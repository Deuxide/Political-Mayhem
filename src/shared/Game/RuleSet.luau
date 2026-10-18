--!strict
-- Difficulty and config-driven rule answers. Stateless.

local Types = require(script.Parent.Types)

export type RuleSet = {
	_difficulty: Types.Difficulty,
	_config: any, -- Config tables from shared/Config
	isPolicyEnabled: (self: RuleSet, trackId: string) -> boolean,
	getMarketCap: (self: RuleSet, resource: Types.ResourceId) -> number,
	getNeedsMultiplier: (self: RuleSet) -> number,
	getCollapseEnabled: (self: RuleSet) -> boolean,
	getRoundTime: (self: RuleSet) -> number,
	getMaxLines: (self: RuleSet, classId: Types.ClassId) -> number,
}

local RuleSet = {}
RuleSet.__index = RuleSet

function RuleSet.new(difficulty: Types.Difficulty, config: any): RuleSet
	local self = setmetatable({}, RuleSet)
	self._difficulty = difficulty
	self._config = config
	return self
end

function RuleSet:isPolicyEnabled(trackId: string): boolean
	local diffConfig = self._config.Difficulty[self._difficulty]
	if diffConfig.disabledPolicies then
		for _, disabled in ipairs(diffConfig.disabledPolicies) do
			if disabled == trackId then return false end
		end
	end
	return true
end

function RuleSet:getMarketCap(resource: Types.ResourceId): number
	local marketConfig = self._config.Market
	local cap = marketConfig.caps and marketConfig.caps[resource]
	return cap or math.huge
end

function RuleSet:getNeedsMultiplier(): number
	local diffConfig = self._config.Difficulty[self._difficulty]
	return diffConfig.needsMultiplier or 1
end

function RuleSet:getCollapseEnabled(): boolean
	return self._difficulty == "Hard" or self._difficulty == "Extreme"
end

function RuleSet:getRoundTime(): number
	local diffConfig = self._config.Difficulty[self._difficulty]
	return diffConfig.roundTimeSeconds or 90
end

function RuleSet:getMaxLines(classId: Types.ClassId): number
	local classConfig = self._config.Classes[classId]
	return classConfig.maxLines or 5
end

return RuleSet
