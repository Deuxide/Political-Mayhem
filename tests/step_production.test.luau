--!nocheck
-- ProductionStep tests (M2-T2; GAME_DESIGN 6.1 to 6.5, R5): assignment rules
-- (openSlots clamp, total worker cap, not-yet-active lines), wage payment
-- (affordable slots in ascending line-id order, unpaid slots produce nothing
-- and are counted for R9), strike target idling lines without 6.4-unpaid
-- counting, Factory Education input halving (floored), and the scratch
-- channel for Taxes/Upkeep/Scoring. Runs the real step on real factory
-- states via tests/loader.luau.

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
	print("production step")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local assertSerializable = Loader.require(shared.Game.State.assertSerializable)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local BuildStep = Loader.require(shared.Game.Steps.BuildStep)
	local ProductionStep = Loader.require(shared.Game.Steps.ProductionStep)

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
				startMoney = {},
				unmetByClass = {},
				passedBills = {},
			},
		}
	end

	local function produce(state: any, ctx: any): any
		ProductionStep.new():run(state, ctx or makeCtx())
		return state
	end

	local function setAssign(state: any, lineId: string, count: number)
		state.drafts.Working.assign[lineId] = count
	end

	local function strike(state: any, target: string)
		state.drafts.Working.strike = { target = target }
	end

	local function hasLog(state: any, needle: string): boolean
		for _, entry in state.eventLog do
			if string.find(entry.text, needle, 1, true) ~= nil then
				return true
			end
		end
		return false
	end

	Lib.test("staffing, wages, output, and Factory input follow 6.1-6.4", function()
		local state = fresh()
		setAssign(state, "Farm-1", 2) -- Middle
		setAssign(state, "Farm-2", 1) -- Middle
		setAssign(state, "Factory-1", 2) -- Capitalist
		produce(state)

		local middle = state.classes.Middle
		local capitalist = state.classes.Capitalist
		-- Wage level 2 (default): Middle paid 2 slots x2 + 1 slot x2 = 6
		Lib.eq(middle.money, 19, "Middle money after wages")
		-- Capitalist paid 2 slots x2 = 4 and consumed 1 Education
		Lib.eq(capitalist.money, 46, "Capitalist money after wages")
		Lib.eq(capitalist.stock.education, 2, "Factory input consumed")
		-- Working received 6 + 4 = 10
		Lib.eq(state.classes.Working.money, 20, "Working wages received")
		-- Farm-1 4 Food, Farm-2 2 Food, Factory-1 4 Goods
		Lib.eq(middle.stock.food, 8, "Middle food produced")
		Lib.eq(capitalist.stock.goods, 6, "Capitalist goods produced")
		Lib.eq(state.lines["Farm-1"].assigned, 2, "Farm-1 assigned")
		Lib.eq(state.lines["Farm-2"].assigned, 1, "Farm-2 assigned")
		Lib.eq(state.lines["Factory-1"].assigned, 2, "Factory-1 assigned")
		Lib.truthy(hasLog(state, "Capitalist Factory-1 produced 4 Goods"), "factory output log")
		Lib.truthy(hasLog(state, "Middle Farm-1 produced 4 Food"), "farm output log")
		Lib.truthy(hasLog(state, "Middle paid 6 Money in wages for 3 slot(s)"), "middle wage log")
		Lib.truthy(hasLog(state, "Capitalist paid 4 Money in wages for 2 slot(s)"), "cap wage log")
		Lib.truthy(hasLog(state, "Working received 10 Money in wages"), "working wage log")
	end)

	Lib.test("assignments beyond a line's openSlots are ignored (6.3)", function()
		local state = fresh()
		setAssign(state, "Farm-1", 5)
		produce(state)
		Lib.eq(state.lines["Farm-1"].assigned, 2, "clamped to openSlots")
		Lib.eq(state.classes.Middle.money, 21, "wages only for 2 slots")
		Lib.eq(state.classes.Middle.stock.food, 6, "2 slots produced 4 Food")
		Lib.eq(state.classes.Working.money, 14, "10 + 4 wages")
	end)

	Lib.test("total assignment caps at the worker pool; excess stay unemployed", function()
		local state = fresh()
		state.classes.Working.workers = 2 -- fixture: only 2 workers exist
		setAssign(state, "Farm-1", 2)
		setAssign(state, "Farm-2", 2)
		setAssign(state, "Factory-1", 2)
		produce(state)
		-- natural order (D-047: type alphabetically, "Factory" < "Farm")
		-- grants Factory-1 the pool first
		Lib.eq(state.lines["Factory-1"].assigned, 2, "Factory-1 fully staffed")
		Lib.eq(state.lines["Farm-1"].assigned, 0, "Farm-1 unemployed")
		Lib.eq(state.lines["Farm-2"].assigned, 0, "Farm-2 unemployed")
		Lib.eq(state.classes.Capitalist.money, 46, "Factory paid")
		Lib.eq(state.classes.Middle.money, 25, "farms unpaid")
		Lib.eq(state.classes.Working.money, 14, "only Factory wages")
	end)

	Lib.test("insufficient owner funds pay what is affordable, ascending ids (6.4)", function()
		local state = fresh()
		state.classes.Middle.money = 3 -- fixture: nearly broke owner
		setAssign(state, "Farm-1", 2) -- needs 4
		setAssign(state, "Farm-2", 2) -- needs 4
		produce(state)
		-- floor(3/2) = 1 slot affordable on Farm-1; Farm-2 gets nothing
		Lib.eq(state.classes.Middle.money, 1, "owner money")
		Lib.eq(state.classes.Middle.stock.food, 4, "only Farm-1's paid slot produced")
		Lib.eq(state.classes.Working.money, 12, "one slot's wage")
		Lib.truthy(
			hasLog(state, "Middle paid 2 Money in wages for 1 slot(s); 3 wage slot(s) left unpaid"),
			"unpaid log"
		)
		Lib.truthy(not hasLog(state, "Farm-2 produced"), "unpaid slots produce nothing")
	end)

	Lib.test("a line with no open slots idles silently (no wage, no log)", function()
		local state = fresh()
		state.lines["Farm-1"].openSlots = 0 -- owner closed the line (6.2)
		setAssign(state, "Farm-1", 2)
		produce(state)
		Lib.eq(state.lines["Farm-1"].assigned, 0, "no slots -> no staffing")
		Lib.eq(state.classes.Middle.money, 25, "no wages due")
		Lib.eq(state.classes.Middle.stock.food, 2, "no output")
	end)

	Lib.test("strike target's lines idle, no wage, not counted as unpaid (6.5)", function()
		local state = fresh()
		setAssign(state, "Farm-1", 2) -- Middle: unaffected
		setAssign(state, "Factory-1", 2) -- Capitalist: struck
		setAssign(state, "Factory-2", 2) -- Capitalist: struck
		strike(state, "Capitalist")
		produce(state)
		Lib.eq(state.classes.Capitalist.stock.goods, 2, "struck factories produce nothing")
		Lib.eq(state.classes.Capitalist.money, 50, "struck owner pays nothing")
		Lib.eq(state.classes.Working.money, 14, "only the unaffected Farm's wages")
		Lib.eq(state.classes.Middle.money, 21, "Middle paid its farm")
		Lib.truthy(hasLog(state, "Working's strike idles Capitalist: 2"), "strike log")
		Lib.truthy(hasLog(state, "Middle Farm-1 produced 4 Food"), "unstruck line still produces")
		Lib.truthy(not hasLog(state, "Factory-1 produced"), "struck line has no output log")
	end)

	Lib.test("missing Factory Education halves output (floored) (6.1)", function()
		local state = fresh()
		state.classes.Capitalist.stock.education = 0
		setAssign(state, "Factory-1", 2)
		produce(state)
		-- 2 slots x 2 goods = 4; halved = 2
		Lib.eq(state.classes.Capitalist.stock.goods, 4, "halved output")
		Lib.eq(state.classes.Capitalist.money, 46, "wages still paid (operating)")
		Lib.eq(state.classes.Capitalist.stock.education, 0, "no input consumed")
		Lib.truthy(hasLog(state, "produced 2 Goods (no input: output halved)"), "halved note")
	end)

	Lib.test("halving floors odd outputs as well (6.1)", function()
		local state = fresh()
		state.classes.Capitalist.stock.education = 0
		setAssign(state, "Factory-1", 1) -- 1 x 2 = 2 -> floor 1
		produce(state)
		Lib.eq(state.classes.Capitalist.stock.goods, 3, "2 + floor(2/2) = 3")
	end)

	Lib.test("a line built today stays inactive; it operates next Day (R4->R5)", function()
		local state = fresh()
		state.drafts.Capitalist.build = { lineType = "Factory" } -- cost 20
		BuildStep.new():run(state, makeCtx())
		local built = state.lines["Factory-4"]
		Lib.truthy(built ~= nil, "Factory-4 queued today")
		setAssign(state, "Factory-4", 2)
		produce(state)
		Lib.eq(state.lines["Factory-4"].assigned, 0, "today's Production ignores it")
		Lib.eq(state.classes.Capitalist.stock.goods, 2, "no output today")
		Lib.eq(state.classes.Capitalist.money, 30, "no wage paid today (50 - 20 build)")
		state.day += 1
		produce(state)
		Lib.eq(state.lines["Factory-4"].assigned, 2, "active next Day")
		Lib.eq(state.classes.Capitalist.stock.goods, 6, "output next Day")
	end)

	Lib.test("the scratch channel records wages, unpaid slots, employment", function()
		local ctx = makeCtx()
		local state = fresh()
		setAssign(state, "Farm-1", 2)
		setAssign(state, "Factory-1", 2)
		state.classes.Capitalist.money = 3 -- covers only 1 of 2 slots
		produce(state, ctx)
		Lib.eq(ctx.scratch.wagesReceived.Working, 6, "Working income (taxes)")
		Lib.eq(ctx.scratch.unpaidSlots, 1, "unpaid slot count (stability)")
		Lib.eq(ctx.scratch.employedWorkers, 3, "employed workers (scoring)")
	end)
end

return M
