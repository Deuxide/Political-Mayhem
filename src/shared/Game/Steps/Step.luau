--!strict
-- Abstract Step base (GAME_DESIGN section 10; ARCHITECTURE 3.1 "Behavior"):
-- one resolution step each; the ResolutionPipeline (M2-T7) composes the
-- subclasses in the exact GAME_DESIGN order. Stateless: everything a step
-- needs arrives through (state, ctx) — the working copy to mutate via
-- StateOps and the ctx below. Invalid or unaffordable player actions are
-- skipped and logged, never thrown (GAME_DESIGN section 10).

local Types = require(script.Parent.Parent.Types)
local Rng = require(script.Parent.Parent.Rng)
local RuleSet = require(script.Parent.Parent.RuleSet)
local Abstract = require(script.Parent.Parent.Abstract)

local Step = {}
Step.__index = Step

-- Everything handed to every step of one resolution. rng = the injected
-- randomness (D-018); ruleSet = difficulty flags as typed answers (never
-- difficulty-name comparisons); scratch = the per-Day channel for
-- cross-step intermediates (D-046), fresh-created by the pipeline each
-- resolution and never part of MatchState.
export type StepContext = {
	rng: Rng.Rng,
	ruleSet: RuleSet.RuleSet,
	scratch: DayScratch,
}

-- Intermediate values one resolution passes downward (D-046): R5 Production
-- tracks wages received (R7 Taxes income) and unpaid slots (R9 Stability);
-- R6 Market tracks sales revenue (R7 Taxes income); employed workers feed
-- the R12 Scoring employment criterion. Not state, not serialized, not
-- hashed: it exists only while the pipeline runs.
export type DayScratch = {
	wagesReceived: { [Types.ClassId]: number },
	salesRevenue: { [Types.ClassId]: number },
	unpaidSlots: number,
	employedWorkers: number,
}

-- Abstract hook every concrete step implements (R1..R14). Methods are
-- dot-defined with explicit `self` (M1-T0 template); call sites keep `:`.
function Step.run(_self: Step, _state: Types.MatchState, _ctx: StepContext)
	Abstract.notImplemented("Step", "run")
	-- The helper always throws; the type checker cannot see through user
	-- functions that throw, so this unreachable return closes the return
	-- path for the analyzer (and keeps the parameters visibly consumed).
	return nil
end

-- Instance alias below the definitions so `typeof` snapshots the complete
-- metatable (Luau type aliases are order-independent).
export type Step = typeof(setmetatable({} :: {}, Step))

return Step
