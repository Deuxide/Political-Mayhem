--!strict
-- Transfers (GAME_DESIGN 8.1): the primitive every trade and every promise
-- fulfilment is built on. A transfer is legal when the sender holds the
-- resources; it then moves them all at once, or not at all.
--
-- The module never reads a clock and never throws for a player action: a
-- refused transfer comes back with a reason the caller can show.
local Types = require(script.Parent.Parent.Types)
local StateOps = require(script.Parent.Parent.State.StateOps)

type ClassId = Types.ClassId
type MatchState = Types.MatchState
type ResourceBag = Types.ResourceBag
type ResourceId = Types.ResourceId

-- One resource of a bag, in the fixed resource order.
type BagEntry = {
	resourceId: ResourceId,
	amount: number,
}

local Transfers = {}

-- The resources of a bag as a list, in the fixed resource order.
local function bagEntries(bag: ResourceBag): { BagEntry }
	local entries: { BagEntry } = {}
	for si = 1, #Types.RESOURCE_IDS do
		local resourceId: ResourceId = Types.RESOURCE_IDS[si] :: any
		local amount = bag[resourceId]
		if amount ~= nil and amount ~= 0 then
			table.insert(entries, { resourceId = resourceId, amount = amount })
		end
	end
	return entries
end

-- Whether every amount in the bag is a whole number of at least zero.
function Transfers.isWellFormed(bag: ResourceBag): (boolean, string)
	for _, entry in bagEntries(bag) do
		if entry.amount ~= math.floor(entry.amount) or entry.amount < 0 then
			return false, `the amount of {entry.resourceId} must be a whole number`
		end
	end
	return true, ""
end

-- Whether a class holds everything the bag asks for, and why not.
function Transfers.canAfford(
	state: MatchState,
	classId: ClassId,
	bag: ResourceBag
): (boolean, string)
	for _, entry in bagEntries(bag) do
		if entry.amount ~= math.floor(entry.amount) or entry.amount < 0 then
			return false, `the amount of {entry.resourceId} must be a whole number`
		end
		if StateOps.resourceValue(state, classId, entry.resourceId) < entry.amount then
			return false, `{classId} does not have {entry.amount} {entry.resourceId}`
		end
	end
	return true, ""
end

-- Moves the resources from one class to another. The bag is checked first,
-- so the moves themselves cannot fail and the transfer is all or nothing.
function Transfers.execute(
	state: MatchState,
	from: ClassId,
	to: ClassId,
	bag: ResourceBag
): (boolean, string)
	if from == to then
		return false, "a class cannot transfer to itself"
	end

	local affordable, reason = Transfers.canAfford(state, from, bag)
	if not affordable then
		return false, reason
	end

	for _, entry in bagEntries(bag) do
		StateOps.subtractResource(state, from, entry.resourceId, entry.amount)
	end
	for _, entry in bagEntries(bag) do
		StateOps.addResource(state, to, entry.resourceId, entry.amount)
	end

	return true, ""
end

return Transfers
