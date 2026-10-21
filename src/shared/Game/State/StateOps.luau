--!strict
-- The sanctioned arithmetic over class resources (ARCHITECTURE 3.1
-- "Operations"; GAME_DESIGN section 10): steps and live actions mutate
-- resource fields only through these helpers.
-- Contract: an insufficiency (would go negative) returns false and changes
-- nothing — gameplay-invalid actions are skipped and logged, never thrown;
-- wrong keys (unknown class/resource, missing stock key, negative or
-- non-finite amount) are programming errors and raise.
-- Resource ids are the six Config/Resources ids; the stock-key mapping stays
-- there (D-008), never duplicated here.

local Types = require(script.Parent.Parent.Types)
local ConfigResources = require(script.Parent.Parent.Parent.Config.Resources)

type MatchState = Types.MatchState
type ClassId = Types.ClassId
type ClassState = Types.ClassState
type ResourceId = Types.ResourceId
type Line = Types.Line

export type ResourceTransfer = {
	classId: ClassId,
	resource: ResourceId,
	amount: number,
}

local StateOps = {}

-- GAME_DESIGN 10: every step processes classes in this exact order.
StateOps.CLASS_ORDER = Types.CLASS_IDS :: { ClassId }

local function classOf(state: MatchState, classId: ClassId): ClassState
	local class = state.classes[classId]
	if class == nil then
		error(`StateOps: unknown class '{tostring(classId)}'`, 0)
	end
	return class :: ClassState
end

-- "Guard" here means programming errors are impossible to route silently:
-- NaN fails the self-inequality check, ±infinity fails the equality bounds.
local function assertAmount(resource: string, amount: number)
	if amount ~= amount or amount == math.huge or amount == -math.huge then
		error(`StateOps: non-finite amount for '{resource}'`, 0)
	end
	if amount < 0 then
		error(`StateOps: negative amount for '{resource}'`, 0)
	end
end

-- Resolves where a resource lives: (holder table, field key). The holder is
-- the ClassState for money/influence and the stock table for stocks; the key
-- is always a string field or stock id. `any` typed: two record shapes share
-- the same keyed access, and the ids are validated right above.
local function targetOf(class: ClassState, resource: ResourceId): (any, string)
	local info = (ConfigResources :: any)[resource]
	if info == nil then
		error(`StateOps: unknown resource '{tostring(resource)}'`, 0)
	end
	local stockKey = info.stockKey :: string?
	if stockKey == nil then
		if resource == "Money" then
			-- the info table is frozen config data; write into the state
			return class, "money"
		elseif resource == "Influence" then
			return class, "influence"
		end
		error(`StateOps: resource '{resource}' has no stock key in Config/Resources`, 0)
	end
	if (class.stock :: any)[stockKey] == nil then
		error(`StateOps: class stock is missing key '{stockKey}'`, 0)
	end
	return class.stock, stockKey
end

-- Returns the receiving field's current value, raising on missing stock keys
-- (strict-missing: missing state keys are corruption, not insufficiency).
local function valueAt(class: ClassState, resource: ResourceId): number
	local target, key = targetOf(class, resource)
	return target[key]
end

function StateOps.addResource(
	state: MatchState,
	classId: ClassId,
	resource: ResourceId,
	amount: number
): boolean
	assertAmount(resource, amount)
	local class = classOf(state, classId)
	local target, key = targetOf(class, resource)
	target[key] = target[key] + amount
	return true
end

function StateOps.subtractResource(
	state: MatchState,
	classId: ClassId,
	resource: ResourceId,
	amount: number
): boolean
	assertAmount(resource, amount)
	local class = classOf(state, classId)
	local target, key = targetOf(class, resource)
	local after = target[key] - amount
	if after < 0 then
		-- never-negative: leave the state untouched so the caller logs/skips
		return false
	end
	target[key] = after
	return true
end

-- Reads the current value for a transfer check without math (used by steps
-- that validate before paying). Raises on wrong keys like the mutators.
function StateOps.resourceValue(state: MatchState, classId: ClassId, resource: ResourceId): number
	local class = classOf(state, classId)
	return valueAt(class, resource)
end

-- Generic deep copy: state is plain data (strings/int keys, primitives) per
-- the serializable contract, so plain recursion is safe and complete.
local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy: { [any]: any } = {}
	for key, item in value do
		copy[key] = deepCopy(item)
	end
	return copy
end

-- Snapshot helper (ARCHITECTURE: "Snapshot = StateOps.deepCopy(state)").
-- Await-free pure copy step: copying never yields, so Resolve can snapshot
-- and roll back its working copy atomically.
function StateOps.deepCopy(state: MatchState): MatchState
	return deepCopy(state) :: MatchState
end

-- Registers one newly built line (R4 Build ids are unique across the match,
-- so replacing an existing id would be corruption, not an overwrite). The
-- line itself is plain data already shaped by the caller; this is the single
-- mutation point for growing state.lines during resolution.
function StateOps.addLine(state: MatchState, line: Line)
	if state.lines[line.id] ~= nil then
		error(`StateOps: line id '{line.id}' already exists`, 0)
	end
	state.lines[line.id] = line
end

return table.freeze(StateOps)
