--!strict
-- Generic resource transfer operations (used by trade, promises, etc.).

local Types = require(script.Parent.Parent.Types)
local StateOps = require(script.Parent.Parent.State.StateOps)

export type Transfers = {
	canAfford: (state: Types.ClassState, cost: { [Types.ResourceId]: number }) -> boolean,
	payCost: (
		state: Types.ClassState,
		cost: { [Types.ResourceId]: number },
		stateOps: StateOps.StateOps
	) -> boolean,
	grantRewards: (
		state: Types.ClassState,
		rewards: { [Types.ResourceId]: number },
		stateOps: StateOps.StateOps
	) -> (),
}

local Transfers = {}

function Transfers.canAfford(state: Types.ClassState, cost: { [Types.ResourceId]: number }): boolean
	for resource, amount in pairs(cost) do
		if (state.resources[resource] or 0) < amount then return false end
	end
	return true
end

function Transfers.payCost(
	state: Types.ClassState,
	cost: { [Types.ResourceId]: number },
	stateOps: StateOps.StateOps
): boolean
	-- Check first
	if not Transfers.canAfford(state, cost) then return false end
	-- Pay
	for resource, amount in pairs(cost) do
		stateOps:subtractResource(state, resource, amount)
	end
	return true
end

function Transfers.grantRewards(
	state: Types.ClassState,
	rewards: { [Types.ResourceId]: number },
	stateOps: StateOps.StateOps
)
	for resource, amount in pairs(rewards) do
		stateOps:addResource(state, resource, amount)
	end
end

return Transfers
