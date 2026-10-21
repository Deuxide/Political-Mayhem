--!strict
-- Difficulty matrix (GAME_DESIGN 12). Game logic reads flags and selectors,
-- never difficulty names (M5-T3). scopes of the multipliers and the exact
-- needsMultiplier rounding are decided where they are applied: the
-- startResourceMultiplier at StateFactory (T4) and needsMultiplier at the
-- Upkeep step; Extreme's "round up" note is recorded there when it lands.
-- Pure data.
local Types = require(script.Parent.Parent.Game.Types)

type Difficulty = Types.Difficulty
type PolicyId = Types.PolicyId
type InfoMode = Types.InfoMode

-- Hint depth: the matrix says "yes" (Easy), "yes (light)" (Normal), "no"
-- (Hard/Extreme).
export type HintLevel = "full" | "light" | "none"

export type DifficultyEntry = {
	rounds: number,
	windowSeconds: number,
	revealSeconds: number,
	soloTarget: number,
	policiesEnabled: { PolicyId }, -- subset of Types.POLICY_IDS
	infoMode: InfoMode,
	eventsEnabled: boolean,
	eventsForecast: boolean, -- one-Day forecast (Hard shows it, Extreme not)
	collapseEnabled: boolean,
	hints: HintLevel,
	startResourceMultiplier: number,
	needsMultiplier: number,
	botSuggestions: boolean,
}

export type DifficultyConfig = {
	[Difficulty]: DifficultyEntry,
}

local ALL_POLICY_IDS: { PolicyId } = table.freeze({
	"Wage",
	"TaxWorking",
	"TaxMiddle",
	"TaxCapitalist",
	"PublicServices",
	"Tariff",
	"StrikeRights",
} :: { PolicyId })

return table.freeze({
	Easy = {
		rounds = 8,
		windowSeconds = 90,
		revealSeconds = 12,
		soloTarget = 14,
		policiesEnabled = { "Wage", "TaxCapitalist", "PublicServices" },
		infoMode = "open",
		eventsEnabled = false,
		eventsForecast = false,
		collapseEnabled = false,
		hints = "full",
		startResourceMultiplier = 1.25,
		needsMultiplier = 0.75,
		botSuggestions = true,
	} :: DifficultyEntry,

	Normal = {
		rounds = 12,
		windowSeconds = 120,
		revealSeconds = 8,
		soloTarget = 24,
		policiesEnabled = ALL_POLICY_IDS,
		infoMode = "open",
		eventsEnabled = false,
		eventsForecast = false,
		collapseEnabled = false,
		hints = "light",
		startResourceMultiplier = 1,
		needsMultiplier = 1,
		botSuggestions = false,
	} :: DifficultyEntry,

	Hard = {
		rounds = 14,
		windowSeconds = 150,
		revealSeconds = 8,
		soloTarget = 34,
		policiesEnabled = ALL_POLICY_IDS,
		infoMode = "partial",
		eventsEnabled = true,
		eventsForecast = true,
		collapseEnabled = true,
		hints = "none",
		startResourceMultiplier = 1,
		needsMultiplier = 1,
		botSuggestions = false,
	} :: DifficultyEntry,

	Extreme = {
		rounds = 18,
		windowSeconds = 180,
		revealSeconds = 8,
		soloTarget = 48,
		policiesEnabled = ALL_POLICY_IDS,
		infoMode = "fog",
		eventsEnabled = true,
		eventsForecast = false,
		collapseEnabled = true,
		hints = "none",
		startResourceMultiplier = 0.85,
		needsMultiplier = 1.15, -- "(round up)" per 12; decided at the Upkeep step
		botSuggestions = false,
	} :: DifficultyEntry,
} :: DifficultyConfig)
