--!strict
-- Canonical resource metadata (GAME_DESIGN 4, D-008). The id union and its
-- frozen mirror are Types' job; this table carries per-resource data only:
-- display name and, for the four stock resources, the lowercase stock key the
-- ClassState stock is stored under. Prices live in Config/Market. Pure data.
local Types = require(script.Parent.Parent.Game.Types)

type ResourceId = Types.ResourceId
type StockId = Types.StockId

export type ResourceInfo = {
	name: string,
	stockKey: StockId?, -- lowercase stock key; nil for Money/Influence
}

export type ResourcesConfig = {
	[ResourceId]: ResourceInfo,
}

return table.freeze({
	Money = { name = "Money", stockKey = nil } :: ResourceInfo,
	Influence = { name = "Influence", stockKey = nil } :: ResourceInfo,
	Food = { name = "Food", stockKey = "food" } :: ResourceInfo,
	Goods = { name = "Goods", stockKey = "goods" } :: ResourceInfo,
	Health = { name = "Health", stockKey = "health" } :: ResourceInfo,
	Education = { name = "Education", stockKey = "education" } :: ResourceInfo,
} :: ResourcesConfig)
