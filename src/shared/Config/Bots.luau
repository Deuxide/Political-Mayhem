--!strict
-- Bot tuning (GAME_DESIGN 15). Data only: the per-bot RNG seed stride keeps
-- the four deterministic streams apart while every stream still comes from
-- the match seed. A prime stride avoids accidental overlap between classes.
-- The heuristics themselves live in server/Services/Bots, not here.

return table.freeze({
	rngSeedStride = 104729,
})
