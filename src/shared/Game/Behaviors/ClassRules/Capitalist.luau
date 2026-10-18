--!strict
-- Capitalist class rules.

local Types = require(script.Parent.Parent.Parent.Types)
local ClassRules = require(script.Parent.ClassRules)

local CapitalistRules = setmetatable({}, { __index = ClassRules })
CapitalistRules.__index = CapitalistRules

function CapitalistRules.new(config: any)
	return setmetatable(ClassRules.new(config), CapitalistRules)
end

function CapitalistRules:getStartResources(): { [Types.ResourceId]: number }
	return self._config.startResources or {}
end

function CapitalistRules:getNeeds(): { [Types.ResourceId]: number } return self._config.needs or {} end

function CapitalistRules:getMaxLines(): number return self._config.maxLines or 5 end

function CapitalistRules:getVictoryConditions(): { string }
	return self._config.victoryConditions or { "HighStability", "HighVP" }
end

return CapitalistRules
