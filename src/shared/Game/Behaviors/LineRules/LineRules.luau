--!strict
-- Abstract base for production line rules.

local Types = require(script.Parent.Parent.Parent.Types)

export type LineRules = {
	_config: Types.LineConfig,
	new: (config: Types.LineConfig) -> LineRules,
	output: (
		self: LineRules,
		line: Types.LineState,
		owner: Types.ClassState,
		staffed: number
	) -> number,
	wageCost: (self: LineRules, staffed: number) -> number,
	canStrike: (self: LineRules) -> boolean,
	strikeEffect: (self: LineRules, line: Types.LineState, owner: Types.ClassState) -> (),
}

local LineRules = {}
LineRules.__index = LineRules

function LineRules.new(config: Types.LineConfig)
	return setmetatable({ _config = config }, LineRules)
end

function LineRules:output(
	line: Types.LineState,
	owner: Types.ClassState,
	staffed: number
): number
	error("not implemented: LineRules:output")
end

function LineRules:wageCost(staffed: number): number error("not implemented: LineRules:wageCost") end

function LineRules:canStrike(): boolean error("not implemented: LineRules:canStrike") end

function LineRules:strikeEffect(line: Types.LineState, owner: Types.ClassState): ()
	error("not implemented: LineRules:strikeEffect")
end

return LineRules
