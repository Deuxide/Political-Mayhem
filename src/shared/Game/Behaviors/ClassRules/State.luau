--!strict
-- State class rules.

local Types = require(script.Parent.Parent.Parent.Types)
local ClassRules = require(script.Parent.ClassRules)

local StateRules = setmetatable({}, { __index = ClassRules })
StateRules.__index = StateRules

function StateRules.new(config: any) return setmetatable(ClassRules.new(config), StateRules) end

function StateRules:getStartResources(): { [Types.ResourceId]: number }
	return self._config.startResources or {}
end

function StateRules:getNeeds(): { [Types.ResourceId]: number } return self._config.needs or {} end

function StateRules:getMaxLines(): number return self._config.maxLines or 5 end

function StateRules:getVictoryConditions(): { string }
	return self._config.victoryConditions or { "HighStability", "HighVP" }
end

return StateRules
