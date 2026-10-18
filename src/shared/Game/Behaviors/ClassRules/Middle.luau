--!strict
-- Middle class rules.

local Types = require(script.Parent.Parent.Parent.Types)
local ClassRules = require(script.Parent.ClassRules)

local MiddleRules = setmetatable({}, { __index = ClassRules })
MiddleRules.__index = MiddleRules

function MiddleRules.new(config: any) return setmetatable(ClassRules.new(config), MiddleRules) end

function MiddleRules:getStartResources(): { [Types.ResourceId]: number }
	return self._config.startResources or {}
end

function MiddleRules:getNeeds(): { [Types.ResourceId]: number } return self._config.needs or {} end

function MiddleRules:getMaxLines(): number return self._config.maxLines or 5 end

function MiddleRules:getVictoryConditions(): { string }
	return self._config.victoryConditions or { "HighStability", "HighVP" }
end

return MiddleRules
