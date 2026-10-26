--!strict
-- Policy tracks (GAME_DESIGN 7.2) and the bill-system numbers (7.3). Numeric
-- effects per level are data (levelValues keyed by the level); tracks without
-- numeric effects (PublicServices, StrikeRights) are mode-only. Which classes
-- may lobby/build/propose lives in Config/Classes and the steps, never here.
-- The player-facing names live here too, so every panel labels a track the
-- same way (M8-T1). Pure data.
local Types = require(script.Parent.Parent.Game.Types)

type PolicyId = Types.PolicyId

export type PolicyTrack = {
	minLevel: number, -- inclusive lower bound (Wage starts at 1)
	maxLevel: number, -- inclusive upper bound
	default: number,
	levelValues: { [number]: number }?, -- effect value per level; nil for modes
	name: string, -- player-facing track name (M8-T1)
	levelLabels: { [number]: string }, -- player-facing label per level (M8-T1)
}

export type BillsConfig = {
	maxLive: number, -- at most 2 live bills at once
	proposeCost: number, -- Influence per proposal (State proposes free)
	cutoffSeconds: number, -- proposals close this long before the Window ends
	quorum: number, -- passing needs yesWeight >= quorum
}

-- The penalty of an outlawed strike (GAME_DESIGN 6.5): the StrikeRights
-- track is a mode, so its effect numbers live here instead of in
-- levelValues.
export type StrikeRightsConfig = {
	workingInfluenceLoss: number, -- Working loses this Influence per strike Day
	stateInfluenceGain: number, -- the State gains this Influence per strike Day
}

export type PoliciesConfig = {
	unpaidWagePenalty: number, -- Stability cost per unpaid slot (6.4)
	bills: BillsConfig,
	strikeRights: StrikeRightsConfig,
	tracks: {
		[PolicyId]: PolicyTrack,
	},
}

return table.freeze({
	unpaidWagePenalty = 1,

	bills = {
		maxLive = 2,
		proposeCost = 1,
		cutoffSeconds = 20,
		quorum = 5,
	} :: BillsConfig,

	-- The outlawed strike's penalty (6.5)
	strikeRights = {
		workingInfluenceLoss = 2,
		stateInfluenceGain = 1,
	} :: StrikeRightsConfig,

	tracks = {
		-- Low/Medium/High wage per staffed slot (6.4)
		Wage = {
			minLevel = 1,
			maxLevel = 3,
			default = 2,
			levelValues = { [1] = 1, [2] = 2, [3] = 3 },
			name = "Wage",
			levelLabels = { [1] = "Low", [2] = "Medium", [3] = "High" },
		} :: PolicyTrack,

		-- 0/10/20/30 percent, stored as fractions (6.7)
		TaxWorking = {
			minLevel = 0,
			maxLevel = 3,
			default = 1,
			levelValues = { [0] = 0, [1] = 0.1, [2] = 0.2, [3] = 0.3 },
			name = "Tax: Working",
			levelLabels = { [0] = "0%", [1] = "10%", [2] = "20%", [3] = "30%" },
		} :: PolicyTrack,

		TaxMiddle = {
			minLevel = 0,
			maxLevel = 3,
			default = 1,
			levelValues = { [0] = 0, [1] = 0.1, [2] = 0.2, [3] = 0.3 },
			name = "Tax: Middle",
			levelLabels = { [0] = "0%", [1] = "10%", [2] = "20%", [3] = "30%" },
		} :: PolicyTrack,

		TaxCapitalist = {
			minLevel = 0,
			maxLevel = 3,
			default = 1,
			levelValues = { [0] = 0, [1] = 0.1, [2] = 0.2, [3] = 0.3 },
			name = "Tax: Capitalist",
			levelLabels = { [0] = "0%", [1] = "10%", [2] = "20%", [3] = "30%" },
		} :: PolicyTrack,

		-- Market / Universal distribution (6.8)
		PublicServices = {
			minLevel = 0,
			maxLevel = 1,
			default = 0,
			levelValues = nil,
			name = "Public services",
			levelLabels = { [0] = "Market", [1] = "Universal" },
		} :: PolicyTrack,

		-- Money added per imported unit equals the level (6.6)
		Tariff = {
			minLevel = 0,
			maxLevel = 2,
			default = 0,
			levelValues = { [0] = 0, [1] = 1, [2] = 2 },
			name = "Tariff",
			levelLabels = { [0] = "0", [1] = "+1", [2] = "+2" },
		} :: PolicyTrack,

		-- Outlawed / Allowed (6.5)
		StrikeRights = {
			minLevel = 0,
			maxLevel = 1,
			default = 1,
			levelValues = nil,
			name = "Strike rights",
			levelLabels = { [0] = "Outlawed", [1] = "Allowed" },
		} :: PolicyTrack,
	} :: {
		[PolicyId]: PolicyTrack,
	},
} :: PoliciesConfig)
