--!strict
-- Policy tracks (GAME_DESIGN 7.2) and the bill-system numbers (7.3). Numeric
-- effects per level are data (levelValues keyed by the level); tracks without
-- numeric effects (PublicServices, StrikeRights) are mode-only. Which classes
-- may lobby/build/propose lives in Config/Classes and the steps, never here.
-- Pure data.
local Types = require(script.Parent.Parent.Game.Types)

type PolicyId = Types.PolicyId

export type PolicyTrack = {
	minLevel: number, -- inclusive lower bound (Wage starts at 1)
	maxLevel: number, -- inclusive upper bound
	default: number,
	levelValues: { [number]: number }?, -- effect value per level; nil for modes
}

export type BillsConfig = {
	maxLive: number, -- at most 2 live bills at once
	proposeCost: number, -- Influence per proposal (State proposes free)
	cutoffSeconds: number, -- proposals close this long before the Window ends
	quorum: number, -- passing needs yesWeight >= quorum
}

export type PoliciesConfig = {
	unpaidWagePenalty: number, -- Stability cost per unpaid slot (6.4)
	bills: BillsConfig,
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

	tracks = {
		-- Low/Medium/High wage per staffed slot (6.4)
		Wage = {
			minLevel = 1,
			maxLevel = 3,
			default = 2,
			levelValues = { [1] = 1, [2] = 2, [3] = 3 },
		} :: PolicyTrack,

		-- 0/10/20/30 percent, stored as fractions (6.7)
		TaxWorking = {
			minLevel = 0,
			maxLevel = 3,
			default = 1,
			levelValues = { [0] = 0, [1] = 0.1, [2] = 0.2, [3] = 0.3 },
		} :: PolicyTrack,

		TaxMiddle = {
			minLevel = 0,
			maxLevel = 3,
			default = 1,
			levelValues = { [0] = 0, [1] = 0.1, [2] = 0.2, [3] = 0.3 },
		} :: PolicyTrack,

		TaxCapitalist = {
			minLevel = 0,
			maxLevel = 3,
			default = 1,
			levelValues = { [0] = 0, [1] = 0.1, [2] = 0.2, [3] = 0.3 },
		} :: PolicyTrack,

		-- Market / Universal distribution (6.8)
		PublicServices = {
			minLevel = 0,
			maxLevel = 1,
			default = 0,
			levelValues = nil,
		} :: PolicyTrack,

		-- Money added per imported unit equals the level (6.6)
		Tariff = {
			minLevel = 0,
			maxLevel = 2,
			default = 0,
			levelValues = { [0] = 0, [1] = 1, [2] = 2 },
		} :: PolicyTrack,

		-- Outlawed / Allowed (6.5)
		StrikeRights = {
			minLevel = 0,
			maxLevel = 1,
			default = 1,
			levelValues = nil,
		} :: PolicyTrack,
	} :: {
		[PolicyId]: PolicyTrack,
	},
} :: PoliciesConfig)
