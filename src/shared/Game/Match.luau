--!strict
-- Facade over one match (ARCHITECTURE 3.1 "Objects"): holds the plain state,
-- the difficulty answers (RuleSet), and the injected Rng. Live actions,
-- resolveDay, and the viewers attach in later milestones; snapshot() and
-- hash() follow in M1-T5. The state stays plain data — the facade owns it,
-- it never lives in state.

local Types = require(script.Parent.Types)
local RuleSet = require(script.Parent.RuleSet)
local Rng = require(script.Parent.Rng)
local Step = require(script.Parent.Steps.Step)
local ResolutionPipeline = require(script.Parent.ResolutionPipeline)
local StateOps = require(script.Parent.State.StateOps)
local StateHash = require(script.Parent.State.StateHash)

type MatchState = Types.MatchState
type RuleSetType = RuleSet.RuleSet
type RngType = Rng.Rng
type StepContext = Step.StepContext

local Match = {}
Match.__index = Match

function Match.new(state: MatchState, ruleSet: RuleSetType, rng: RngType): Match
	return setmetatable(
		{
			_state = state,
			_ruleSet = ruleSet,
			_rng = rng,
			_pipeline = ResolutionPipeline.new(),
		} :: {
			_state: MatchState,
			_ruleSet: RuleSetType,
			_rng: RngType,
			_pipeline: ResolutionPipeline.ResolutionPipeline,
		},
		Match
	)
end

export type Match = typeof(setmetatable(
	{} :: {
		_state: MatchState,
		_ruleSet: RuleSetType,
		_rng: RngType,
		_pipeline: ResolutionPipeline.ResolutionPipeline,
	},
	Match
))

-- Live reference — M2+ resolution reads and copies it, UI never sends it raw.
function Match.state(self: Match): MatchState
	return self._state
end

function Match.ruleSet(self: Match): RuleSetType
	return self._ruleSet
end

function Match.rng(self: Match): RngType
	return self._rng
end

-- Full-content copy, per ARCHITECTURE ("Snapshot = StateOps.deepCopy(state)"):
-- callers may read any part of it without touching the live state.
function Match.snapshot(self: Match): MatchState
	return StateOps.deepCopy(self._state)
end

-- Deterministic content hash of the live state (duplicates-free — the same
-- content hashes identically), per ARCHITECTURE ("hash = StateHash.compute").
function Match.hash(self: Match): string
	return StateHash.compute(self._state)
end

-- Resolves one Day (GAME_DESIGN section 10): the ResolutionPipeline runs
-- its steps over a working copy of the state, and that copy becomes the
-- live state only when every step succeeded — a step that throws (a
-- programming error, never a player action) leaves the live state untouched.
-- The rng is the resolution stream; the Match's own rng serves live
-- actions, and passing the stream in keeps a replay reproducible.
function Match.resolveDay(self: Match, rng: RngType): MatchState
	local working = StateOps.deepCopy(self._state)
	local ctx: StepContext = {
		rng = rng,
		ruleSet = self._ruleSet,
		-- fresh per Day: the cross-step intermediates of one resolution
		scratch = {
			wagesReceived = {},
			salesRevenue = {},
			unpaidSlots = 0,
			employedWorkers = 0,
			startMoney = {},
			unmetByClass = {},
			passedBills = {},
		},
	}
	self._pipeline:run(working, ctx)
	self._state = working
	return working
end

return Match
