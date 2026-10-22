--!strict
-- R12 Scoring (GAME_DESIGN 11.1): every class is scored against the criteria
-- in Config/Objectives. Each criterion is a named predicate behind the
-- registry below; its award is capped by the objective's own `vp` (1 unless
-- Config says otherwise) and by the Day's maximum (Config/Scoring), then the
-- total lands on the class's VP.
--
-- The report line names the criteria that paid, so the Evening Report can
-- answer "why did this number go up" (section 1).
local Types = require(script.Parent.Parent.Types)
local Step = require(script.Parent.Step)
local ConfigObjectives = require(script.Parent.Parent.Parent.Config.Objectives)
local ConfigScoring = require(script.Parent.Parent.Parent.Config.Scoring)

local ObjectiveBase = require(script.Parent.Parent.Behaviors.Objectives.Objective)
local EducationStockAtLeast =
	require(script.Parent.Parent.Behaviors.Objectives.EducationStockAtLeast)
local EmploymentAtLeast = require(script.Parent.Parent.Behaviors.Objectives.EmploymentAtLeast)
local MoneyGainAtLeast = require(script.Parent.Parent.Behaviors.Objectives.MoneyGainAtLeast)
local MoneyGainScaled = require(script.Parent.Parent.Behaviors.Objectives.MoneyGainScaled)
local MoneyNotDecreasing = require(script.Parent.Parent.Behaviors.Objectives.MoneyNotDecreasing)
local NeedsMet = require(script.Parent.Parent.Behaviors.Objectives.NeedsMet)
local OwnBillPassed = require(script.Parent.Parent.Behaviors.Objectives.OwnBillPassed)
local OwnsLinesAtLeast = require(script.Parent.Parent.Behaviors.Objectives.OwnsLinesAtLeast)
local PublicStaffingAtLeast =
	require(script.Parent.Parent.Behaviors.Objectives.PublicStaffingAtLeast)
local StabilityAtLeast = require(script.Parent.Parent.Behaviors.Objectives.StabilityAtLeast)
local TaxCapitalistAtMost = require(script.Parent.Parent.Behaviors.Objectives.TaxCapitalistAtMost)
local WageAtLeast = require(script.Parent.Parent.Behaviors.Objectives.WageAtLeast)

type ClassId = Types.ClassId
type LogEntry = Types.LogEntry
type MatchState = Types.MatchState
type ObjectiveEntry = ConfigObjectives.Objective
type ScoreContext = ObjectiveBase.ScoreContext
type StepContext = Step.StepContext

-- The predicate registry (11.1): Config names a criterion by id, this table
-- names the behavior class that scores it. `any` for the same reason the
-- pipeline holds runner functions: sibling class types do not unify with
-- the abstract base.
local REGISTRY: { [string]: any } = {
	needsMet = NeedsMet,
	employmentAtLeast = EmploymentAtLeast,
	wageAtLeast = WageAtLeast,
	ownBillPassed = OwnBillPassed,
	educationStockAtLeast = EducationStockAtLeast,
	moneyGainAtLeast = MoneyGainAtLeast,
	ownsLinesAtLeast = OwnsLinesAtLeast,
	moneyGainScaled = MoneyGainScaled,
	taxCapitalistAtMost = TaxCapitalistAtMost,
	moneyNotDecreasing = MoneyNotDecreasing,
	stabilityAtLeast = StabilityAtLeast,
	publicStaffingAtLeast = PublicStaffingAtLeast,
}

local function log(state: MatchState, entry: LogEntry)
	table.insert(state.eventLog, entry)
end

local ScoringStep = setmetatable({}, { __index = Step })
ScoringStep.__index = ScoringStep

function ScoringStep.new(): ScoringStep
	return setmetatable({}, ScoringStep)
end

export type ScoringStep = typeof(setmetatable({} :: {}, ScoringStep))

function ScoringStep.run(_self: ScoringStep, state: MatchState, ctx: StepContext)
	for ci = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[ci] :: any
		local objectives = ConfigObjectives[classId] :: { ObjectiveEntry }
		local awarded = 0
		local met: { string } = {}

		for _, objective in objectives do
			local predicate: any = REGISTRY[objective.id]
			if predicate == nil then
				-- A typo in Config is a programming error, never a player
				-- action; fail loudly instead of silently scoring 0.
				error(`Scoring: no predicate for objective '{objective.id}'`, 0)
			end

			local scoreCtx: ScoreContext = {
				state = state,
				classId = classId,
				params = objective.params or {},
				day = ctx.scratch,
			}
			local raw: number = predicate:award(scoreCtx)
			local points = math.clamp(math.floor(raw), 0, objective.vp or 1)
			if points > 0 then
				awarded += points
				table.insert(met, objective.id)
			end
		end

		awarded = math.min(awarded, ConfigScoring.maxVpPerDay)
		if awarded > 0 then
			state.classes[classId].vp += awarded
			log(state, {
				day = state.day,
				text = `{classId} gained {awarded} VP ({table.concat(met, ", ")})`,
				actor = classId,
			})
		end
	end
end

return ScoringStep
