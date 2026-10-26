--!strict
-- R6 Market (GAME_DESIGN 6.6, section 10): each class's draft market orders
-- execute in fixed order — sells first, then buys — and inside a side, the
-- resource entries run in STOCK_IDS order (the fixed enumeration §10
-- requires wherever order matters). Import (buy) price pays + tariff level
-- per unit and the tariff revenue goes to the State. Volume caps bound the
-- executed units per side (D-048): the request is truncated against the cap
-- the class has left, and an order that skips (no stock, no Money) does not
-- consume cap, so a later entry can still use it. Unaffordable buys and
-- unstocked sells skip with a log entry (section 10). Sales revenue is
-- income (D-046): it lands in scratch.salesRevenue for R7 Taxes.

local Types = require(script.Parent.Parent.Types)
local Step = require(script.Parent.Step)
local StateOps = require(script.Parent.Parent.State.StateOps)
local StockMap = require(script.Parent.Parent.StockMap)
local ConfigMarket = require(script.Parent.Parent.Parent.Config.Market)
local ConfigPolicies = require(script.Parent.Parent.Parent.Config.Policies)
local ConfigResources = require(script.Parent.Parent.Parent.Config.Resources)

type ClassId = Types.ClassId
type DayScratch = Step.DayScratch
type LogEntry = Types.LogEntry
type MarketBag = Types.MarketBag
type MatchState = Types.MatchState
type PolicyId = Types.PolicyId
type ResourceId = Types.ResourceId
type StockId = Types.StockId
type StepContext = Step.StepContext

local function log(state: MatchState, entry: LogEntry)
	table.insert(state.eventLog, entry)
end

-- Display name of a resource (Config/Resources owns the labels).
local function resourceName(resourceId: ResourceId): string
	return (ConfigResources :: any)[resourceId].name
end

-- How many units this entry may execute, and how many the cap drops.
local function takeVolume(requested: number, capLeft: number): (number, number)
	if requested <= 0 then
		return 0, 0
	end
	local take = math.min(requested, capLeft)
	return take, requested - take
end

-- Sells: the class exchanges stock for Money at the export price. The
-- revenue is the class's income for R7 (scratch, D-046).
local function runSells(state: MatchState, classId: ClassId, bag: MarketBag, scratch: DayScratch)
	local capLeft = ConfigMarket.volumeCap
	local dropped = 0

	for si = 1, #Types.STOCK_IDS do
		local stockId: StockId = Types.STOCK_IDS[si] :: any
		local raw = (bag :: { [any]: any })[stockId]
		local requested: number = raw or 0
		local take, lost = takeVolume(requested, capLeft)
		dropped += lost
		if take <= 0 then
			continue
		end

		local resourceId: ResourceId = (StockMap :: any)[stockId]
		if not StateOps.subtractResource(state, classId, resourceId, take) then
			log(state, {
				day = state.day,
				text = `{classId} sell skipped: not enough {resourceName(resourceId)} in stock`,
				actor = classId,
			})
			continue
		end
		capLeft -= take

		local price = ConfigMarket.prices[stockId].sell
		local revenue = price * take
		StateOps.addResource(state, classId, "Money", revenue)
		local soFar: number = (scratch.salesRevenue :: any)[classId] or 0
		(scratch.salesRevenue :: any)[classId] = soFar + revenue
		log(state, {
			day = state.day,
			text = `{classId} sold {take} {resourceName(resourceId)} for {revenue} Money`,
			actor = classId,
		})
	end

	if dropped > 0 then
		log(state, {
			day = state.day,
			text = `{classId} sell volume capped: {dropped} unit(s) dropped (cap {ConfigMarket.volumeCap})`,
			actor = classId,
		})
	end
end

-- Buys: the class pays the import price plus the tariff per unit; the
-- tariff part goes to the State. A buy the class cannot afford skips as a
-- whole (no partial buy) and keeps the cap for later entries.
local function runBuys(state: MatchState, classId: ClassId, bag: MarketBag, tariff: number)
	local capLeft = ConfigMarket.volumeCap
	local dropped = 0

	for si = 1, #Types.STOCK_IDS do
		local stockId: StockId = Types.STOCK_IDS[si] :: any
		local raw = (bag :: { [any]: any })[stockId]
		local requested: number = raw or 0
		local take, lost = takeVolume(requested, capLeft)
		dropped += lost
		if take <= 0 then
			continue
		end

		local resourceId: ResourceId = (StockMap :: any)[stockId]
		local price = ConfigMarket.prices[stockId].buy
		local cost = (price + tariff) * take
		if not StateOps.subtractResource(state, classId, "Money", cost) then
			log(state, {
				day = state.day,
				text = `{classId} buy skipped: cannot afford {take} {resourceName(resourceId)} ({cost} Money)`,
				actor = classId,
			})
			continue
		end
		capLeft -= take

		StateOps.addResource(state, classId, resourceId, take)
		local tariffRevenue = tariff * take
		if tariffRevenue > 0 then
			StateOps.addResource(state, "State", "Money", tariffRevenue)
		end
		local note = if tariffRevenue > 0 then ` (incl. {tariffRevenue} Money tariff)` else ""
		log(state, {
			day = state.day,
			text = `{classId} bought {take} {resourceName(resourceId)} for {cost} Money{note}`,
			actor = classId,
		})
	end

	if dropped > 0 then
		log(state, {
			day = state.day,
			text = `{classId} buy volume capped: {dropped} unit(s) dropped (cap {ConfigMarket.volumeCap})`,
			actor = classId,
		})
	end
end

local MarketStep = setmetatable({}, { __index = Step })
MarketStep.__index = MarketStep

function MarketStep.new(): MarketStep
	return setmetatable({}, MarketStep)
end

export type MarketStep = typeof(setmetatable({} :: {}, MarketStep))

function MarketStep.run(_self: MarketStep, state: MatchState, ctx: StepContext)
	local scratch = ctx.scratch

	-- Tariff: the policy's level, priced per imported unit (Config/Policies
	-- holds the per-level effect; the level itself lives in the state).
	local tariffId: PolicyId = "Tariff"
	-- Disabled tracks are absent from the policy map; D-041 says readers
	-- treat a missing track as level 0. Easy disables Tariff, so this is the
	-- difference between a free import and a nil arithmetic error.
	local tariffLevel: number = (state.policies :: any)[tariffId] or 0
	local tariff: number = (ConfigPolicies.tracks[tariffId].levelValues :: { [any]: any })[tariffLevel]
		or 0

	for ci = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[ci] :: any
		local market = state.drafts[classId].market
		if market ~= nil then
			if market.sell ~= nil then
				runSells(state, classId, market.sell, scratch)
			end
			if market.buy ~= nil then
				runBuys(state, classId, market.buy, tariff)
			end
		end
	end
end

return MarketStep
