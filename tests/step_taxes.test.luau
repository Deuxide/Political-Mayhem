--!nocheck
-- TaxesStep tests (M2-T4; GAME_DESIGN 6.7, R7): each class's tax level and
-- income source (Working = wages received, Middle/Capitalist = market sales
-- revenue), floor behavior (including the 30% x 10 case that a naive float
-- multiply would under-charge), the State receiving the total, an unpayable
-- tax skipping with a log, a disabled track not taxing at all, and a
-- tax-free class logging nothing. Runs the real step on real factory states
-- via tests/loader.luau.

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
	print("taxes step")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local assertSerializable = Loader.require(shared.Game.State.assertSerializable)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local TaxesStep = Loader.require(shared.Game.Steps.TaxesStep)

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

	local function tax(state: any, ctx: any): any
		TaxesStep.new():run(state, ctx)
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

	Lib.test("each class pays its own level and the State gets the total (6.7)", function()
		local ctx = makeCtx()
		local state = fresh()
		state.policies.TaxWorking = 1 -- 10%
		state.policies.TaxMiddle = 2 -- 20%
		state.policies.TaxCapitalist = 3 -- 30%
		ctx.scratch.wagesReceived.Working = 10
		ctx.scratch.salesRevenue.Middle = 20
		ctx.scratch.salesRevenue.Capitalist = 30
		tax(state, ctx)
		Lib.eq(state.classes.Working.money, 9, "10 - floor(10%)")
		Lib.eq(state.classes.Middle.money, 21, "25 - floor(20%)")
		Lib.eq(state.classes.Capitalist.money, 41, "50 - floor(30%)")
		Lib.eq(state.classes.State.money, 44, "State receives 1 + 4 + 9")
		Lib.truthy(hasLog(state, "Working paid 1 Money tax (10%)"), "working log")
		Lib.truthy(hasLog(state, "Middle paid 4 Money tax (20%)"), "middle log")
		Lib.truthy(hasLog(state, "Capitalist paid 9 Money tax (30%)"), "capitalist log")
	end)

	Lib.test("the tax floors to whole units (6.7)", function()
		local ctx = makeCtx()
		local state = fresh()
		state.policies.TaxCapitalist = 3 -- 30%
		ctx.scratch.salesRevenue.Capitalist = 7
		tax(state, ctx)
		-- floor(0.3 x 7) = floor(2.1) = 2
		Lib.eq(state.classes.Capitalist.money, 48, "50 - 2")
		Lib.eq(state.classes.State.money, 32, "State receives 2")
		Lib.truthy(hasLog(state, "Capitalist paid 2 Money tax (30%)"), "floored log")
	end)

	Lib.test("30% of 10 is 3, not 2 (integer percent, D-050)", function()
		local ctx = makeCtx()
		local state = fresh()
		state.policies.TaxCapitalist = 3 -- 30%
		ctx.scratch.salesRevenue.Capitalist = 10
		tax(state, ctx)
		-- a float multiply (0.3 * 10) lands at 2.9999999999999996 and would
		-- floor to 2; the integer percent keeps it exact
		Lib.eq(state.classes.Capitalist.money, 47, "50 - 3")
		Lib.eq(state.classes.State.money, 33, "State receives 3")
		Lib.truthy(hasLog(state, "Capitalist paid 3 Money tax (30%)"), "exact log")
	end)

	Lib.test("Working is taxed on wages, not on market revenue (6.7)", function()
		local ctx = makeCtx()
		local state = fresh()
		state.policies.TaxWorking = 1 -- 10%
		ctx.scratch.wagesReceived.Working = 20
		ctx.scratch.salesRevenue.Working = 100 -- must not count
		tax(state, ctx)
		Lib.eq(state.classes.Working.money, 8, "10 - floor(10% of 20)")
		Lib.eq(state.classes.State.money, 32, "State receives 2")
	end)

	Lib.test("Middle is taxed on market revenue, not on wages (6.7)", function()
		local ctx = makeCtx()
		local state = fresh()
		state.policies.TaxMiddle = 1 -- 10%
		ctx.scratch.salesRevenue.Middle = 10
		ctx.scratch.wagesReceived.Middle = 999 -- must not count
		tax(state, ctx)
		Lib.eq(state.classes.Middle.money, 24, "25 - floor(10% of 10)")
		Lib.eq(state.classes.State.money, 31, "State receives 1")
	end)

	Lib.test("an unpayable tax is skipped with a log (D-049)", function()
		local ctx = makeCtx()
		local state = fresh()
		state.classes.Working.money = 0 -- fixture: broke class
		state.policies.TaxWorking = 1 -- 10%
		ctx.scratch.wagesReceived.Working = 100
		tax(state, ctx)
		Lib.eq(state.classes.Working.money, 0, "no money taken")
		Lib.eq(state.classes.State.money, 30, "State receives nothing")
		Lib.truthy(hasLog(state, "Working tax skipped: cannot pay 10 Money"), "skip log")
	end)

	Lib.test("a disabled tax track does not tax (Easy has no TaxWorking)", function()
		local ctx = makeCtx()
		local state = StateFactory.create("Easy", SEATS, 41)
		ctx.scratch.wagesReceived.Working = 100
		ctx.scratch.salesRevenue.Middle = 100
		tax(state, ctx)
		-- Easy's startResourceMultiplier 1.25: Working 12, Middle 31, State 37
		Lib.eq(state.classes.Working.money, 12, "Working is not taxed on Easy")
		Lib.eq(state.classes.Middle.money, 31, "Middle is not taxed on Easy")
		Lib.eq(state.classes.State.money, 37, "State receives nothing")
		Lib.eq(#state.eventLog, 0, "no tax logs")
	end)

	Lib.test("no income means no tax and no log (6.7)", function()
		local ctx = makeCtx()
		local state = fresh()
		tax(state, ctx)
		Lib.eq(state.classes.State.money, 30, "State receives nothing")
		Lib.eq(#state.eventLog, 0, "no tax logs")
	end)

	Lib.test("taxed states stay serializable and deterministic (no RNG used)", function()
		local function runOnce(): any
			local ctx = makeCtx()
			local state = fresh()
			state.policies.TaxMiddle = 2
			ctx.scratch.salesRevenue.Middle = 20
			tax(state, ctx)
			return state
		end
		local a = runOnce()
		local b = runOnce()
		Lib.eq(#assertSerializable.validate(a), 0, "state serializable")
		Lib.eq(StateHash.compute(a), StateHash.compute(b), "same input -> same result")
		Lib.eq(a.classes.Middle.money, 21, "same money")
		Lib.eq(a.classes.State.money, 34, "same State money")
	end)
end

return M
