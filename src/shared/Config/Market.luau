--!strict
-- Market configurations: base prices, caps.

export type Market = {
	basePrices: { [string]: number },
	caps: { [string]: number },
}

return {
	basePrices = {
		Money = 1,
		Food = 3,
		Goods = 4,
		Health = 5,
		Education = 6,
	},
	caps = {
		Food = 100,
		Goods = 100,
		Health = 50,
		Education = 50,
	},
}
