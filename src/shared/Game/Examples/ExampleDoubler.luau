--!strict
-- Example subclass of ExampleRule (M1-T0): depth 1, adds its one private
-- config field and implements the abstract hook. Nothing else registers or
-- uses this family.

local ExampleRule = require(script.Parent.ExampleRule)

local ExampleDoubler = setmetatable({}, { __index = ExampleRule })
ExampleDoubler.__index = ExampleDoubler

function ExampleDoubler.new(factor: number): ExampleDoubler
	return setmetatable({ _name = "ExampleDoubler", _factor = factor }, ExampleDoubler)
end

function ExampleDoubler.apply(self: ExampleDoubler, value: number): number
	return value * self._factor
end

export type ExampleDoubler = typeof(setmetatable(
	{} :: {
		_name: string,
		_factor: number,
	},
	ExampleDoubler
))

return ExampleDoubler
