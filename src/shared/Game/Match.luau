--!strict
-- Facade over one match (ARCHITECTURE 3.1 "Objects"): holds the plain state,
-- the difficulty answers (RuleSet), and the injected Rng. Live actions,
-- resolveDay, and the viewers attach in later milestones; snapshot() and
-- hash() follow in M1-T5. The state stays plain data — the facade owns it,
-- it never lives in state.

local Types = require(script.Parent.Types)
local RuleSet = require(script.Parent.RuleSet)
local Rng = require(script.Parent.Rng)

type MatchState = Types.MatchState
type RuleSetType = RuleSet.RuleSet
type RngType = Rng.Rng

local Match = {}
Match.__index = Match

function Match.new(state: MatchState, ruleSet: RuleSetType, rng: RngType): Match
	return setmetatable(
		{
			_state = state,
			_ruleSet = ruleSet,
			_rng = rng,
		} :: {
			_state: MatchState,
			_ruleSet: RuleSetType,
			_rng: RngType,
		},
		Match
	)
end

export type Match = typeof(setmetatable(
	{} :: {
		_state: MatchState,
		_ruleSet: RuleSetType,
		_rng: RngType,
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

return Match
