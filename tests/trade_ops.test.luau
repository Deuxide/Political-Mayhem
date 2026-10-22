--!nocheck
-- Trade tests (M4-T1; GAME_DESIGN 8.2): the offer lifecycle — proposing,
-- accepting, declining, expiring — the caps, and the rule that a trade
-- whose resources changed after the proposal fails atomically at the
-- acceptance. Runs the real module on real factory states via
-- tests/loader.luau.

local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

local SEATS: { [string]: { string } } = {
	Working = { "Seat-Working" },
	Middle = { "Seat-Middle" },
	Capitalist = { "Seat-Capitalist" },
	State = { "Seat-State" },
}

function M.run()
	print("trade ops")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local assertSerializable = Loader.require(shared.Game.State.assertSerializable)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local Trade = Loader.require(shared.Game.Ops.Trade)
	local MarketStep = Loader.require(shared.Game.Steps.MarketStep)

	local function fresh(): any
		return StateFactory.create("Normal", SEATS, 41)
	end

	local function makeCtx(): any
		return {
			rng = Rng.new(41),
			ruleSet = RuleSet.new("Normal"),
			scratch = {
				wagesReceived = {},
				salesRevenue = {},
				unpaidSlots = 0,
				employedWorkers = 0,
				startMoney = {},
				unmetByClass = {},
				passedBills = {},
			},
		}
	end

	Lib.test("a proposal creates a live offer (8.2)", function()
		local state = fresh()
		local offer, reason = Trade.propose(
			state,
			"Middle",
			"Capitalist",
			{ Money = 5 },
			{ Goods = 2 },
			{},
			120
		)
		Lib.truthy(offer ~= nil, "accepted: " .. tostring(reason))
		Lib.eq(offer.id, "Trade-1", "offer id")
		Lib.eq(offer.from, "Middle", "from")
		Lib.eq(offer.to, "Capitalist", "to")
		Lib.eq(offer.give.Money, 5, "give")
		Lib.eq(offer.want.Goods, 2, "want")
		Lib.eq(offer.expiresAt, 120, "expires at the end of the Window")
		Lib.eq(#state.trades, 1, "one live offer")
	end)

	Lib.test("a class cannot trade with itself (8.2)", function()
		local state = fresh()
		local offer, reason = Trade.propose(state, "Middle", "Middle", { Money = 5 }, {}, {}, 120)
		Lib.eq(offer, nil, "refused")
		Lib.eq(reason, "a class cannot trade with itself", "reason")
		Lib.eq(#state.trades, 0, "no offer created")
	end)

	Lib.test("a class may have at most 5 pending offers (8.2)", function()
		local state = fresh()
		for i = 1, 5 do
			local offer = Trade.propose(state, "Middle", "Capitalist", { Money = i }, {}, {}, 120)
			Lib.truthy(offer ~= nil, `offer {i} accepted`)
		end
		Lib.eq(Trade.pendingCount(state, "Middle"), 5, "five pending")
		local sixth, reason = Trade.propose(state, "Middle", "Working", { Money = 1 }, {}, {}, 120)
		Lib.eq(sixth, nil, "the sixth is refused")
		Lib.eq(reason, "a class may have at most 5 pending offers", "reason")
		Lib.eq(#state.trades, 5, "still five offers")
	end)

	Lib.test("accepting moves both parts (8.2)", function()
		local state = fresh()
		local offer = Trade.propose(
			state,
			"Middle",
			"Capitalist",
			{ Money = 5 },
			{ Goods = 2 },
			{},
			120
		)
		local ok, reason = Trade.respond(state, offer.id, true, 10)
		Lib.eq(ok, true, "accepted: " .. tostring(reason))
		Lib.eq(state.classes.Middle.money, 20, "25 - 5")
		Lib.eq(state.classes.Capitalist.money, 55, "50 + 5")
		Lib.eq(state.classes.Middle.stock.goods, 3, "1 + 2 goods")
		Lib.eq(state.classes.Capitalist.stock.goods, 0, "2 - 2 goods")
		Lib.eq(#state.trades, 0, "the offer is gone")
	end)

	Lib.test("declining moves nothing and drops the offer (8.2)", function()
		local state = fresh()
		local offer = Trade.propose(state, "Middle", "Capitalist", { Money = 5 }, {}, {}, 120)
		local ok = Trade.respond(state, offer.id, false, 10)
		Lib.eq(ok, true, "declined")
		Lib.eq(state.classes.Middle.money, 25, "money untouched")
		Lib.eq(#state.trades, 0, "the offer is gone")
	end)

	Lib.test("a trade whose resources changed after the proposal fails (8.2)", function()
		local state = fresh()
		local offer = Trade.propose(
			state,
			"Capitalist",
			"Middle",
			{ Money = 20 },
			{ Food = 2 },
			{},
			120
		)
		-- the Capitalist spends the money it offered before the Middle answers
		state.drafts.Capitalist.market.buy["goods"] = 6 -- 6 x 6 = 36 Money
		MarketStep.new():run(state, makeCtx())
		Lib.eq(state.classes.Capitalist.money, 14, "the money is gone")

		local ok, reason = Trade.respond(state, offer.id, true, 10)
		Lib.eq(ok, false, "the trade fails")
		Lib.eq(reason, "Capitalist does not have 20 Money", "reason")
		Lib.eq(state.classes.Middle.money, 25, "nothing moved")
		Lib.eq(state.classes.Middle.stock.food, 2, "nothing moved")
		Lib.eq(#state.trades, 0, "the offer is gone")
	end)

	Lib.test("a trade that cannot pay both parts moves nothing (8.2)", function()
		local state = fresh()
		local offer = Trade.propose(
			state,
			"Middle",
			"Working",
			{ Money = 5 },
			{ Food = 9 }, -- the Working has 4 Food
			{},
			120
		)
		local ok, reason = Trade.respond(state, offer.id, true, 10)
		Lib.eq(ok, false, "the trade fails")
		Lib.eq(reason, "Working does not have 9 Food", "reason")
		Lib.eq(state.classes.Middle.money, 25, "the first part did not move")
		Lib.eq(state.classes.Working.money, 10, "nothing moved")
		Lib.eq(state.classes.Middle.stock.food, 2, "nothing moved")
	end)

	Lib.test("an expired offer cannot be accepted (8.2)", function()
		local state = fresh()
		local offer = Trade.propose(state, "Middle", "Capitalist", { Money = 5 }, {}, {}, 120)
		local ok, reason = Trade.respond(state, offer.id, true, 120)
		Lib.eq(ok, false, "refused")
		Lib.eq(reason, "the trade offer has expired", "reason")
		Lib.eq(state.classes.Middle.money, 25, "nothing moved")
		Lib.eq(#state.trades, 0, "the offer is gone")
	end)

	Lib.test("expired offers are dropped when the Window ends (8.2)", function()
		local state = fresh()
		Trade.propose(state, "Middle", "Capitalist", { Money = 5 }, {}, {}, 120)
		Trade.propose(state, "Working", "Capitalist", { Money = 1 }, {}, {}, 300)
		Lib.eq(#state.trades, 2, "two live offers")
		Lib.eq(Trade.expireOffers(state, 200), 1, "one dropped")
		Lib.eq(#state.trades, 1, "one offer left")
		Lib.eq(state.trades[1].from, "Working", "the later offer is the one left")
	end)

	Lib.test("traded states stay serializable and deterministic (no RNG used)", function()
		local function runOnce(): any
			local state = fresh()
			local offer = Trade.propose(
				state,
				"Middle",
				"Capitalist",
				{ Money = 5 },
				{ Goods = 2 },
				{},
				120
			)
			Trade.respond(state, offer.id, true, 10)
			return state
		end
		local a = runOnce()
		local b = runOnce()
		Lib.eq(#assertSerializable.validate(a), 0, "state serializable")
		Lib.eq(StateHash.compute(a), StateHash.compute(b), "same input -> same result")
		Lib.eq(a.classes.Middle.money, 20, "same money")
	end)
end

return M
