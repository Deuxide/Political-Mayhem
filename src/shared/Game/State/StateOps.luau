--!strict
-- Safe resource math, CLASS_ORDER, deepCopy for plain state tables.

local Types = require(script.Parent.Parent.Types)

export type StateOps = {
	deepCopy: <T>(self: StateOps, value: T) -> T,
	addResource: (
		self: StateOps,
		state: Types.ClassState,
		resource: Types.ResourceId,
		amount: number
	) -> boolean,
	subtractResource: (
		self: StateOps,
		state: Types.ClassState,
		resource: Types.ResourceId,
		amount: number
	) -> boolean,
	setResource: (
		self: StateOps,
		state: Types.ClassState,
		resource: Types.ResourceId,
		amount: number
	) -> boolean,
	getResource: (self: StateOps, state: Types.ClassState, resource: Types.ResourceId) -> number,
	transferResource: (
		self: StateOps,
		from: Types.ClassState,
		to: Types.ClassState,
		resource: Types.ResourceId,
		amount: number
	) -> boolean,
	CLASS_ORDER: { Types.ClassId },
}

local StateOps = {}
StateOps.__index = StateOps

StateOps.CLASS_ORDER = { "Working", "Middle", "Capitalist", "State" }

function StateOps.new(): StateOps return setmetatable({}, StateOps) end

function StateOps:deepCopy<T>(value: T): T
	if type(value) ~= "table" then return value end
	local copy: any = {}
	for k, v in pairs(value) do
		if type(k) == "string" or type(k) == "number" then copy[k] = self:deepCopy(v) end
	end
	return copy
end

function StateOps:addResource(
	state: Types.ClassState,
	resource: Types.ResourceId,
	amount: number
): boolean
	if amount < 0 then return self:subtractResource(state, resource, -amount) end
	state.resources[resource] = (state.resources[resource] or 0) + amount
	return true
end

function StateOps:subtractResource(
	state: Types.ClassState,
	resource: Types.ResourceId,
	amount: number
): boolean
	if amount < 0 then return self:addResource(state, resource, -amount) end
	local current = state.resources[resource] or 0
	if current < amount then return false end
	state.resources[resource] = current - amount
	return true
end

function StateOps:setResource(
	state: Types.ClassState,
	resource: Types.ResourceId,
	amount: number
): boolean
	if amount < 0 then return false end
	state.resources[resource] = amount
	return true
end

function StateOps:getResource(state: Types.ClassState, resource: Types.ResourceId): number
	return state.resources[resource] or 0
end

function StateOps:transferResource(
	from: Types.ClassState,
	to: Types.ClassState,
	resource: Types.ResourceId,
	amount: number
): boolean
	if not self:subtractResource(from, resource, amount) then return false end
	self:addResource(to, resource, amount)
	return true
end

return StateOps
