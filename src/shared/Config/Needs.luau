--!strict
-- Per-class daily needs as pure rates (GAME_DESIGN 5.3). Working's needs are
-- formulas on the worker count: ceil(workers / 2) Food and ceil(workers / 4)
-- Health. They are encoded here as per-worker rates (0.5 and 0.25) because
-- rounding and the difficulty needsMultiplier composition belong to the
-- Upkeep step, not to this data file. Flat needs are direct amounts. Pure
-- data.
local Types = require(script.Parent.Parent.Game.Types)

type ClassId = Types.ClassId
type StockId = Types.StockId

export type NeedRate = {
	perWorker: number?, -- ceil(workers x rate); absent = 0
	flat: number?, -- constant amount per Day; absent = 0
}

export type NeedsConfig = {
	[ClassId]: {
		[StockId]: NeedRate,
	},
}

return table.freeze({
	Working = {
		food = { perWorker = 0.5 }, -- ceil(workers / 2)
		goods = { flat = 0 },
		health = { perWorker = 0.25 }, -- ceil(workers / 4)
		education = { flat = 0 },
	} :: { [StockId]: NeedRate },

	Middle = {
		food = { flat = 2 },
		goods = { flat = 1 },
		health = { flat = 1 },
		education = { flat = 1 },
	} :: { [StockId]: NeedRate },

	Capitalist = {
		food = { flat = 1 },
		goods = { flat = 2 },
		health = { flat = 1 },
		education = { flat = 0 },
	} :: { [StockId]: NeedRate },

	State = {
		food = { flat = 0 },
		goods = { flat = 0 },
		health = { flat = 0 },
		education = { flat = 0 },
	} :: { [StockId]: NeedRate },
} :: NeedsConfig)
