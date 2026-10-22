--!strict
-- Visibility numbers (GAME_DESIGN 13): the cutoffs the `partial` info mode
-- shows in place of exact values. Money uses the design's own tiers
-- (Low < 15, Mid 15..39, High >= 40); stocks are single-digit counts, so
-- reusing the Money cutoffs would report every stock as Low — they get their
-- own cutoffs (D-071). Pure data.

export type TierCutoffs = {
	lowBelow: number, -- a value below this is Low
	highAtLeast: number, -- a value at or above this is High; the gap is Mid
}

export type VisibilityConfig = {
	moneyTiers: TierCutoffs,
	stockTiers: TierCutoffs,
}

return table.freeze({
	moneyTiers = { lowBelow = 15, highAtLeast = 40 },
	stockTiers = { lowBelow = 2, highAtLeast = 4 },
} :: VisibilityConfig)
