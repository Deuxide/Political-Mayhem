--!strict
-- Registry for all policy types. Lookup by trackId.

local Types = require(script.Parent.Parent.Parent.Types)
local Policy = require(script.Parent.Policy)
local WagePolicy = require(script.Parent.Wage)
local TaxPolicy = require(script.Parent.Tax)
local PublicServicesPolicy = require(script.Parent.PublicServices)
local TariffPolicy = require(script.Parent.Tariff)
local StrikeRightsPolicy = require(script.Parent.StrikeRights)

export type PolicyRegistry = {
	_policies: { [string]: Policy.Policy },
	get: (self: PolicyRegistry, trackId: string) -> Policy.Policy?,
	register: (self: PolicyRegistry, trackId: string, policy: Policy.Policy) -> (),
	allEnabled: (self: PolicyRegistry, difficulty: Types.Difficulty) -> { Policy.Policy },
}

local PolicyRegistry = {}
PolicyRegistry.__index = PolicyRegistry

function PolicyRegistry.new(config: any): PolicyRegistry
	local self = setmetatable({ _policies = {} }, PolicyRegistry)
	self:register("Wage", WagePolicy.new("Wage", config.Policies.tracks.Wage))
	self:register("Tax", TaxPolicy.new("Tax", config.Policies.tracks.Tax))
	self:register(
		"PublicServices",
		PublicServicesPolicy.new("PublicServices", config.Policies.tracks.PublicServices)
	)
	self:register("Tariff", TariffPolicy.new("Tariff", config.Policies.tracks.Tariff))
	self:register(
		"StrikeRights",
		StrikeRightsPolicy.new("StrikeRights", config.Policies.tracks.StrikeRights)
	)
	return self
end

function PolicyRegistry:get(trackId: string): Policy.Policy? return self._policies[trackId] end

function PolicyRegistry:register(trackId: string, policy: Policy.Policy)
	self._policies[trackId] = policy
end

function PolicyRegistry:allEnabled(difficulty: Types.Difficulty): { Policy.Policy }
	local result = {}
	for _, policy in pairs(self._policies) do
		if policy:isEnabledForDifficulty(difficulty) then table.insert(result, policy) end
	end
	return result
end

return PolicyRegistry
