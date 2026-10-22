--!strict
-- The VP criteria (GAME_DESIGN 11.1): one behavior class per named
-- predicate, all under this abstract base (ARCHITECTURE 3.1 "Behavior" —
-- one abstract base, depth 1). R12 Scoring walks Config/Objectives, looks
-- the predicate up by id, and turns its award into points (capped at the
-- objective's own `vp` and at the Day's maximum).
--
-- Criteria are pure reads: a predicate never mutates the state and never
-- throws for a player action.
local Types = require(script.Parent.Parent.Parent.Types)
local Step = require(script.Parent.Parent.Parent.Steps.Step)
local Abstract = require(script.Parent.Parent.Parent.Abstract)

type ClassId = Types.ClassId
type DayScratch = Step.DayScratch
type MatchState = Types.MatchState
type PolicyId = Types.PolicyId

-- Everything a criterion may look at: the resolved state (every step up to
-- R11 has run), the class being scored, its Config params, and the Day's
-- cross-step intermediates (D-046).
export type ScoreContext = {
	state: MatchState,
	classId: ClassId,
	params: { [string]: number },
	day: DayScratch,
}

local Objective = {}
Objective.__index = Objective

-- The award in VP: 0 when the criterion is not met. The Scoring step caps
-- it at the objective's `vp` (1 unless Config says otherwise) and at the
-- Day's maximum.
function Objective.award(_self: Objective, _ctx: ScoreContext): number
	Abstract.notImplemented("Objective", "award")
	-- The helper always throws; this unreachable return closes the return
	-- path for the analyzer (see the Step base).
	return 0
end

-- Money the class gained this Day (11.1): the income channels R5 and R6
-- already feed (wages and market sales). Never transfers or spending — a
-- reshuffle between classes is not a gain (DECISIONS).
function Objective.moneyGained(ctx: ScoreContext): number
	local wages: number = (ctx.day.wagesReceived :: any)[ctx.classId] or 0
	local sales: number = (ctx.day.salesRevenue :: any)[ctx.classId] or 0
	return wages + sales
end

-- The level of a policy track; a track the difficulty disabled is absent
-- from the map and reads as 0 (D-041).
function Objective.policyLevel(state: MatchState, policyId: PolicyId): number
	local level: number? = (state.policies :: any)[policyId]
	return level or 0
end

export type Objective = typeof(setmetatable({} :: {}, Objective))

return Objective
