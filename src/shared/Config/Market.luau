--!strict
-- Market (export/import) prices and volume cap (GAME_DESIGN 6.6). Tariff
-- mechanics (import price + tariff Level per unit; revenue to the State) are
-- resolution behavior; the tariff-level numbers live in Config/Policies.
-- Sell-execute-before-buy ordering and income attribution are pipeline
-- behavior. Pure data.
local Types = require(script.Parent.Parent.Game.Types)

type StockId = Types.StockId

export type Price = {
	sell: number, -- export price per unit
	buy: number, -- import price per unit (tariff adds on top)
}

export type MarketConfig = {
	prices: {
		[StockId]: Price,
	},
	volumeCap: number, -- executed units per side per class per Day (D-048)
}

return table.freeze({
	prices = {
		food = { sell = 2, buy = 4 } :: Price,
		goods = { sell = 3, buy = 6 } :: Price,
		health = { sell = 5, buy = 10 } :: Price,
		education = { sell = 4, buy = 8 } :: Price,
	} :: {
		[StockId]: Price,
	},
	volumeCap = 6,
} :: MarketConfig)
