--!strict
-- Factory line rules. Output depends on owner's Education stock.

local Types = require(script.Parent.Parent.Parent.Types)
local LineRules = require(script.Parent.LineRules)

local FactoryRules = setmetatable({}, { __index = LineRules })
FactoryRules.__index = FactoryRules

function FactoryRules.new(config: Types.LineConfig)
	return setmetatable(LineRules.new(config), FactoryRules)
end

function FactoryRules:output(
	line: Types.LineState,
	owner: Types.ClassState,
	staffed: number
): number
	local base = staffed * (self._config.outputPerSlot or 3)
	if (owner.resources.Education or 0) < 1 then return math.floor(base / 2) end
	return base
end

function FactoryRules:wageCost(staffed: number): number
	return staffed * (self._config.wagePerSlot or 2)
end

function FactoryRules:canStrike(): boolean return true end

function FactoryRules:strikeEffect(line: Types.LineState, owner: Types.ClassState): ()
	line.active = false
end

return FactoryRules
