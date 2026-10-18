--!strict
-- Match facade: holds state, RuleSet, Rng; resolveDay(), live actions, snapshot(), hash(), viewFor().

local Types = require(script.Parent.Types)
local Rng = require(script.Parent.Rng)
local RuleSet = require(script.Parent.RuleSet)
local StateOps = require(script.Parent.State.StateOps)
local StateHash = require(script.Parent.State.StateHash)
local ResolutionPipeline = require(script.Parent.ResolutionPipeline)

export type Match = {
	_state: Types.MatchState,
	_ruleSet: RuleSet.RuleSet,
	_rng: Rng.Rng,
	_stateOps: StateOps.StateOps,
	_resolutionPipeline: ResolutionPipeline.ResolutionPipeline,

	getState: (self: Match) -> Types.MatchState,
	getRuleSet: (self: Match) -> RuleSet.RuleSet,
	getRng: (self: Match) -> Rng.Rng,
	resolveDay: (self: Match) -> (boolean, { Types.LogEntry }?),
	snapshot: (self: Match) -> Types.MatchState,
	hash: (self: Match) -> string,
	viewFor: (self: Match, classId: Types.ClassId) -> Types.PlayerView,
	-- Live actions (stubs for now)
	applyTrade: (self: Match, offer: Types.TradeOffer) -> (boolean, string?),
	proposeBill: (self: Match, bill: Types.Bill) -> (boolean, string?),
	castVote: (
		self: Match,
		classId: Types.ClassId,
		billId: string,
		inFavor: boolean,
		influence: number
	) -> (boolean, string?),
	proposeAlliance: (self: Match, from: Types.ClassId, to: Types.ClassId) -> (boolean, string?),
	breakAlliance: (self: Match, from: Types.ClassId, to: Types.ClassId) -> (boolean, string?),
	proposePromise: (self: Match, promise: Types.Promise) -> (boolean, string?),
}

local Match = {}
Match.__index = Match

function Match.new(initialState: Types.MatchState, ruleSet: RuleSet.RuleSet, rng: Rng.Rng): Match
	local self = setmetatable({}, Match)
	self._state = initialState
	self._ruleSet = ruleSet
	self._rng = rng
	self._stateOps = StateOps.new()
	self._resolutionPipeline = ResolutionPipeline.new(ruleSet)
	return self
end

function Match:getState(): Types.MatchState return self._state end

function Match:getRuleSet(): RuleSet.RuleSet return self._ruleSet end

function Match:getRng(): Rng.Rng return self._rng end

function Match:resolveDay(): (boolean, { Types.LogEntry }?)
	-- Deep copy state for working copy
	local workingCopy = self._stateOps:deepCopy(self._state)
	local ctx = {
		rng = self._rng,
		ruleSet = self._ruleSet,
		stateOps = self._stateOps,
		trace = {} :: { Types.LogEntry },
	}

	local success, err = pcall(function() self._resolutionPipeline:run(workingCopy, ctx) end)

	if not success then
		warn("Resolution failed: " .. tostring(err))
		return false, nil
	end

	-- Commit working copy
	self._state = workingCopy
	self._state.round += 1
	self._state.phase = "ActionWindow"

	-- Append trace to event log
	for _, entry in ipairs(ctx.trace) do
		table.insert(self._state.eventLog, entry)
	end

	return true, ctx.trace
end

function Match:snapshot(): Types.MatchState return self._stateOps:deepCopy(self._state) end

function Match:hash(): string return StateHash.compute(self._state) end

function Match:viewFor(classId: Types.ClassId): Types.PlayerView
	-- TODO: Implement per-class filtered view based on info mode (M5-T4)
	return {
		ownClass = classId,
		visibleState = self._state, -- placeholder: full state for now
		infoMode = "OpenInfo",
	}
end

-- Live action stubs (return success for now; validation in M6)
function Match:applyTrade(offer: Types.TradeOffer): (boolean, string?) return true, nil end

function Match:proposeBill(bill: Types.Bill): (boolean, string?) return true, nil end

function Match:castVote(
	classId: Types.ClassId,
	billId: string,
	inFavor: boolean,
	influence: number
): (boolean, string?)
	return true, nil
end

function Match:proposeAlliance(from: Types.ClassId, to: Types.ClassId): (boolean, string?)
	return true, nil
end

function Match:breakAlliance(from: Types.ClassId, to: Types.ClassId): (boolean, string?)
	return true, nil
end

function Match:proposePromise(promise: Types.Promise): (boolean, string?) return true, nil end

return Match
