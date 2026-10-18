--!strict
-- Class configurations: starting values, needs, max lines, victory conditions.

export type Classes = {
	Working: ClassConfig,
	Middle: ClassConfig,
	Capitalist: ClassConfig,
	State: ClassConfig,
}

export type ClassConfig = {
	startResources: { [string]: number },
	startStability: number,
	needs: { [string]: number },
	maxLines: number,
	victoryConditions: { string },
}

return {
	Working = {
		startResources = {
			Money = 10,
			Influence = 3,
			Food = 4,
			Goods = 0,
			Health = 1,
			Education = 0,
		},
		startStability = 60,
		needs = { Food = 0, Goods = 0, Health = 0, Education = 0 }, -- Dynamic per GAME_DESIGN 5.3
		maxLines = 5,
		victoryConditions = { "NeedsMet", "Employment75", "WageMedium", "ProposedBillPassed" },
	},
	Middle = {
		startResources = {
			Money = 25,
			Influence = 2,
			Food = 2,
			Goods = 1,
			Health = 1,
			Education = 1,
		},
		startStability = 60,
		needs = { Food = 2, Goods = 1, Health = 1, Education = 1 },
		maxLines = 5,
		victoryConditions = { "EducationStock2", "MoneyGained5", "Owns5Lines", "NeedsMet" },
	},
	Capitalist = {
		startResources = {
			Money = 50,
			Influence = 1,
			Food = 1,
			Goods = 2,
			Health = 1,
			Education = 3,
		},
		startStability = 60,
		needs = { Food = 1, Goods = 2, Health = 1, Education = 0 },
		maxLines = 5,
		victoryConditions = { "MoneyGained", "TaxCapitalistLow" },
	},
	State = {
		startResources = {
			Money = 30,
			Influence = 2,
			Food = 0,
			Goods = 0,
			Health = 0,
			Education = 0,
		},
		startStability = 60,
		needs = { Food = 0, Goods = 0, Health = 0, Education = 0 },
		maxLines = 5,
		victoryConditions = {
			"MoneyNonNegative",
			"Stability60",
			"Stability80",
			"PublicLinesStaffed75",
		},
	},
}
