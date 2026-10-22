--!strict
-- Scoring and victory numbers (GAME_DESIGN 11). Pure data; the rules that
-- read them are Steps/Scoring (R12) and Steps/VictoryCheck (R13).
return table.freeze({
	-- 11.1: a class never scores more than this in one Day. The per-class
	-- criteria add up to exactly 4, so this is a safety net, not a normal cap.
	maxVpPerDay = 4,

	-- 11.2 shared victory: an alliance that has held for at least this many
	-- Days, whose combined VP reaches soloTarget x 1.5, with each member at
	-- soloTarget x 0.4 (rounded up).
	sharedAllianceAgeDays = 3,
	sharedCombinedFactor = 1.5,
	sharedEachFactor = 0.4,

	-- 11.2 final Day: an alliance compares at combinedVP x 0.7.
	finalAllianceFactor = 0.7,

	-- 11.2 collapse: this many consecutive Days at Stability 0 end the match
	-- (only when the difficulty enables collapse).
	collapseCounterLimit = 2,
})
