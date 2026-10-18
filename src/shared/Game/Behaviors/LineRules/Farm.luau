--!strict
-- Farm line rules.

local Types = require(script.Parent.Parent.Parent.Types)
local LineRules = require(script.Parent.LineRules)

local FarmRules = setmetatable({}, { __index = LineRules })
FarmRules.__index = FarmRules

function FarmRules.new(config: Types.LineConfig)
	return setmetatable(LineRules.new(config), FarmRules)
end

function FarmRules:output(
	line: Types.LineState,
	owner: Types.ClassState,
	staffed: number
): number
	return staffed * (self._config.outputPerSlot or 2)
end

function FarmRules:wageCost(staffed: number): number
	return staffed * (self._config.wagePerSlot or 1)
end

function FarmRules:canStrike(): boolean return true end

function FarmRules:strikeEffect(line: Types.LineState, owner: Types.ClassState): ()
	line.active = false
end

return FarmRules
