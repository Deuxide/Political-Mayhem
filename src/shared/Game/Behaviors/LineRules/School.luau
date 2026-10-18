--!strict
-- School line rules.

local Types = require(script.Parent.Parent.Parent.Types)
local LineRules = require(script.Parent.LineRules)

local SchoolRules = setmetatable({}, { __index = LineRules })
SchoolRules.__index = SchoolRules

function SchoolRules.new(config: Types.LineConfig)
	return setmetatable(LineRules.new(config), SchoolRules)
end

function SchoolRules:output(
	line: Types.LineState,
	owner: Types.ClassState,
	staffed: number
): number
	return staffed * (self._config.outputPerSlot or 1)
end

function SchoolRules:wageCost(staffed: number): number
	return staffed * (self._config.wagePerSlot or 1)
end

function SchoolRules:canStrike(): boolean return true end

function SchoolRules:strikeEffect(line: Types.LineState, owner: Types.ClassState): ()
	line.active = false
end

return SchoolRules
