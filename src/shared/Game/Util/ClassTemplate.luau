--!strict
-- Class template demonstrating ARCHITECTURE.md section 3.1 conventions.
-- This is a reference file; copy and modify for new classes.

--[[
Conventions:
- One class per file; file name = class name
- ClassName.new(...) constructor
- : for methods, . for statics
- _private fields prefixed with _
- Exported instance type
- --!strict at top
- Abstract methods error with "not implemented: ClassName:method"
- Inject dependencies; no globals, no _G, no hidden singletons
- Never reach into another object's _field
]]

local abstract = require(script.Parent.Util.abstract)

export type ExampleClass = {
	_config: any,
	_dependency: any,

	new: (config: any, dependency: any) -> ExampleClass,
	publicMethod: (self: ExampleClass, arg: string) -> number,
	privateMethod: (self: ExampleClass) -> (),
}

local ExampleClass = {}
ExampleClass.__index = ExampleClass

-- Constructor: inject dependencies, store config
function ExampleClass.new(config: any, dependency: any): ExampleClass
	local self = setmetatable({}, ExampleClass)
	self._config = config
	self._dependency = dependency
	return self
end

-- Public method using :
function ExampleClass:publicMethod(arg: string): number
	self:_privateMethod()
	return #arg + (self._config.multiplier or 1)
end

-- Private method (convention: _ prefix)
function ExampleClass:_privateMethod()
	-- Access own _fields only
	print("Private method called, config:", self._config.name)
end

-- Abstract method example (if this were a base class)
-- function ExampleClass:abstractMethod()
--     abstract("ExampleClass:abstractMethod")
-- end

return ExampleClass
