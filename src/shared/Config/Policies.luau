--!strict
-- Policy track configurations.

export type PolicyTrack = {
	defaultLevel: number,
	maxLevel: number,
	voteThreshold: number,
	disabledOnDifficulties: { string }?,
	-- Per-track specific config
	wagePerLevel: number?,
	taxRates: { [string]: number }?,
	serviceFunding: number?,
	tariffRate: number?,
	strikeProtection: number?,
}

export type Policies = {
	tracks: { [string]: PolicyTrack },
}

return {
	tracks = {
		Wage = {
			defaultLevel = 1,
			maxLevel = 5,
			voteThreshold = 0.5,
			wagePerLevel = 1,
			disabledOnDifficulties = { "Easy" },
		},
		Tax = {
			defaultLevel = 1,
			maxLevel = 5,
			voteThreshold = 0.5,
			taxRates = { Working = 0.1, Middle = 0.15, Capitalist = 0.2, State = 0 },
			disabledOnDifficulties = { "Easy" },
		},
		PublicServices = {
			defaultLevel = 1,
			maxLevel = 5,
			voteThreshold = 0.5,
			serviceFunding = 10,
			disabledOnDifficulties = { "Easy" },
		},
		Tariff = {
			defaultLevel = 0,
			maxLevel = 3,
			voteThreshold = 0.5,
			tariffRate = 0.1,
			disabledOnDifficulties = { "Easy" },
		},
		StrikeRights = {
			defaultLevel = 1,
			maxLevel = 2,
			voteThreshold = 0.5,
			strikeProtection = 1,
			disabledOnDifficulties = { "Easy" },
		},
	},
}
