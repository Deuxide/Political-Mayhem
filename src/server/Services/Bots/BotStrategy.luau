--!strict
-- BotStrategy: the abstract behavior base for the four class bots
-- (ARCHITECTURE 3.1 "Behavior", GAME_DESIGN 15). One abstract base and one
-- subclass per class, depth 1.
--
-- A bot decides from a PlayerView and a per-bot RNG only. It never receives
-- the MatchState, the match RNG or a client's raw request, so it cannot read
-- a field the human in that seat could not read (GAME_DESIGN 13 and 15).
-- BotService builds the view, applies the returned draft through DraftRules
-- (the same clamp a human gets), and owns the RNG stream.
--
-- The helpers below are the shared v1 heuristics: open affordable slots, sell
-- surplus, buy missing needs, assign workers, vote by class interest and
-- weigh a trade with the counterparty's Reputation. Each subclass chooses the
-- class-specific build and priorities.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Rng = require(ReplicatedStorage.Shared.Game.Rng)
local Abstract = require(ReplicatedStorage.Shared.Game.Abstract)
local Reputation = require(ReplicatedStorage.Shared.Game.Ops.Reputation)
local ConfigBots = require(ReplicatedStorage.Shared.Config.Bots)
local ConfigLines = require(ReplicatedStorage.Shared.Config.Lines)
local ConfigMarket = require(ReplicatedStorage.Shared.Config.Market)
local ConfigPolicies = require(ReplicatedStorage.Shared.Config.Policies)
local ConfigResources = require(ReplicatedStorage.Shared.Config.Resources)

type ActionDraft = Types.ActionDraft
type Alliance = Types.Alliance
type AllianceProposal = Types.AllianceProposal
type Bill = Types.Bill
type ClassId = Types.ClassId
type LineType = Types.LineType
type LineView = Types.LineView
type PlayerView = Types.PlayerView
type ResourceBag = Types.ResourceBag
type ResourceId = Types.ResourceId
type StockId = Types.StockId
type TradeOffer = Types.TradeOffer

export type BotContext = {
	rng: Rng.Rng,
}

-- Live diplomacy a bot may take after its draft is stored. These are not
-- draft fields (GAME_DESIGN 9): BotService applies them through the same
-- Alliances Ops the human handlers use.
export type BotLiveDecision = {
	proposeAllianceTo: ClassId?,
	respondToAlliance: string?,
	acceptAlliance: boolean?,
	breakAlliance: boolean?,
}

local BotStrategy = {}
BotStrategy.__index = BotStrategy

export type BotStrategy = typeof(setmetatable({} :: {}, BotStrategy))

function BotStrategy.new(): BotStrategy
	return setmetatable({}, BotStrategy)
end

-- A fresh, safe, empty draft. Every field is present so a subclass can fill
-- only what it chooses; StateFactory's initial draft has the same shape.
function BotStrategy.emptyDraft(): ActionDraft
	return {
		sequence = 0,
		locked = false,
		openSlots = {},
		assign = {},
		strike = nil,
		build = nil,
		lobby = nil,
		market = { sell = {}, buy = {} },
		votes = {},
	}
end

-- The Wage policy's Money per staffed slot this Day.
function BotStrategy.wage(view: PlayerView): number
	local track = (ConfigPolicies.tracks :: any).Wage
	local level = (view.policies :: any).Wage
	if level == nil then
		return track.default
	end
	local values = track.levelValues
	if values == nil then
		return track.default
	end
	return (values :: any)[level] or track.default
end

local function stockKeyOf(resourceId: ResourceId): StockId?
	local entry = (ConfigResources :: any)[resourceId]
	local key = entry.stockKey
	if type(key) == "string" then
		return key :: StockId
	end
	return nil
end

local function bagValue(bag: ResourceBag): number
	local total = 0
	for ri = 1, #Types.RESOURCE_IDS do
		local resourceId: ResourceId = Types.RESOURCE_IDS[ri] :: any
		local amount = bag[resourceId] or 0
		if amount > 0 then
			if resourceId == "Money" then
				total += amount
			elseif resourceId == "Influence" then
				total += amount * ConfigBots.influenceValue
			else
				local stockId = stockKeyOf(resourceId)
				if stockId ~= nil then
					local price = (ConfigMarket.prices :: any)[stockId].buy
					total += amount * price
				end
			end
		end
	end
	return total
