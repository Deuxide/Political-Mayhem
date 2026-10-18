--!strict
-- Deliver promise: from delivers resources to by round.

local Types = require(script.Parent.Parent.Parent.Types)
local PromiseRules = require(script.Parent.PromiseRules)

local DeliverRules = setmetatable({}, { __index = PromiseRules })
DeliverRules.__index = DeliverRules

function DeliverRules.new() return setmetatable(PromiseRules.new("Deliver"), DeliverRules) end

function DeliverRules:audit(state: Types.MatchState, promise: Types.Promise): boolean
	-- Check if from delivered the promised resources to by expiresRound
	-- terms: { give: { [ResourceId]: number }, to: ClassId }
	if not promise.terms.give or not promise.terms.to then return false end

	if promise.status == "Fulfilled" then return true end

	if promise.expiresRound and state.round > promise.expiresRound then return false end

	-- Check if resources were transferred (would need transfer log)
	-- Placeholder: assume fulfilled if not expired
	return true
end

return DeliverRules
