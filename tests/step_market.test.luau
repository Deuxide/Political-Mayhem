--!nocheck
-- MarketStep tests (M2-T3; GAME_DESIGN 6.6, R6): sell before buy, volume caps
-- (per side, shared across entries, dropped units noted), tariff pricing
-- (buyer pays + level per unit, State collects the tariff), insufficient
-- Money skipping a buy while later entries still run, unstocked sells
-- skipping, and sales revenue tracked as income (scratch). Runs the real
-- step on real factory states via tests/loader.luau.

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
	print("market step")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local assertSerializable = Loader.require(shared.Game.State.assertSerializable)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local MarketStep = Loader.require(shared.Game.Steps.MarketStep)

	local function fresh(): any
		return StateFactory.create("Normal", SEATS, 41)
	end

	local function makeCtx(): any
		return {
			rng = Rng.new(41),
			ruleSet = RuleSet.new("Normal"),
			-- what the M2-T7 pipeline will create fresh each resolution
			scratch = {
				wagesReceived = {},
				salesRevenue = {},
				unpaidSlots = 0,
				employedWorkers = 0,
			},
		}
	end

	local function trade(state: any, classId: string, sell: any?, buy: any?): any
		state.drafts[classId].market = { sell = sell or {}, buy = buy or {} }
		return state
	end

	local function run(state: any, ctx: any): any
		MarketStep.new():run(state, ctx or makeCtx())
		return state
	end

	local function hasLog(state: any, needle: string): boolean
		for _, entry in state.eventLog do
			if string.find(entry.text, needle, 1, true) ~= nil then
				return true
			end
		end
		return false
	end

	Lib.test("sells execute before buys and pay the fixed prices (6.6)", function()
		local ctx = makeCtx()
		local state = fresh()
		trade(state, "Middle", { food = 2 }, { goods = 2 })
		run(state, ctx)
		-- Middle starts with 25 Money, 2 Food, 1 Goods
		Lib.eq(state.classes.Middle.money, 17, "25 + 4 (sell) - 12 (buy)")
		Lib.eq(state.classes.Middle.stock.food, 0, "food sold")
		Lib.eq(state.classes.Middle.stock.goods, 3, "goods bought")
		Lib.eq(state.classes.State.money, 30, "no tariff at level 0")
		Lib.truthy(hasLog(state, "Middle sold 2 Food for 4 Money"), "sell log")
		Lib.truthy(hasLog(state, "Middle bought 2 Goods for 12 Money"), "buy log")
		-- the sell log comes before the buy log
		Lib.eq(state.eventLog[1].text, "Middle sold 2 Food for 4 Money", "sell logged first")
	end)

	Lib.test("the sell volume cap truncates and notes the dropped units (6.6)", function()
		local ctx = makeCtx()
		local state = fresh()
		state.classes.Capitalist.stock.goods = 9 -- fixture: more than the cap
		trade(state, "Capitalist", { goods = 10 }, {})
		run(state, ctx)
		Lib.eq(state.classes.Capitalist.stock.goods, 3, "only 6 sold")
		Lib.eq(state.classes.Capitalist.money, 68, "50 + 6 x 3")
		Lib.truthy(
			hasLog(state, "Capitalist sell volume capped: 4 unit(s) dropped (cap 6)"),
			"cap note"
		)
		Lib.eq(ctx.scratch.salesRevenue.Capitalist, 18, "revenue is income")
	end)

	Lib.test("the cap is shared across entries and drops the overflow", function()
		local ctx = makeCtx()
		local state = fresh()
		state.classes.Middle.stock.goods = 8 -- fixture
		state.classes.Middle.stock.health = 2 -- fixture
		trade(state, "Middle", { goods = 8, health = 2 }, {})
		run(state, ctx)
		-- goods take the cap (6 of 8), health gets nothing
		Lib.eq(state.classes.Middle.stock.goods, 2, "6 goods sold")
		Lib.eq(state.classes.Middle.stock.health, 2, "no health sold")
		Lib.eq(state.classes.Middle.money, 43, "25 + 6 x 3")
		Lib.truthy(
			hasLog(state, "Middle sell volume capped: 4 unit(s) dropped (cap 6)"),
			"2 over the goods cap + 2 health units"
		)
		Lib.truthy(not hasLog(state, "sold 2 Health"), "the dropped entry never sold")
	end)

	Lib.test("insufficient Money skips the buy; later entries still run (6.6)", function()
		local ctx = makeCtx()
		local state = fresh()
		-- Working starts with 10 Money, 4 Food, 1 Health
		trade(state, "Working", {}, { food = 3, health = 1 })
		run(state, ctx)
		-- food would cost 12 > 10: skipped whole, and it keeps the cap
		Lib.truthy(
			hasLog(state, "Working buy skipped: cannot afford 3 Food (12 Money)"),
			"skip log"
		)
		Lib.eq(state.classes.Working.stock.food, 4, "no food bought")
		-- health costs exactly 10: bought, money to zero
		Lib.eq(state.classes.Working.money, 0, "money spent to zero")
		Lib.eq(state.classes.Working.stock.health, 2, "health bought")
		Lib.truthy(hasLog(state, "Working bought 1 Health for 10 Money"), "buy log")
	end)

	Lib.test("a sell without the stock skips with a log (6.6)", function()
		local ctx = makeCtx()
		local state = fresh()
		trade(state, "Middle", { food = 5 }, {}) -- Middle has 2 Food
		run(state, ctx)
		Lib.eq(state.classes.Middle.stock.food, 2, "stock untouched")
		Lib.eq(state.classes.Middle.money, 25, "money untouched")
		Lib.truthy(hasLog(state, "Middle sell skipped: not enough Food in stock"), "skip log")
		Lib.eq(ctx.scratch.salesRevenue.Middle or 0, 0, "no revenue, no income")
	end)

	Lib.test("the tariff raises the import price and pays the State (6.6)", function()
		local ctx = makeCtx()
		local state = fresh()
		state.policies.Tariff = 2 -- fixture: 2 Money per imported unit
		trade(state, "Capitalist", {}, { goods = 2 })
		run(state, ctx)
		-- import price 6 + tariff 2 = 8 per unit
		Lib.eq(state.classes.Capitalist.money, 34, "50 - 16")
		Lib.eq(state.classes.Capitalist.stock.goods, 4, "goods bought")
		Lib.eq(state.classes.State.money, 34, "State collected the tariff")
		Lib.truthy(
			hasLog(state, "Capitalist bought 2 Goods for 16 Money (incl. 4 Money tariff)"),
			"tariff note"
		)
	end)

	Lib.test("a sale funds the same class's buy on the same Day (6.6)", function()
		local ctx = makeCtx()
		local state = fresh()
		trade(state, "Middle", { education = 1 }, { food = 2 })
		run(state, ctx)
		Lib.eq(state.classes.Middle.money, 21, "25 + 4 (sell) - 8 (buy)")
		Lib.eq(state.classes.Middle.stock.education, 0, "education sold")
		Lib.eq(state.classes.Middle.stock.food, 4, "food bought")
		Lib.eq(ctx.scratch.salesRevenue.Middle, 4, "revenue is income")
	end)

	Lib.test("no market draft changes nothing (not even the hash)", function()
		local state = fresh()
		local before = StateHash.compute(state)
		run(state)
		Lib.eq(StateHash.compute(state), before, "state untouched")
		Lib.eq(#state.eventLog, 0, "no log entries")
	end)

	Lib.test("zero-volume entries are silent and use no cap", function()
		local ctx = makeCtx()
		local state = fresh()
		trade(state, "Middle", { food = 0, goods = 1 }, {})
		run(state, ctx)
		Lib.eq(state.classes.Middle.money, 28, "25 + 1 x 3")
		Lib.eq(state.classes.Middle.stock.goods, 0, "goods sold")
		Lib.truthy(not hasLog(state, "Food"), "the empty entry logs nothing")
		Lib.truthy(not hasLog(state, "volume capped"), "no cap note")
	end)

	Lib.test("sell and buy have separate volume caps (6.6)", function()
		local ctx = makeCtx()
		local state = fresh()
		state.classes.Working.stock.food = 6 -- fixture
		trade(state, "Working", { food = 6 }, { food = 2 })
		run(state, ctx)
		Lib.eq(state.classes.Working.money, 14, "10 + 12 (sell) - 8 (buy)")
		Lib.eq(state.classes.Working.stock.food, 2, "6 sold, 2 bought")
		Lib.truthy(not hasLog(state, "volume capped"), "neither side hit the cap")
	end)

	Lib.test("market states stay serializable and deterministic (no RNG used)", function()
		local a = fresh()
		local b = fresh()
		trade(a, "Middle", { food = 2 }, { goods = 2 })
		trade(b, "Middle", { food = 2 }, { goods = 2 })
		run(a)
		run(b)
		Lib.eq(#assertSerializable.validate(a), 0, "state serializable")
		Lib.eq(StateHash.compute(a), StateHash.compute(b), "same input -> same result")
		Lib.eq(a.classes.Middle.money, b.classes.Middle.money, "same money")
	end)
end

return M
