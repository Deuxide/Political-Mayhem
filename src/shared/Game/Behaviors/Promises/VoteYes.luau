--!strict
-- VoteYes promise: from votes yes on a specific bill.

local Types = require(script.Parent.Parent.Parent.Types)
local PromiseRules = require(script.Parent.PromiseRules)

local VoteYesRules = setmetatable({}, { __index = PromiseRules })
VoteYesRules.__index = VoteYesRules

function VoteYesRules.new() return setmetatable(PromiseRules.new("VoteYes"), VoteYesRules) end

function VoteYesRules:audit(state: Types.MatchState, promise: Types.Promise): boolean
	-- terms: { billId: string }
	if not promise.terms.billId then return false end

	if promise.status == "Fulfilled" then return true end

	-- Check if bill was voted on and from voted yes
	-- Would need bill vote history
	return true -- Placeholder
end

return VoteYesRules
