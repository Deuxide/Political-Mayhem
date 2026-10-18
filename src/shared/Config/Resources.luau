--!strict
-- Resource definitions and metadata.

export type Resources = {
	list: { string },
	icons: { [string]: string },
	marketPrices: { [string]: MarketPrice },
	tiers: { [string]: number },
}

export type MarketPrice = {
	export: number,
	import: number,
}

return {
	list = { "Money", "Influence", "Food", "Goods", "Health", "Education" },
	icons = {
		Money = "rbxassetid://0",
		Influence = "rbxassetid://0",
		Food = "rbxassetid://0",
		Goods = "rbxassetid://0",
		Health = "rbxassetid://0",
		Education = "rbxassetid://0",
	},
	marketPrices = {
		Food = { export = 2, import = 4 },
		Goods = { export = 3, import = 6 },
		Health = { export = 5, import = 10 },
		Education = { export = 4, import = 8 },
	},
	tiers = {
		Money = { Low = 15, Mid = 40, High = math.huge }, -- Low < 15, Mid 15-39, High >= 40
	},
}
