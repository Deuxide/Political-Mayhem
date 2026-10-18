--!strict
-- NoStrike promise: from refrains from striking target's lines.

local Types = require(script.Parent.Parent.Parent.Types)
local PromiseRules = require(script.Parent.PromiseRules)

local NoStrikeRules = setmetatable({}, { __index = PromiseRules })
NoStrikeRules.__index = NoStrikeRules

function NoStrikeRules.new() return setmetatable(PromiseRules.new("NoStrike"), NoStrikeRules) end

function NoStrikeRules:audit(state: Types.MatchState, promise: Types.Promise): boolean
	-- terms: { targetClass: ClassId, lineIds?: { string } }
	if not promise.terms.targetClass then return false end

	if promise.status == "Fulfilled" then return true end

	-- Check if from struck any of target's lines during promise period
	-- Would need strike history
	return true -- Placeholder
end

return NoStrikeRules
