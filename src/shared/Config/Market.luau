--!strict
-- Market configurations: prices, caps, tariff handling.

export type Market = {
	exportPrices: { [string]: number },
	importPrices: { [string]: number },
	caps: { sell: number, buy: number },
	revenueCountsAsIncome: boolean,
	directTradesUntaxed: boolean,
}

return {
	exportPrices = {
		Food = 2,
		Goods = 3,
		Health = 5,
		Education = 4,
	},
	importPrices = {
		Food = 4,
		Goods = 6,
		Health = 10,
		Education = 8,
	},
	caps = { sell = 6, buy = 6 }, -- per class per day
	revenueCountsAsIncome = true,
	directTradesUntaxed = true,
}
