--!strict
-- Line-type production data (GAME_DESIGN 6.1). Output is the per-staffed-slot
-- produce; Factory consumes one Education per OPERATING line from the owner's
-- Education stock (missing input halves output — the Production step resolves
-- that, this file stays data). Build permissions per class live in
-- Config/Classes (canBuild). All lines start with openSlots = slotsMax
-- (GAME_DESIGN 5.2): StateFactory applies that; it is not duplicated here.
-- Pure data.
local Types = require(script.Parent.Parent.Game.Types)

type LineType = Types.LineType
type StockId = Types.StockId

export type LineConfig = {
	output: { [StockId]: number }, -- stock produced per staffed slot
	input: { [StockId]: number }?, -- consumed from the owner per operating line
	slotsMax: number, -- openSlots upper bound (0..slotsMax)
	buildCost: number, -- Money
}

export type LinesConfig = {
	[LineType]: LineConfig,
}

return table.freeze({
	Farm = {
		output = { food = 2 },
		slotsMax = 2,
		buildCost = 12,
	} :: LineConfig,

	Factory = {
		output = { goods = 2 },
		input = { education = 1 },
		slotsMax = 2,
		buildCost = 20,
	} :: LineConfig,

	Clinic = {
		output = { health = 1 },
		slotsMax = 2,
		buildCost = 15,
	} :: LineConfig,

	School = {
		output = { education = 1 },
		slotsMax = 2,
		buildCost = 15,
	} :: LineConfig,
} :: LinesConfig)
