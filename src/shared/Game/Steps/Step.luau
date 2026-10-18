--!strict
-- Abstract base class for resolution pipeline steps.
-- Each step is a stateless strategy class with run(state, ctx) method.

local Types = require(script.Parent.Types)
local abstract = require(script.Parent.Util.abstract)

export type Step = {
	_name: string,
	run: (
		self: Step,
		state: Types.MatchState,
		ctx: {
			rng: any,
			ruleSet: any,
			stateOps: any,
			trace: { Types.LogEntry },
		}
	) -> (),
}

local Step = {}
Step.__index = Step

function Step.new(name: string): Step return setmetatable({ _name = name }, Step) end

function Step:run(state: Types.MatchState, ctx: any): () abstract("Step:run") end

return Step
