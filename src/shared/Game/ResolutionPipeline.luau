--!strict
-- The resolution pipeline (GAME_DESIGN section 10): the exact order of the
-- steps one Day runs through. The pipeline owns the step instances and
-- runs them over the working copy of the state; Match:resolveDay commits
-- that copy only if every step succeeded.
--
-- The step list follows the section 10 table: R1 LockDrafts is real, R4 to
-- R9 are the economy steps of M2, R2/R3/R10/R11/R12/R13 are placeholders
-- for the milestones that own them, and R14 closes the Day (draft
-- roll-forward + Day counter).

local Types = require(script.Parent.Types)
local Step = require(script.Parent.Steps.Step)
local LockDraftsStep = require(script.Parent.Steps.LockDraftsStep)
local LobbyStep = require(script.Parent.Steps.LobbyStep)
local StubStep = require(script.Parent.Steps.StubStep)
local BuildStep = require(script.Parent.Steps.BuildStep)
local ProductionStep = require(script.Parent.Steps.ProductionStep)
local MarketStep = require(script.Parent.Steps.MarketStep)
local TaxesStep = require(script.Parent.Steps.TaxesStep)
local PublicServicesStep = require(script.Parent.Steps.PublicServicesStep)
local UpkeepStep = require(script.Parent.Steps.UpkeepStep)
local InfluenceStep = require(script.Parent.Steps.InfluenceStep)
local DayEndStep = require(script.Parent.Steps.DayEndStep)

type MatchState = Types.MatchState
type StepContext = Step.StepContext

-- One step's run, as a plain function. Every step class is its own Luau
-- type (each `typeof(setmetatable(...))`), so the pipeline holds runners
-- instead of the objects: one uniform type for the list, and the call site
-- stays checked.
export type Runner = (MatchState, StepContext) -> ()

-- Wraps a step object. This `any` is the one place where a step's own type
-- is not visible; the runner signature still pins what it is called with.
local function runner(step: any): Runner
	return function(state: MatchState, ctx: StepContext)
		step:run(state, ctx)
	end
end

local ResolutionPipeline = {}
ResolutionPipeline.__index = ResolutionPipeline

-- The steps of section 10, in order.
local function defaultSteps(): { Runner }
	return {
		runner(LockDraftsStep.new()), -- R1
		runner(LobbyStep.new()), -- R2
		runner(StubStep.new("Bills")), -- R3 (M3-T2/T3)
		runner(BuildStep.new()), -- R4
		runner(ProductionStep.new()), -- R5
		runner(MarketStep.new()), -- R6
		runner(TaxesStep.new()), -- R7
		runner(PublicServicesStep.new()), -- R8
		runner(UpkeepStep.new()), -- R9
		runner(InfluenceStep.new()), -- R10
		runner(StubStep.new("Promises")), -- R11 (M4)
		runner(StubStep.new("Scoring")), -- R12 (M5)
		runner(StubStep.new("VictoryCheck")), -- R13 (M5)
		runner(DayEndStep.new()), -- R14
	}
end

function ResolutionPipeline.new(): ResolutionPipeline
	return setmetatable({ _steps = defaultSteps() } :: { _steps: { Runner } }, ResolutionPipeline)
end

export type ResolutionPipeline = typeof(setmetatable(
	{} :: { _steps: { Runner } },
	ResolutionPipeline
))

-- Runs every step over the state it is given, in order.
function ResolutionPipeline.run(self: ResolutionPipeline, state: MatchState, ctx: StepContext)
	for _, run in self._steps do
		run(state, ctx)
	end
end

return ResolutionPipeline
