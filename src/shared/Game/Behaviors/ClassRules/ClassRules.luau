--!strict
-- Abstract base for class-specific rules.

local Types = require(script.Parent.Parent.Parent.Types)

export type ClassRules = {
	_config: any,
	new: (config: any) -> ClassRules,
	getStartResources: (self: ClassRules) -> { [Types.ResourceId]: number },
	getNeeds: (self: ClassRules) -> { [Types.ResourceId]: number },
	getMaxLines: (self: ClassRules) -> number,
	getVictoryConditions: (self: ClassRules) -> { string },
}

local ClassRules = {}
ClassRules.__index = ClassRules

function ClassRules.new(config: any) return setmetatable({ _config = config }, ClassRules) end

function ClassRules:getStartResources(): { [Types.ResourceId]: number }
	error("not implemented: ClassRules:getStartResources")
end

function ClassRules:getNeeds(): { [Types.ResourceId]: number }
	error("not implemented: ClassRules:getNeeds")
end

function ClassRules:getMaxLines(): number error("not implemented: ClassRules:getMaxLines") end

function ClassRules:getVictoryConditions(): { string }
	error("not implemented: ClassRules:getVictoryConditions")
end

return ClassRules
