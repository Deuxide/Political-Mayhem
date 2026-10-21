--!strict
-- The reverse of Config/Resources' stockKey mapping (D-008 keeps the forward
-- map there): one derived, frozen table so Production (R5) and Market (R6)
-- turn stock keys into resource ids without duplicating the derivation.
-- Built once at load over the frozen mirrors, so it is deterministic.
local Types = require(script.Parent.Types)
local ConfigResources = require(script.Parent.Parent.Config.Resources)

type ResourceId = Types.ResourceId
type StockId = Types.StockId

local stockToResource: { [StockId]: ResourceId } = {}
for i = 1, #Types.RESOURCE_IDS do
	-- luau-lsp 1.70.1: cross-module mirror reads degrade to `string`;
	-- the annotation + `any` idiom re-narrows them (see luau-conventions)
	local resourceId: ResourceId = Types.RESOURCE_IDS[i] :: any
	local stockKey = (ConfigResources :: any)[resourceId].stockKey
	if stockKey ~= nil then
		stockToResource[stockKey] = resourceId
	end
end

return table.freeze(stockToResource)
