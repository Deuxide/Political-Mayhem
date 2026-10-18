--!strict
-- Trade operations: validate, execute atomically, re-check affordability.

local Types = require(script.Parent.Parent.Types)
local StateOps = require(script.Parent.Parent.State.StateOps)

export type Trade = {
	validateOffer: (state: Types.MatchState, offer: Types.TradeOffer) -> (boolean, string?),
	execute: (
		state: Types.MatchState,
		offer: Types.TradeOffer,
		stateOps: StateOps.StateOps
	) -> (boolean, string?),
}

local Trade = {}

function Trade.validateOffer(state: Types.MatchState, offer: Types.TradeOffer): (boolean, string?)
	local fromState = state.classes[offer.from]
	local toState = state.classes[offer.to]

	if not fromState or not toState then return false, "Invalid class in trade" end

	if offer.status ~= "Accepted" then return false, "Trade not accepted" end

	-- Check from has resources to give
	for resource, amount in pairs(offer.give) do
		if (fromState.resources[resource] or 0) < amount then
			return false, "Insufficient " .. resource .. " to give"
		end
	end

	-- Check to has resources to give
	for resource, amount in pairs(offer.take) do
		if (toState.resources[resource] or 0) < amount then
			return false, "Insufficient " .. resource .. " to receive"
		end
	end

	return true, nil
end

function Trade.execute(
	state: Types.MatchState,
	offer: Types.TradeOffer,
	stateOps: StateOps.StateOps
): (boolean, string?)
	local fromState = state.classes[offer.from]
	local toState = state.classes[offer.to]

	if not fromState or not toState then return false, "Invalid class in trade" end

	-- Re-check affordability at execution time
	local valid, err = Trade.validateOffer(state, offer)
	if not valid then return false, err end

	-- Execute atomically: all or nothing
	-- Give resources from -> to
	for resource, amount in pairs(offer.give) do
		stateOps:transferResource(fromState, toState, resource, amount)
	end

	-- Take resources to -> from
	for resource, amount in pairs(offer.take) do
		stateOps:transferResource(toState, fromState, resource, amount)
	end

	offer.status = "Accepted"
	return true, nil
end

return Trade
