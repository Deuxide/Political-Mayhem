--!strict
-- Strike Rights policy: determines if strikes are legal and penalties.

local Types = require(script.Parent.Parent.Parent.Types)
local Policy = require(script.Parent.Policy)

local StrikeRightsPolicy = setmetatable({}, { __index = Policy })
StrikeRightsPolicy.__index = StrikeRightsPolicy

function StrikeRightsPolicy.new(trackId: string, config: any)
	return setmetatable(Policy.new(trackId, config), StrikeRightsPolicy)
end

function StrikeRightsPolicy:apply(state: Types.MatchState, level: number, ruleSet: any): ()
	-- Applied during Production (strikes) and Promises steps
	-- Level 0 = outlawed, 1 = restricted, 2 = protected
	state.policyState.tracks[self._trackId].level = level
end

return StrikeRightsPolicy
