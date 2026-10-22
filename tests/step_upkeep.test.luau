--!nocheck
-- UpkeepStep tests (M2-T6; GAME_DESIGN 6.9, R9): the needs are consumed from
-- stock, unmet is what a class could not cover, the Stability change is
-- -1 per unmet unit (capped at -10) plus +2 when nothing is unmet, minus
-- 1 per unpaid wage slot and per outlawed strike, clamped to 0..100, and
-- the collapse counter advances at stability 0 and resets otherwise. Runs
-- the real step on real factory states via tests/loader.luau.

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
	print("upkeep step")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local assertSerializable = Loader.require(shared.Game.State.assertSerializable)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local Match = Loader.require(shared.Game.Match)
	local UpkeepStep = Loader.require(shared.Game.Steps.UpkeepStep)

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

	local function upkeep(state: any, ctx: any): any
		UpkeepStep.new():run(state, ctx or makeCtx())
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

	-- a state where every class can cover its needs
	local function allNeedsMet(state: any)
		state.classes.Working.stock.food = 8
		state.classes.Working.stock.health = 4
		state.classes.Middle.stock.food = 2
		state.classes.Middle.stock.goods = 1
		state.classes.Middle.stock.health = 1
		state.classes.Middle.stock.education = 1
		state.classes.Capitalist.stock.food = 1
		state.classes.Capitalist.stock.goods = 2
		state.classes.Capitalist.stock.health = 1
		return state
	end

	Lib.test("needs are consumed and unmet is what could not be covered (6.9)", function()
		local state = fresh()
		upkeep(state)
		-- Working needs 8 Food + 4 Health, has 4 + 1 -> 4 and 3 unmet
		Lib.eq(state.classes.Working.stock.food, 0, "food consumed")
		Lib.eq(state.classes.Working.stock.health, 0, "health consumed")
		-- Middle and Capitalist cover their needs exactly
		Lib.eq(state.classes.Middle.stock.food, 0, "middle food consumed")
		Lib.eq(state.classes.Middle.stock.education, 0, "middle education consumed")
		Lib.eq(state.classes.Capitalist.stock.goods, 0, "capitalist goods consumed")
		-- 7 unmet units -> stability 60 - 7
		Lib.eq(state.stability, 53, "stability after unmet")
		Lib.truthy(
			hasLog(state, "Working could not cover 4 Food and 3 Health"),
			"unmet log names the resources"
		)
		Lib.truthy(hasLog(state, "Stability -7 (7 unmet need unit(s))"), "stability log")
	end)

	Lib.test("the unmet penalty is capped at -10 (6.9)", function()
		local state = fresh()
		state.classes.Working.workers = 40 -- fixture: needs 20 Food + 10 Health
		upkeep(state)
		-- 25 unmet units, but the penalty stops at -10
		Lib.eq(state.stability, 50, "60 - 10")
		Lib.truthy(hasLog(state, "Stability -10"), "capped delta")
	end)

	Lib.test("no unmet need gives the +2 bonus (6.9)", function()
		local state = allNeedsMet(fresh())
		upkeep(state)
		Lib.eq(state.stability, 62, "60 + 2")
		Lib.truthy(hasLog(state, "Stability +2 (all needs met)"), "bonus log")
		Lib.eq(state.collapseCounter, 0, "no collapse")
	end)

	Lib.test("stability is clamped at 0 and at 100 (6.9)", function()
		local low = fresh()
		low.stability = 3
		low.classes.Working.workers = 40 -- fixture: more unmet than the cap
		upkeep(low)
		Lib.eq(low.stability, 0, "clamped at 0")
		local high = allNeedsMet(fresh())
		high.stability = 99
		upkeep(high)
		Lib.eq(high.stability, 100, "clamped at 100")
	end)

	Lib.test("the collapse counter advances at stability 0 and resets otherwise", function()
		local state = fresh()
		state.stability = 3
		state.classes.Working.workers = 40 -- fixture: unmet
		upkeep(state)
		Lib.eq(state.stability, 0, "stability at 0")
		Lib.eq(state.collapseCounter, 1, "counter advanced")
		Lib.truthy(hasLog(state, "collapse counter 1"), "collapse log")
		-- a Day with no unmet resets the counter
		local next_ = allNeedsMet(fresh())
		next_.collapseCounter = 1
		upkeep(next_)
		Lib.eq(next_.collapseCounter, 0, "counter reset")
	end)

	Lib.test("unpaid wage slots cost stability (6.4, 6.9)", function()
		local ctx = makeCtx()
		ctx.scratch.unpaidSlots = 3
		local state = allNeedsMet(fresh())
		upkeep(state, ctx)
		-- +2 bonus - 3 unpaid slots
		Lib.eq(state.stability, 59, "60 + 2 - 3")
		Lib.truthy(hasLog(state, "3 unpaid wage slot(s)"), "unpaid in the log")
	end)

	Lib.test("an outlawed strike costs stability (6.5, 6.9)", function()
		local state = allNeedsMet(fresh())
		state.policies.StrikeRights = 0 -- Outlawed
		state.drafts.Working.strike = { target = "Capitalist" }
		upkeep(state)
		-- +2 bonus - 1 outlawed strike
		Lib.eq(state.stability, 61, "60 + 2 - 1")
		Lib.truthy(hasLog(state, "1 outlawed strike(s)"), "strike in the log")
	end)

	Lib.test("an allowed strike costs no stability (6.5)", function()
		local state = allNeedsMet(fresh())
		state.policies.StrikeRights = 1 -- Allowed
		state.drafts.Working.strike = { target = "Capitalist" }
		upkeep(state)
		Lib.eq(state.stability, 62, "60 + 2")
		Lib.truthy(not hasLog(state, "outlawed"), "no strike penalty")
	end)

	Lib.test("an outlawed strike costs Working Influence and pays the State (6.5)", function()
		local state = allNeedsMet(fresh())
		state.policies.StrikeRights = 0 -- Outlawed
		state.drafts.Working.strike = { target = "Capitalist" }
		upkeep(state)
		-- Working 3 - 2, the State 2 + 1
		Lib.eq(state.classes.Working.influence, 1, "Working lost 2 Influence")
		Lib.eq(state.classes.State.influence, 3, "State gained 1 Influence")
		-- +2 bonus - 1 outlawed strike
		Lib.eq(state.stability, 61, "60 + 2 - 1")
		Lib.truthy(hasLog(state, "Working lost 2 Influence to the outlawed strike"), "loss log")
		Lib.truthy(hasLog(state, "State gained 1 Influence from the outlawed strike"), "gain log")
	end)

	Lib.test("the Working's Influence never falls below 0 (6.5)", function()
		local state = allNeedsMet(fresh())
		state.policies.StrikeRights = 0
		state.classes.Working.influence = 1 -- fixture
		state.drafts.Working.strike = { target = "Capitalist" }
		upkeep(state)
		Lib.eq(state.classes.Working.influence, 0, "only what it had")
		Lib.truthy(hasLog(state, "Working lost 1 Influence to the outlawed strike"), "loss log")
	end)

	Lib.test("the State never gains past the Influence cap (7.1)", function()
		local state = allNeedsMet(fresh())
		state.policies.StrikeRights = 0
		state.classes.State.influence = 20 -- fixture: at the cap
		state.drafts.Working.strike = { target = "Capitalist" }
		upkeep(state)
		Lib.eq(state.classes.State.influence, 20, "still at the cap")
		Lib.truthy(not hasLog(state, "State gained"), "no gain, so no entry")
	end)

	Lib.test("no strike means no penalty (6.5)", function()
		local state = allNeedsMet(fresh())
		state.policies.StrikeRights = 0
		upkeep(state)
		Lib.eq(state.classes.Working.influence, 3, "Working untouched")
		Lib.eq(state.classes.State.influence, 2, "State untouched")
		Lib.eq(state.stability, 62, "60 + 2")
	end)

	Lib.test("the penalty lands before the Day's Influence income (6.5, 7.1)", function()
		-- Working at 19: the penalty first gives 17 + 3 income = 20; the
		-- other order would cap the income at 20 and then take 2 -> 18
		local state = allNeedsMet(fresh())
		state.policies.StrikeRights = 0
		state.classes.Working.influence = 19 -- fixture
		state.drafts.Working.strike = { target = "Capitalist" }
		upkeep(state)
		Lib.eq(state.classes.Working.influence, 17, "the penalty first")
		local after = allNeedsMet(fresh())
		after.policies.StrikeRights = 0
		after.classes.Working.influence = 19
		after.drafts.Working.strike = { target = "Capitalist" }
		local InfluenceStep = Loader.require(shared.Game.Steps.InfluenceStep)
		InfluenceStep.new():run(after, makeCtx())
		Lib.eq(after.classes.Working.influence, 20, "the income caps at 20")
	end)

	Lib.test("the penalty applies on every strike Day (6.5)", function()
		local match =
			Match.new(StateFactory.create("Normal", SEATS, 41), RuleSet.new("Normal"), Rng.new(41))
		local state = match:state()
		state.policies.StrikeRights = 0
		state.drafts.Working.strike = { target = "Capitalist" }
		match:resolveDay(match:rng())
		-- 3 - 2 + 3 income = 4
		Lib.eq(match:state().classes.Working.influence, 4, "after Day 1")
		match:resolveDay(match:rng())
		-- 4 - 2 + 3 income = 5
		Lib.eq(match:state().classes.Working.influence, 5, "after Day 2")
	end)

	Lib.test("upkeep states stay serializable and deterministic (no RNG used)", function()
		local function runOnce(): any
			local state = fresh()
			upkeep(state)
			return state
		end
		local a = runOnce()
		local b = runOnce()
		Lib.eq(#assertSerializable.validate(a), 0, "state serializable")
		Lib.eq(StateHash.compute(a), StateHash.compute(b), "same input -> same result")
		Lib.eq(a.stability, 53, "same stability")
	end)
end

return M
