--!strict
-- Placeholder step for the pipeline parts a later milestone owns: R2 Lobby
-- and R10 Influence (M3-T1), R3 Bills (M3-T2), R11 Promises (M4), R12
-- Scoring and R13 VictoryCheck (M5). It honours the Step contract and
-- changes nothing, so a Day already resolves end to end; the milestone
-- that owns the step replaces it with the real one.

local Types = require(script.Parent.Parent.Types)
local Step = require(script.Parent.Step)

type StepContext = Step.StepContext

local StubStep = setmetatable({}, { __index = Step })
StubStep.__index = StubStep

function StubStep.new(name: string): StubStep
	return setmetatable({ _name = name }, StubStep)
end

export type StubStep = typeof(setmetatable({} :: { _name: string }, StubStep))

function StubStep.run(_self: StubStep, _state: Types.MatchState, _ctx: StepContext)
	return -- nothing to do until the milestone that owns this step
end

return StubStep
