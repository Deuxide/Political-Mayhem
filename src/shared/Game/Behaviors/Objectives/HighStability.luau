--!strict
-- High Stability objective.

local Types = require(script.Parent.Parent.Parent.Types)
local Objective = require(script.Parent.Objective)

local HighStability = setmetatable({}, { __index = Objective })
HighStability.__index = HighStability

function HighStability.new(config: any)
	return setmetatable(Objective.new("HighStability", config), HighStability)
end

function HighStability:evaluate(state: Types.MatchState, classId: Types.ClassId): boolean
	local classState = state.classes[classId]
	if not classState then return false end
	local threshold = self._config.threshold or 80
	return classState.stability >= threshold
end

function HighStability:getProgress(state: Types.MatchState, classId: Types.ClassId): number
	local classState = state.classes[classId]
	if not classState then return 0 end
	local threshold = self._config.threshold or 80
	return math.clamp(classState.stability / threshold, 0, 1)
end

return HighStability
