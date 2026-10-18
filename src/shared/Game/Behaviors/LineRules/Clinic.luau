--!strict
-- Clinic line rules.

local Types = require(script.Parent.Parent.Parent.Types)
local LineRules = require(script.Parent.LineRules)

local ClinicRules = setmetatable({}, { __index = LineRules })
ClinicRules.__index = ClinicRules

function ClinicRules.new(config: Types.LineConfig)
	return setmetatable(LineRules.new(config), ClinicRules)
end

function ClinicRules:output(
	line: Types.LineState,
	owner: Types.ClassState,
	staffed: number
): number
	return staffed * (self._config.outputPerSlot or 2)
end

function ClinicRules:wageCost(staffed: number): number
	return staffed * (self._config.wagePerSlot or 2)
end

function ClinicRules:canStrike(): boolean return true end

function ClinicRules:strikeEffect(line: Types.LineState, owner: Types.ClassState): ()
	line.active = false
end

return ClinicRules
