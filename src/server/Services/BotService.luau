--!strict
-- BotService: the bot seats and the bot runner (M6-T2 seat, M9-T1 runner).
--
-- A bot seat is the class nobody took. At the start of every Window the
-- runner builds the PlayerView a human in that seat would receive, gives it
-- and a per-bot RNG to the class strategy, and stores the returned draft
-- through DraftRules — the same clamp a human's Draft_Update gets. The
-- strategy never sees the MatchState or the match RNG (GAME_DESIGN 13/15).
--
-- The seat data is plain; the runner is a runtime object because the RNG
-- streams have identity and live for the whole match.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Seats = require(ReplicatedStorage.Shared.Net.Seats)
local Rng = require(ReplicatedStorage.Shared.Game.Rng)
local Match = require(ReplicatedStorage.Shared.Game.Match)
local Alliances = require(ReplicatedStorage.Shared.Game.Ops.Alliances)
local ConfigBots = require(ReplicatedStorage.Shared.Config.Bots)
local PlayerViewBuilder =
	require(ReplicatedStorage.Shared.Game.Behaviors.InfoModes.PlayerViewBuilder)
local BotStrategy = require(script.Parent.Bots.BotStrategy)
local WorkingBot = require(script.Parent.Bots.WorkingBot)
local MiddleBot = require(script.Parent.Bots.MiddleBot)
local CapitalistBot = require(script.Parent.Bots.CapitalistBot)
local StateBot = require(script.Parent.Bots.StateBot)
local DraftRules = require(script.Parent.DraftRules)

type ActionDraft = Types.ActionDraft
type ClassId = Types.ClassId
type MatchType = Match.Match
type Seat = Seats.Seat

local BotService = {}
BotService.__index = BotService

export type BotService = typeof(setmetatable(
	{} :: {
		_rngs: { [ClassId]: Rng.Rng },
		_strategies: { [ClassId]: BotStrategy.BotStrategy },
	},
	BotService
))

local DEFAULT_STRATEGIES: { [ClassId]: BotStrategy.BotStrategy } = {
	Working = WorkingBot.new(),
	Middle = MiddleBot.new(),
	Capitalist = CapitalistBot.new(),
	State = StateBot.new(),
}

-- The bot that takes a class nobody else did.
function BotService.seatFor(classId: ClassId): Seat
	return {
		id = `Bot-{classId}`,
		kind = "Bot",
		userId = nil,
		name = `{classId} bot`,
		classId = classId,
		roles = { "Economy", "Politics", "Diplomacy" },
		connected = true,
		ready = true,
		botControlled = false,
	}
end

-- A runner for one match. The optional strategies are for tests; production
-- uses the four class strategies. The RNG streams are derived from the match
-- seed and stay independent of each other and of the match RNG.
function BotService.new(
	seed: number,
	strategies: { [ClassId]: BotStrategy.BotStrategy }?
): BotService
	local chosen = table.clone(DEFAULT_STRATEGIES)
	if strategies ~= nil then
		for classId, strategy in strategies do
			local id: ClassId = classId :: any
			chosen[id] = strategy
		end
	end

	local rngs: { [ClassId]: Rng.Rng } = {}
	for index = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[index] :: any
		rngs[classId] = Rng.new(seed + index * ConfigBots.rngSeedStride)
	end

	return setmetatable({
		_rngs = rngs,
		_strategies = chosen,
	}, BotService)
end

-- One bot's Window: build the restricted view, decide, then store the draft
-- through the shared clamp. Returns nil and a reason when the bot cannot act.
function BotService.run(
	self: BotService,
	match: MatchType,
	classId: ClassId
): (ActionDraft?, string)
	local state = match:state()
	if state.phase ~= "Window" then
		return nil, "the Window is closed"
	end
	local strategy: BotStrategy.BotStrategy? = self._strategies[classId]
	if strategy == nil then
		return nil, `no strategy for {classId}`
	end

	-- The only data the strategy receives: a detached PlayerView (hidden
	-- fields absent, exactly as a human's client sees them) and its own RNG.
	local view = PlayerViewBuilder.build(state, match:ruleSet(), classId)
	local decision = strategy:decide(view, { rng = self._rngs[classId] })

	local stored = state.drafts[classId]
	return DraftRules.apply(state, classId, decision, stored.sequence + 1), ""
end

-- One bot's live diplomacy after its draft: alliance proposals, responses
-- and breaks. The strategy sees only the same PlayerView; BotService applies
-- the decision through the shared Alliances Ops (GAME_DESIGN 8.4).
function BotService._playLive(self: BotService, match: MatchType, classId: ClassId)
	local state = match:state()
	if state.phase ~= "Window" then
		return
	end
	local strategy: BotStrategy.BotStrategy? = self._strategies[classId]
	if strategy == nil then
		return
	end

	local view = PlayerViewBuilder.build(state, match:ruleSet(), classId)
	local decision = strategy:decideLive(view, { rng = self._rngs[classId] })

	if decision.respondToAlliance ~= nil then
		local proposal: Types.AllianceProposal? = nil
		for _, candidate in state.allianceProposals do
			if candidate.id == decision.respondToAlliance and candidate.to == classId then
				proposal = candidate
				break
			end
		end
		if proposal ~= nil then
			Alliances.respond(state, proposal.id, decision.acceptAlliance == true)
		end
	end

	if decision.breakAlliance == true then
		Alliances.breakAlliance(state, classId)
	end

	local target: ClassId? = decision.proposeAllianceTo
	if target ~= nil then
		Alliances.propose(state, classId, target :: ClassId)
	end
end

-- Run every bot class for this Window. The caller passes the classes whose
-- seats are bots; the order is the canonical CLASS_IDS order from the lobby.
-- Each bot's live diplomacy is applied after its draft, so a later bot in the
-- order sees the proposal and can answer it in the same Window.
function BotService.playWindow(
	self: BotService,
	match: MatchType,
	classIds: { ClassId }
): { ClassId }
	local played: { ClassId } = {}
	for _, classId in classIds do
		local id: ClassId = classId :: any
		local draft = self:run(match, id)
		if draft ~= nil then
			self:_playLive(match, id)
			table.insert(played, id)
		end
	end
	return played
end

return BotService
