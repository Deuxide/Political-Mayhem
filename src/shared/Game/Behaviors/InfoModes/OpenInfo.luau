--!strict
-- `open` info mode (GAME_DESIGN 13; Easy and Normal): every field about every
-- class is exact — Money, stocks and Influence are the real values. Only the
-- view builder's own copies separate them from the live state.
local InfoMode = require(script.Parent.InfoMode)

local OpenInfo = setmetatable({}, { __index = InfoMode })
OpenInfo.__index = OpenInfo

export type OpenInfo = typeof(setmetatable({} :: {}, OpenInfo))

function OpenInfo.money(_self: OpenInfo, ctx: InfoMode.TargetContext): InfoMode.Tiered
	return InfoMode.fullMoney(ctx)
end

function OpenInfo.stock(
	_self: OpenInfo,
	ctx: InfoMode.TargetContext
): { [InfoMode.StockId]: InfoMode.Tiered }
	return InfoMode.fullStock(ctx)
end

function OpenInfo.influence(_self: OpenInfo, ctx: InfoMode.TargetContext): number?
	return InfoMode.fullInfluence(ctx)
end

return OpenInfo
