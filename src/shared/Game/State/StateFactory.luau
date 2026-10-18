--!strict
-- Builds the initial MatchState from config, seats, and seed.

local Types = require(script.Parent.Parent.Types)
local Rng = require(script.Parent.Parent.Rng)
local RuleSet = require(script.Parent.Parent.RuleSet)

export type StateFactory = {
	create: (
		difficulty: Types.Difficulty,
		seats: { [Types.ClassId]: string? },
		seed: number,
		config: any
	) -> Types.MatchState,
}

local StateFactory = {}

local CLASS_ORDER: { Types.ClassId } = { "Working", "Middle", "Capitalist", "State" }

function StateFactory.create(
	difficulty: Types.Difficulty,
	seats: { [Types.ClassId]: string? },
	seed: number,
	config: any
): Types.MatchState
	local ruleSet = RuleSet.new(difficulty, config)
	local rng = Rng.new(seed)

	-- Initialize class states from config
	local classes: { [Types.ClassId]: Types.ClassState } = {}
	for _, classId in ipairs(CLASS_ORDER) do
		local classConfig = config.Classes[classId]
		local startResources = classConfig.startResources or {}

		classes[classId] = {
			id = classId,
			resources = {
				Money = startResources.Money or 0,
				Influence = startResources.Influence or 0,
				Food = startResources.Food or 0,
				Goods = startResources.Goods or 0,
				Health = startResources.Health or 0,
				Education = startResources.Education or 0,
			},
			lines = {},
			stability = classConfig.startStability or 50,
			victoryPoints = 0,
			influence = startResources.Influence or 0,
			reputation = {
				Working = 0,
				Middle = 0,
				Capitalist = 0,
				State = 0,
			},
			alliances = {
				Working = false,
				Middle = false,
				Capitalist = false,
				State = false,
			},
			promises = {},
			activeStrikes = {},
		}
	end

	-- Initialize policy state
	local policyState: Types.PolicyState = { tracks = {} }
	for trackId, trackConfig in pairs(config.Policies.tracks or {}) do
		policyState.tracks[trackId] = {
			level = trackConfig.defaultLevel or 0,
			maxLevel = trackConfig.maxLevel or 5,
		}
	end

	return {
		difficulty = difficulty,
		round = 1,
		phase = "ActionWindow",
		classes = classes,
		policyState = policyState,
		eventLog = {},
		rngSeed = seed,
	}
end

return StateFactory
