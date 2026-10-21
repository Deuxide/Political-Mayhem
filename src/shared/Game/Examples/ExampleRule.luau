--!strict
-- Example behavior base (M1-T0): the class-template and behavior rules from
-- ARCHITECTURE 3.1 in code, kept as a living reference for every future
-- behavior family. Stateless: it may hold nothing beyond values handed to
-- `new`; the abstract hook raises through Abstract.notImplemented.
-- Methods are dot-defined with an explicit `self` annotation (the only form
-- luau-lsp types reliably on a plain-class table); call sites keep `:` sugar.

local Abstract = require(script.Parent.Parent.Abstract)

local ExampleRule = {}
ExampleRule.__index = ExampleRule

function ExampleRule.new(name: string): ExampleRule
	return setmetatable({ _name = name }, ExampleRule)
end

-- Abstract hook every subclass must implement.
function ExampleRule.apply(_self: ExampleRule, value: number): number
	Abstract.notImplemented("ExampleRule", "apply")
	-- The helper always throws; the type checker cannot see through user
	-- functions that throw, so this unreachable return closes the return
	-- path for the analyzer (and keeps the parameter visibly consumed).
	return value
end

-- Instance alias below the definitions so `typeof` snapshots the complete
-- metatable (Luau type aliases are order-independent).
export type ExampleRule = typeof(setmetatable(
	{} :: {
		_name: string,
	},
	ExampleRule
))

return ExampleRule
