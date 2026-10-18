--!strict
-- Abstract base for victory objectives.

local Types = require(script.Parent.Parent.Parent.Types)

export type Objective = {
	_id: string,
	_config: any,
	new: (id: string, config: any) -> Objective,
	evaluate: (self: Objective, state: Types.MatchState, classId: Types.ClassId) -> boolean,
	getProgress: (self: Objective, state: Types.MatchState, classId: Types.ClassId) -> number,
}

local Objective = {}
Objective.__index = Objective

function Objective.new(id: string, config: any)
	return setmetatable({ _id = id, _config = config }, Objective)
end

function Objective:evaluate(state: Types.MatchState, classId: Types.ClassId): boolean
	error("not implemented: Objective:evaluate")
end

function Objective:getProgress(state: Types.MatchState, classId: Types.ClassId): number
	error("not implemented: Objective:getProgress")
end

return Objective
