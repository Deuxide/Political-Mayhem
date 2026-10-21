--!strict
-- Difficulty answers (ARCHITECTURE 3.1 "Objects"): wraps one Config/Difficulty
-- entry at Match creation. Game code reads flags and selectors through this
-- class, never difficulty names (M5-T3) and never the config table directly.
-- Also the single home for "is this a known difficulty" validation.

local Types = require(script.Parent.Types)
local ConfigDifficulty = require(script.Parent.Parent.Config.Difficulty)

type Difficulty = Types.Difficulty
type InfoMode = Types.InfoMode
type PolicyId = Types.PolicyId
type HintLevel = ConfigDifficulty.HintLevel
type DifficultyEntry = ConfigDifficulty.DifficultyEntry

local RuleSet = {}
RuleSet.__index = RuleSet

function RuleSet.new(difficulty: Difficulty): RuleSet
	for _, known in Types.DIFFICULTIES do
		if known == difficulty then
			return setmetatable(
				{ _entry = ConfigDifficulty[difficulty] :: DifficultyEntry } :: { _entry: DifficultyEntry },
				RuleSet
			)
		end
	end
	error(`RuleSet.new: unknown difficulty '{difficulty}'`, 0)
end

export type RuleSet = typeof(setmetatable(
	{} :: {
		_entry: DifficultyEntry,
	},
	RuleSet
))

function RuleSet.rounds(self: RuleSet): number
	return self._entry.rounds
end

function RuleSet.windowSeconds(self: RuleSet): number
	return self._entry.windowSeconds
end

function RuleSet.revealSeconds(self: RuleSet): number
	return self._entry.revealSeconds
end

function RuleSet.soloTarget(self: RuleSet): number
	return self._entry.soloTarget
end

function RuleSet.isPolicyEnabled(self: RuleSet, policyId: PolicyId): boolean
	for _, enabled in self._entry.policiesEnabled do
		if enabled == policyId then
			return true
		end
	end
	return false
end

function RuleSet.infoMode(self: RuleSet): InfoMode
	return self._entry.infoMode
end

function RuleSet.eventsEnabled(self: RuleSet): boolean
	return self._entry.eventsEnabled
end

function RuleSet.eventsForecast(self: RuleSet): boolean
	return self._entry.eventsForecast
end

function RuleSet.collapseEnabled(self: RuleSet): boolean
	return self._entry.collapseEnabled
end

function RuleSet.hints(self: RuleSet): HintLevel
	return self._entry.hints
end

function RuleSet.startResourceMultiplier(self: RuleSet): number
	return self._entry.startResourceMultiplier
end

function RuleSet.needsMultiplier(self: RuleSet): number
	return self._entry.needsMultiplier
end

function RuleSet.botSuggestions(self: RuleSet): boolean
	return self._entry.botSuggestions
end

return RuleSet
