--!strict
-- Public Services policy: determines service funding and distribution.

local Types = require(script.Parent.Parent.Parent.Types)
local Policy = require(script.Parent.Policy)

local PublicServicesPolicy = setmetatable({}, { __index = Policy })
PublicServicesPolicy.__index = PublicServicesPolicy

function PublicServicesPolicy.new(trackId: string, config: any)
	return setmetatable(Policy.new(trackId, config), PublicServicesPolicy)
end

function PublicServicesPolicy:apply(state: Types.MatchState, level: number, ruleSet: any): ()
	-- Applied during PublicServices step (R8)
	state.policyState.tracks[self._trackId].level = level
end

return PublicServicesPolicy
