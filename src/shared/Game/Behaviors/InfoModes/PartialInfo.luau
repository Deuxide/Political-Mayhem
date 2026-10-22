--!strict
-- `partial` info mode (GAME_DESIGN 13; Hard): another class's Money and
-- stocks are shown as a Low/Mid/High tier, and its Influence is hidden. VP and
-- lines stay exact. The tier cutoffs are the visibility config, not numbers
-- in this file (D-071).
local InfoMode = require(script.Parent.InfoMode)
local Types = require(script.Parent.Parent.Parent.Types)
local ConfigVisibility = require(script.Parent.Parent.Parent.Parent.Config.Visibility)

local PartialInfo = setmetatable({}, { __index = InfoMode })
PartialInfo.__index = PartialInfo

export type PartialInfo = typeof(setmetatable({} :: {}, PartialInfo))

function PartialInfo.money(_self: PartialInfo, ctx: InfoMode.TargetContext): InfoMode.Tiered
	return InfoMode.tierOf(InfoMode.fullMoney(ctx), ConfigVisibility.moneyTiers)
end

function PartialInfo.stock(
	_self: PartialInfo,
	ctx: InfoMode.TargetContext
): { [InfoMode.StockId]: InfoMode.Tiered }
	local exact = InfoMode.fullStock(ctx)
	local tiered: { [InfoMode.StockId]: InfoMode.Tiered } = {}
	for si = 1, #Types.STOCK_IDS do
		local stockId: InfoMode.StockId = Types.STOCK_IDS[si] :: any
		tiered[stockId] = InfoMode.tierOf(exact[stockId] :: number, ConfigVisibility.stockTiers)
	end
	return tiered
end

function PartialInfo.influence(_self: PartialInfo, _ctx: InfoMode.TargetContext): number?
	return nil
end

return PartialInfo