end

local function canAfford(view: PlayerView, bag: ResourceBag): boolean
	for ri = 1, #Types.RESOURCE_IDS do
		local resourceId: ResourceId = Types.RESOURCE_IDS[ri] :: any
		local amount = bag[resourceId] or 0
		if amount > 0 then
			if resourceId == "Money" then
				if view.own.money < amount then
					return false
				end
			elseif resourceId == "Influence" then
				if view.own.influence < amount then
					return false
				end
			else
				local stockId: StockId? = stockKeyOf(resourceId)
				if stockId == nil then
					return false
				end
				if (view.own.stock[stockId] or 0) < amount then
					return false
				end
			end
		end
	end
	return true
end

local function saleRevenue(draft: ActionDraft): number
	local revenue = 0
	for rawStockId, amount in draft.market.sell do
		local stockId: StockId = rawStockId :: any
		local price = (ConfigMarket.prices :: any)[stockId].sell
		revenue += amount * price
	end
	return revenue
end

-- Whether a line's owner can pay the slots the Working may assign. In open
-- info the Money is exact; in partial/fog it is hidden, so the bot assumes
-- the owner can pay rather than refusing to work for an unknown class.
local function ownerCanPay(view: PlayerView, owner: ClassId, slots: number, wage: number): boolean
	if owner == view.viewer then
		return true
	end
	local other = view.others[owner]
	if other == nil then
		return true
	end
	local money = other.money
	if type(money) == "number" then
		return money >= slots * wage
	end
	return true
end

-- Open as many of the class's own slots as the post-build Money can pay for
-- this Day. A line with fewer affordable slots still produces; an unpaid slot
-- would cost Stability (GAME_DESIGN 6.4/6.9).
function BotStrategy.openOwnLines(view: PlayerView, draft: ActionDraft, moneyAfterBuild: number)
	local wage = BotStrategy.wage(view)
	local budget = math.max(0, moneyAfterBuild - ConfigBots.moneyReserve)
	for _, line in view.ownLines do
		local config = (ConfigLines :: any)[line.type]
		local slots = math.min(config.slotsMax, math.floor(budget / wage))
		draft.openSlots[line.id] = slots
		budget -= slots * wage
	end
end

-- Buy one line if the class can afford it and still keep the reserve. Returns
-- the Money spent, so the caller can pass the post-build wallet to the slot
-- and market helpers.
function BotStrategy.build(view: PlayerView, draft: ActionDraft, lineType: LineType): number
	local cost = (ConfigLines :: any)[lineType].buildCost
	if view.own.money < cost + ConfigBots.moneyReserve then
		return 0
	end
	draft.build = { lineType = lineType }
	return cost
end

-- Sell stock above the class's needs plus the configured buffer, and above
-- any class-specific reserve (Middle's Education VP, Capitalist's Factory
-- input). The market cap is shared across the stock entries.
function BotStrategy.sellSurplus(view: PlayerView, draft: ActionDraft, keep: { [StockId]: number })
	local cap = ConfigMarket.volumeCap
	for si = 1, #Types.STOCK_IDS do
		local stockId: StockId = Types.STOCK_IDS[si] :: any
		local stock = view.own.stock[stockId] or 0
		local need = view.needs[stockId] or 0
		local reserved = math.max(need + ConfigBots.stockBuffer, keep[stockId] or 0)
		local surplus = stock - reserved
		if surplus > 0 and cap > 0 then
			local take = math.min(surplus, cap)
			draft.market.sell[stockId] = take
			cap -= take
		end
	end
end

-- Buy the missing part of the class's needs, spending the post-build wallet
-- plus what the same draft's sells will earn (R6 sells before it buys). The
-- optional extra budget is the Working's expected wages.
function BotStrategy.buyNeeds(
	view: PlayerView,
	draft: ActionDraft,
	moneyAfterBuild: number,
	extraBudget: number?
)
	local tariffLevel = (view.policies :: any).Tariff or 0
	local budget = math.max(0, moneyAfterBuild + saleRevenue(draft) + (extraBudget or 0))
	local cap = ConfigMarket.volumeCap
	for si = 1, #Types.STOCK_IDS do
		local stockId: StockId = Types.STOCK_IDS[si] :: any
		local need = view.needs[stockId] or 0
		local have = view.own.stock[stockId] or 0
		local gap = need - have
		if gap > 0 and cap > 0 then
			local price = (ConfigMarket.prices :: any)[stockId].buy + tariffLevel
			local affordable = math.floor(budget / price)
			local take = math.min(gap, affordable, cap)
			if take > 0 then
				draft.market.buy[stockId] = take
				budget -= take * price
				cap -= take
			end
		end
	end
