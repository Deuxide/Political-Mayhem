--!strict
-- Resource definitions.

export type Resources = {
	list: { string },
	icons: { [string]: string },
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
}
