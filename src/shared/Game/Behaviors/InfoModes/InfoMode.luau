--!strict
-- Abstract InfoMode strategy (GAME_DESIGN 13; ARCHITECTURE 3.1 "Behavior"):
-- one class per configured mode (`open`, `partial`, `fog`) deciding what ONE
-- viewer sees of ONE other class. Stateless: the PlayerViewBuilder owns the
-- parts of the view that are the same in every mode (own class, VP, lines,
-- policies, Stability, bills, promises, alliances, reputation) and calls
-- these hooks only for the three fields a mode may hide or tier.
--
-- "Hidden" means the field is absent from the built table: Lua has no
-- nil-valued keys, so a view can never leak a secret that a client would see
-- as an explicit null. The class owns no state and no view caching — build a
-- fresh view per request.
--
-- Shared readers (fullMoney/fullStock/fullInfluence/tierOf) live here so the
-- three modes share one definition of "exact" and one definition of a tier.

local Types = require(script.Parent.Parent.Parent.Types)
local ConfigVisibility = require(script.Parent.Parent.Parent.Parent.Config.Visibility)

type ClassId = Types.ClassId
type MatchState = Types.MatchState
type TierCutoffs = ConfigVisibility.TierCutoffs

-- Re-exported for the concrete modes, which then need only this module.
export type Tiered = Types.Tiered
export type PowerTier = Types.PowerTier
export type StockId = Types.StockId

-- One viewer looking at one other class. `allied` is true when the two share
-- an active alliance (8.4), the only case where fog still reveals stocks.
export type TargetContext = {
	state: MatchState,
	viewer: ClassId,
	target: ClassId,
	allied: boolean,
}

local InfoMode = {}
InfoMode.__index = InfoMode

export type InfoMode = typeof(setmetatable({} :: {}, InfoMode))

-- The mode hooks. A concrete mode overrides each one; the abstract form
-- raises, so a missing override fails loudly instead of silently hiding or
-- leaking a field.
function InfoMode.money(_self: InfoMode, _ctx: TargetContext): Tiered
	error("not implemented: InfoMode:money", 0)
end

function InfoMode.stock(_self: InfoMode, _ctx: TargetContext): { [StockId]: Tiered }
	error("not implemented: InfoMode:stock", 0)
end

function InfoMode.influence(_self: InfoMode, _ctx: TargetContext): number?
	error("not implemented: InfoMode:influence", 0)
end

-- The exact readers every mode builds from.
function InfoMode.fullMoney(ctx: TargetContext): number
	return ctx.state.classes[ctx.target].money
end

function InfoMode.fullStock(ctx: TargetContext): { [StockId]: Tiered }
	local stock: { [StockId]: Tiered } = {}
	local entry = ctx.state.classes[ctx.target]
	for si = 1, #Types.STOCK_IDS do
		local stockId: StockId = Types.STOCK_IDS[si] :: any
		stock[stockId] = entry.stock[stockId] or 0
	end
	return stock
end

function InfoMode.fullInfluence(ctx: TargetContext): number
	return ctx.state.classes[ctx.target].influence
end

-- Low below `lowBelow`, High at or above `highAtLeast`, Mid in between.
function InfoMode.tierOf(value: number, cutoffs: TierCutoffs): PowerTier
	if value < cutoffs.lowBelow then
		return "Low"
	end
	if value >= cutoffs.highAtLeast then
		return "High"
	end
	return "Mid"
end

return InfoMode
