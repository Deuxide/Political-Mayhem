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
			Influence = 5,
			Food = 5,
			Goods = 0,
			Health = 5,
			Education = 0,
		},
		startStability = 50,
		needs = { Food = 2, Goods = 1, Health = 1, Education = 1 },
		maxLines = 5,
		victoryConditions = { "HighStability", "HighVP" },
	},
	Middle = {
		startResources = {
			Money = 15,
			Influence = 5,
			Food = 3,
			Goods = 3,
			Health = 3,
			Education = 3,
		},
		startStability = 50,
		needs = { Food = 1, Goods = 2, Health = 1, Education = 2 },
		maxLines = 5,
		victoryConditions = { "HighStability", "HighVP" },
	},
	Capitalist = {
		startResources = {
			Money = 20,
			Influence = 5,
			Food = 0,
			Goods = 5,
			Health = 0,
			Education = 5,
		},
		startStability = 50,
		needs = { Food = 1, Goods = 1, Health = 1, Education = 1 },
		maxLines = 5,
		victoryConditions = { "HighStability", "HighVP" },
	},
	State = {
		startResources = {
			Money = 30,
			Influence = 10,
			Food = 0,
			Goods = 0,
			Health = 0,
			Education = 0,
		},
		startStability = 50,
		needs = { Food = 3, Goods = 2, Health = 3, Education = 2 },
		maxLines = 5,
		victoryConditions = { "HighStability", "HighVP" },
	},
}
