--!strict
-- All game state types live here (ARCHITECTURE 3.1). M0 scope: the four enums
-- only; the full state types arrive with M1-T1 (GAME_DESIGN section 4).

local Types = {}

-- The four social classes (GAME_DESIGN 2). Exactly four per match, always.
export type ClassId = "Working" | "Middle" | "Capitalist" | "State"

-- The six resources (D-008; GAME_DESIGN 4).
export type ResourceId = "Money" | "Influence" | "Food" | "Goods" | "Health" | "Education"

-- Soft phases of a Day (GAME_DESIGN 3.1). "Market Hours" and friends are
-- player-facing names only (D-021); code compares these values.
export type Phase = "Window" | "Resolve" | "Reveal"

-- Difficulty modes. Behavior comes from Config, never from name checks (M5-T3).
export type Difficulty = "Easy" | "Normal" | "Hard" | "Extreme"

-- Runtime mirrors of the unions above, same order, so validation and
-- iteration (from M1 on) have a single source to read. Frozen: enums are
-- constants, not data. Canonical iteration order contracts are M1-T5.
local CLASS_IDS: { ClassId } = { "Working", "Middle", "Capitalist", "State" }
local RESOURCE_IDS: { ResourceId } =
	{ "Money", "Influence", "Food", "Goods", "Health", "Education" }
local PHASES: { Phase } = { "Window", "Resolve", "Reveal" }
local DIFFICULTIES: { Difficulty } = { "Easy", "Normal", "Hard", "Extreme" }

Types.CLASS_IDS = table.freeze(CLASS_IDS)
Types.RESOURCE_IDS = table.freeze(RESOURCE_IDS)
Types.PHASES = table.freeze(PHASES)
Types.DIFFICULTIES = table.freeze(DIFFICULTIES)

return table.freeze(Types)