end

-- Working's assignment: fill open slots up to the worker pool, preferring
-- owners who can visibly pay and then a stable line-id order. Returns the
-- number assigned, which the Working uses to estimate wages for its market
-- budget.
function BotStrategy.assignWorkers(view: PlayerView, draft: ActionDraft): number
	local wage = BotStrategy.wage(view)
	local lines: { LineView } = {}
	for _, line in view.ownLines do
		table.insert(lines, line)
	end
	for owner, other in view.others do
		local ownerId: ClassId = owner :: any
		for _, line in other.lines do
			-- `owner` is on the line; keep the loop key only for the view
			-- shape, the line is the source of truth.
			if line.owner == ownerId then
				table.insert(lines, line)
			end
		end
	end

	table.sort(lines, function(a, b)
		local aPays = ownerCanPay(view, a.owner, a.openSlots, wage)
		local bPays = ownerCanPay(view, b.owner, b.openSlots, wage)
		if aPays ~= bPays then
			return aPays
		end
		return a.id < b.id
	end)

	local remaining = view.own.workers
	local assigned = 0
	for _, line in lines do
		if remaining <= 0 then
			break
		end
		if line.openSlots > 0 then
			local take = math.min(line.openSlots, remaining)
			draft.assign[line.id] = take
			remaining -= take
			assigned += take
		end
	end
	return assigned
end

local function allianceOf(view: PlayerView): Alliance?
	for _, alliance in view.alliances do
		for _, member in alliance.members do
			if member == view.viewer then
				return alliance
			end
		end
	end
	return nil
end

local function otherMember(alliance: Alliance, viewer: ClassId): ClassId?
	for _, member in alliance.members do
		local memberId: ClassId = member :: any
		if memberId ~= viewer then
			return memberId
		end
	end
	return nil
end

local function isAlliedWith(view: PlayerView, target: ClassId): boolean
	for _, alliance in view.alliances do
		local hasViewer = false
		local hasTarget = false
		for _, member in alliance.members do
			if member == view.viewer then
				hasViewer = true
			elseif member == target then
				hasTarget = true
			end
		end
		if hasViewer and hasTarget then
			return true
		end
	end
	return false
end

-- A NoBreakAlliance promise the bot made is still running until the end of
-- its untilDay; the bot will not break before that Closing Bell (8.3).
local function hasNoBreakPromise(view: PlayerView, other: ClassId): boolean
	for _, promise in view.promises do
		if
			promise.status == "open"
			and promise.from == view.viewer
			and promise.to == other
			and promise.kind == "NoBreakAlliance"
		then
			local spec = promise.spec
			if spec.kind == "NoBreakAlliance" and view.day <= spec.untilDay then
				return true
			end
		end
	end
	return false
end

local function hasVoteYesPromise(view: PlayerView, bill: Bill): boolean
	for _, promise in view.promises do
		if
			promise.status == "open"
			and promise.from == view.viewer
			and promise.kind == "VoteYes"
		then
			local spec = promise.spec
			if
				spec.kind == "VoteYes"
				and spec.policyId == bill.policyId
				and spec.level == bill.level
				and view.day <= spec.byDay
			then
				return true
			end
		end
	end
	return false
end

local function bestIncomingProposal(view: PlayerView): AllianceProposal?
	local prefs = (ConfigBots.alliancePreference :: any)[view.viewer]
	if prefs == nil then
		return nil
	end
	local best: AllianceProposal? = nil
	local bestScore = 0
	for _, proposal in view.allianceProposals do
		if proposal.to == view.viewer then
			local score = (prefs :: any)[proposal.from] or 0
			if score > bestScore then
				bestScore = score
				best = proposal
			end
		end
	end
	return best
