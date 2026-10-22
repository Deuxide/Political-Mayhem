--!strict
-- `fog` info mode (GAME_DESIGN 13; Extreme): another class's Money, stocks
-- and Influence are hidden — the fields are absent from the view, not set to
-- a sentinel. VP and lines stay exact, and an allied class's stocks are fully
-- revealed in every mode (8.4): that is the alliance's whole benefit.
local InfoMode = require(script.Parent.InfoMode)

local FogInfo = setmetatable({}, { __index = InfoMode })
FogInfo.__index = FogInfo

export type FogInfo = typeof(setmetatable({} :: {}, FogInfo))

function FogInfo.money(_self: FogInfo, _ctx: InfoMode.TargetContext): InfoMode.Tiered
	return nil
end

function FogInfo.stock(
	_self: FogInfo,
	ctx: InfoMode.TargetContext
): { [InfoMode.StockId]: InfoMode.Tiered }
	if ctx.allied then
		-- the alliance benefit (8.4): full stocks, even in fog
		return InfoMode.fullStock(ctx)
	end
	-- hidden: an empty map, so not even the resource keys are told
	return {}
end

function FogInfo.influence(_self: FogInfo, _ctx: InfoMode.TargetContext): number?
	return nil
end

return FogInfo
