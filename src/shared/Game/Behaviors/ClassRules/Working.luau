--!strict
-- Working class rules.

local Types = require(script.Parent.Parent.Parent.Types)
local ClassRules = require(script.Parent.ClassRules)

local WorkingRules = setmetatable({}, { __index = ClassRules })
WorkingRules.__index = WorkingRules

function WorkingRules.new(config: any) return setmetatable(ClassRules.new(config), WorkingRules) end

function WorkingRules:getStartResources(): { [Types.ResourceId]: number }
	return self._config.startResources or {}
end

function WorkingRules:getNeeds(): { [Types.ResourceId]: number } return self._config.needs or {} end

function WorkingRules:getMaxLines(): number return self._config.maxLines or 5 end

function WorkingRules:getVictoryConditions(): { string }
	return self._config.victoryConditions or { "HighStability", "HighVP" }
end

return WorkingRules
