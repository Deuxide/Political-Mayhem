--!strict
-- Tariff policy: affects market prices for imports/exports.

local Types = require(script.Parent.Parent.Parent.Types)
local Policy = require(script.Parent.Policy)

local TariffPolicy = setmetatable({}, { __index = Policy })
TariffPolicy.__index = TariffPolicy

function TariffPolicy.new(trackId: string, config: any)
	return setmetatable(Policy.new(trackId, config), TariffPolicy)
end

function TariffPolicy:apply(state: Types.MatchState, level: number, ruleSet: any): ()
	-- Applied during Market step (R6)
	state.policyState.tracks[self._trackId].level = level
end

return TariffPolicy
