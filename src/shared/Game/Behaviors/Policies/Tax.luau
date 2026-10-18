--!strict
-- Tax policy: sets tax rates per class.

local Types = require(script.Parent.Parent.Parent.Types)
local Policy = require(script.Parent.Policy)

local TaxPolicy = setmetatable({}, { __index = Policy })
TaxPolicy.__index = TaxPolicy

function TaxPolicy.new(trackId: string, config: any)
	return setmetatable(Policy.new(trackId, config), TaxPolicy)
end

function TaxPolicy:apply(state: Types.MatchState, level: number, ruleSet: any): ()
	-- Tax rates applied during Taxes step (R7)
	state.policyState.tracks[self._trackId].level = level
end

return TaxPolicy
