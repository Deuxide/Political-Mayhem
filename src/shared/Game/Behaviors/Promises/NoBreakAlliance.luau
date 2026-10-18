--!strict
-- NoBreakAlliance promise: from keeps alliance with target.

local Types = require(script.Parent.Parent.Parent.Types)
local PromiseRules = require(script.Parent.PromiseRules)

local NoBreakAllianceRules = setmetatable({}, { __index = PromiseRules })
NoBreakAllianceRules.__index = NoBreakAllianceRules

function NoBreakAllianceRules.new()
	return setmetatable(PromiseRules.new("NoBreakAlliance"), NoBreakAllianceRules)
end

function NoBreakAllianceRules:audit(state: Types.MatchState, promise: Types.Promise): boolean
	-- terms: { targetClass: ClassId }
	if not promise.terms.targetClass then return false end

	if promise.status == "Fulfilled" then return true end

	-- Check if alliance still exists
	local fromState = state.classes[promise.from]
	if not fromState then return false end

	if fromState.alliances[promise.terms.targetClass] then return true end

	return false
end

return NoBreakAllianceRules
