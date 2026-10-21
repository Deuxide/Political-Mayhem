--!strict
-- Trade offers (GAME_DESIGN 8.2): a live offer during the Window. On
-- acceptance the immediate parts (what each side gives) execute atomically,
-- mid-window, if both sides can still afford them — otherwise the trade
-- fails with a reason and nothing moves. Offers expire at the end of the
-- Window, and a class may have at most 5 pending offers.
--
-- The attached promise specs become Promise records on acceptance; that
-- part lives in the Promise module (M4-T2).
local Types = require(script.Parent.Parent.Types)
local Transfers = require(script.Parent.Transfers)

type ClassId = Types.ClassId
type MatchState = Types.MatchState
type PromiseSpec = Types.PromiseSpec
type ResourceBag = Types.ResourceBag
type TradeId = Types.TradeId
type TradeOffer = Types.TradeOffer

-- At most 5 pending offers per class (8.2).
local MAX_PENDING = 5

local Trade = {}

-- The offer with that id, or nil.
function Trade.find(state: MatchState, tradeId: TradeId): TradeOffer?
	for _, offer in state.trades do
		if offer.id == tradeId then
			return offer
		end
	end
	return nil
end

local function remove(state: MatchState, offer: TradeOffer)
	for i = 1, #state.trades do
		if state.trades[i].id == offer.id then
			table.remove(state.trades, i)
			return
		end
	end
end

-- How many offers the class has pending (given or received).
function Trade.pendingCount(state: MatchState, classId: ClassId): number
	local count = 0
	for _, offer in state.trades do
		if offer.from == classId or offer.to == classId then
			count += 1
		end
	end
	return count
end

-- Proposes a trade. `windowEndsAt` is when the current Window ends — the
-- offer expires then (8.2); the module never reads a clock.
--
-- The offer is a promise, not a transfer: the bags are only checked for
-- shape here. Whether the sides can still afford them is decided when the
-- offer is accepted (8.2), so a class may offer resources it does not have
-- yet — and a trade whose resources changed in the meantime fails there.
function Trade.propose(
	state: MatchState,
	from: ClassId,
	to: ClassId,
	give: ResourceBag,
	want: ResourceBag,
	promises: { PromiseSpec },
	windowEndsAt: number
): (TradeOffer?, string)
	if from == to then
		return nil, "a class cannot trade with itself"
	end
	if Trade.pendingCount(state, from) >= MAX_PENDING then
		return nil, `a class may have at most {MAX_PENDING} pending offers`
	end

	-- The amounts must be whole numbers, whatever the offer is worth.
	local wellFormed, reason = Transfers.isWellFormed(give)
	if not wellFormed then
		return nil, reason
	end
	local wellFormedWant, reasonWant = Transfers.isWellFormed(want)
	if not wellFormedWant then
		return nil, reasonWant
	end

	local offer: TradeOffer = {
		id = `Trade-{#state.trades + 1}`,
		from = from,
		to = to,
		give = give,
		want = want,
		promises = promises,
		expiresAt = windowEndsAt,
	}
	table.insert(state.trades, offer)
	return offer, ""
end

-- Answers an offer. Accepting moves the immediate parts when both sides can
-- still afford them; declining only drops the offer.
function Trade.respond(
	state: MatchState,
	tradeId: TradeId,
	accept: boolean,
	nowSeconds: number
): (boolean, string)
	local offer = Trade.find(state, tradeId)
	if offer == nil then
		return false, "unknown trade offer"
	end

	if nowSeconds >= offer.expiresAt then
		remove(state, offer)
		return false, "the trade offer has expired"
	end

	if not accept then
		remove(state, offer)
		return true, ""
	end

	-- Both legs are checked before anything moves: the trade is atomic.
	local giveOk, giveReason = Transfers.canAfford(state, offer.from, offer.give)
	if not giveOk then
		remove(state, offer)
		return false, giveReason
	end
	local wantOk, wantReason = Transfers.canAfford(state, offer.to, offer.want)
	if not wantOk then
		remove(state, offer)
		return false, wantReason
	end

	Transfers.execute(state, offer.from, offer.to, offer.give)
	Transfers.execute(state, offer.to, offer.from, offer.want)
	remove(state, offer)
	return true, ""
end

-- Drops the offers whose Window has ended; returns how many were dropped.
function Trade.expireOffers(state: MatchState, nowSeconds: number): number
	local dropped = 0
	for i = #state.trades, 1, -1 do
		if nowSeconds >= state.trades[i].expiresAt then
			table.remove(state.trades, i)
			dropped += 1
		end
	end
	return dropped
end

return Trade
