--!strict
-- VP criteria per class (GAME_DESIGN 11.1) as pure data. The named predicates
-- are wired later in Game/Steps/Scoring (M2+); here only ids, max awards, and
-- parameters are stored. A criterion without `vp` is worth 1 VP; `vp` caps a
-- scaled award (Capitalist money-gain). Params values may be numbers or
-- strings (a stock key or policy id referenced by name). Pure data.
local Types = require(script.Parent.Parent.Game.Types)

type ClassId = Types.ClassId

export type Objective = {
	id: string, -- predicate name wired in Steps/Scoring
	vp: number?, -- max award; default 1
	params: { [string]: number }?, -- numeric parameters; a resource or policy choice is part of the id (e.g. educationStockAtLeast, taxCapitalistAtMost)
}

export type ObjectivesConfig = {
	[ClassId]: { Objective },
}

return table.freeze({
	Working = {
		{ id = "needsMet" },
		{ id = "employmentAtLeast", params = { fraction = 0.75 } },
		{ id = "wageAtLeast", params = { level = 2 } }, -- Wage >= Medium
		{ id = "ownBillPassed" },
	} :: { Objective },

	Middle = {
		{ id = "educationStockAtLeast", params = { amount = 2 } },
		{ id = "moneyGainAtLeast", params = { amount = 5 } },
		{ id = "ownsLinesAtLeast", params = { count = 5 } },
		{ id = "needsMet" },
	} :: { Objective },

	Capitalist = {
		{ id = "moneyGainScaled", vp = 3, params = { divisor = 8 } }, -- min(3, floor(gain / 8))
		{ id = "taxCapitalistAtMost", params = { level = 1 } },
	} :: { Objective },

	State = {
		{ id = "moneyNotDecreasing" },
		{ id = "stabilityAtLeast", params = { level = 60 } },
		{ id = "stabilityAtLeast", params = { level = 80 } },
		{ id = "publicStaffingAtLeast", params = { fraction = 0.75 } },
	} :: { Objective },
} :: ObjectivesConfig)
