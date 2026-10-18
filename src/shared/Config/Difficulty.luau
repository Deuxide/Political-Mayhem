--!strict
-- Difficulty mode configurations.

export type DifficultyConfig = {
	roundTimeSeconds: number,
	needsMultiplier: number,
	disabledPolicies: { string }?,
	collapseEnabled: boolean,
	eventFrequency: number,
	hintsEnabled: boolean,
	infoMode: "OpenInfo" | "PartialInfo" | "FogInfo",
}

export type Difficulty = {
	Easy: DifficultyConfig,
	Normal: DifficultyConfig,
	Hard: DifficultyConfig,
	Extreme: DifficultyConfig,
}

return {
	Easy = {
		roundTimeSeconds = 120,
		needsMultiplier = 0.5,
		disabledPolicies = { "Wage", "Tax", "PublicServices", "Tariff", "StrikeRights" },
		collapseEnabled = false,
		eventFrequency = 0,
		hintsEnabled = true,
		infoMode = "OpenInfo",
	},
	Normal = {
		roundTimeSeconds = 90,
		needsMultiplier = 1.0,
		disabledPolicies = {},
		collapseEnabled = false,
		eventFrequency = 0.1,
		hintsEnabled = true,
		infoMode = "PartialInfo",
	},
	Hard = {
		roundTimeSeconds = 60,
		needsMultiplier = 1.5,
		disabledPolicies = {},
		collapseEnabled = true,
		eventFrequency = 0.2,
		hintsEnabled = false,
		infoMode = "PartialInfo",
	},
	Extreme = {
		roundTimeSeconds = 45,
		needsMultiplier = 2.0,
		disabledPolicies = {},
		collapseEnabled = true,
		eventFrequency = 0.3,
		hintsEnabled = false,
		infoMode = "FogInfo",
	},
}
