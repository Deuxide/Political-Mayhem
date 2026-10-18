--!strict
-- Wage policy: sets minimum wage per slot.

local Types = require(script.Parent.Parent.Parent.Types)
local Policy = require(script.Parent.Policy)

local WagePolicy = setmetatable({}, { __index = Policy })
WagePolicy.__index = WagePolicy

function WagePolicy.new(trackId: string, config: any)
	return setmetatable(Policy.new(trackId, config), WagePolicy)
end

function WagePolicy:apply(state: Types.MatchState, level: number, ruleSet: any): ()
	-- Wage policy effect is applied during Production step (R5)
	-- Level determines minimum wage per slot
	-- This is a placeholder; actual effect in Steps/Production
	local minWage = level * (self._config.wagePerLevel or 1)
	-- Store in policyState for reference
	state.policyState.tracks[self._trackId].level = level
end

return WagePolicy