end

local function hasOutgoingProposal(view: PlayerView): boolean
	for _, proposal in view.allianceProposals do
		if proposal.from == view.viewer then
			return true
		end
	end
	return false
end

local function bestFreeTarget(view: PlayerView): ClassId?
	local prefs = (ConfigBots.alliancePreference :: any)[view.viewer]
	if prefs == nil then
		return nil
	end
	local best: ClassId? = nil
	local bestScore = 0
	for ci = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[ci] :: any
		if
			classId ~= view.viewer
			and view.others[classId] ~= nil
			and not isAlliedWith(view, classId)
		then
			local score = (prefs :: any)[classId] or 0
			if score > bestScore then
				bestScore = score
				best = classId
			end
		end
	end
	return best :: ClassId?
end

-- Vote the class's base weight by interest, except when an open VoteYes
-- promise covers the bill: a promise is honoured before preference. The bot
-- commits no Influence in v1 (GAME_DESIGN 15).
function BotStrategy.vote(view: PlayerView, draft: ActionDraft)
	local prefs = (ConfigBots.policyPreference :: any)[view.viewer]
	if prefs == nil then
		return
	end
	for _, bill in view.bills do
		if hasVoteYesPromise(view, bill) then
			draft.votes[bill.id] = { side = "yes", influence = 0 }
		else
			local current = (view.policies :: any)[bill.policyId]
			local preference = (prefs :: any)[bill.policyId] or 0
			if current ~= nil and preference ~= 0 and bill.level ~= current then
				local direction = if bill.level > current then 1 else -1
				local side: Types.VoteSide = if preference * direction > 0 then "yes" else "no"
				draft.votes[bill.id] = { side = side, influence = 0 }
			end
		end
	end
end

-- The live diplomacy decision (M9-T3). A bot with an alliance reviews it
-- after the configured age, but an open NoBreakAlliance promise holds it
-- until that promise is audited. A free bot accepts the best incoming
-- proposal, otherwise proposes to the best free class by alliance
-- preference. The shared default applies to every class; a subclass may
-- override it later.
function BotStrategy.decideLive(
	_self: BotStrategy,
	view: PlayerView,
	_ctx: BotContext
): BotLiveDecision
	local alliance = allianceOf(view)
	if alliance ~= nil then
		local other: ClassId? = otherMember(alliance, view.viewer)
		if
			other ~= nil
			and view.day - alliance.formedOnDay >= ConfigBots.allianceBreakAfterDays
			and not hasNoBreakPromise(view, other :: ClassId)
		then
			return { breakAlliance = true }
		end
		return { acceptAlliance = false, breakAlliance = false }
	end

	local incoming = bestIncomingProposal(view)
	if incoming ~= nil then
		return { respondToAlliance = incoming.id, acceptAlliance = true }
	end

	if hasOutgoingProposal(view) then
		return { acceptAlliance = false, breakAlliance = false }
	end

	local target: ClassId? = bestFreeTarget(view)
	if target ~= nil then
		return { proposeAllianceTo = target :: ClassId }
	end
	return { acceptAlliance = false, breakAlliance = false }
end

-- Trade acceptance: weigh what the bot receives against what it gives at
-- market value, then demand a premium from a counterparty whose Reputation is
-- below neutral. The bot also refuses a trade it cannot afford right now.
function BotStrategy.acceptTrade(view: PlayerView, offer: TradeOffer, _ctx: BotContext?): boolean
	if not canAfford(view, offer.want) then
		return false
	end
	local receive = bagValue(offer.give)
	local give = bagValue(offer.want)
	if give <= 0 then
		return true
	end
	local reputation = view.reputation[offer.from]
	local trust = if reputation ~= nil
		then Reputation.score(reputation)
		else ConfigBots.neutralTrust
	local risk = ConfigBots.neutralTrust - trust
	local required = give * (1 + risk * ConfigBots.tradeTrustPenalty)
	return receive >= required
end

-- The one abstract method: decide this Window's draft from what a human in
-- this seat could see. Subclasses override it.
function BotStrategy.decide(_self: BotStrategy, _view: PlayerView, _ctx: BotContext): ActionDraft
	return Abstract.notImplemented("BotStrategy", "decide")
end

return BotStrategy
