--!nocheck
-- PublicServicesStep tests (M2-T5; GAME_DESIGN 6.8, R7's neighbor R8):
-- Universal mode distributes the State's Health and Education to the
-- classes' unmet needs in priority order Working, Middle, Capitalist, until
-- the State's stock or the needs run out; Market mode does nothing. The
-- needs themselves are §5.3 (scaled by the difficulty), the same numbers R9
-- consumes. Runs the real step on real factory states via tests/loader.luau.

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
	print("public services step")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local assertSerializable = Loader.require(shared.Game.State.assertSerializable)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local PublicServicesStep = Loader.require(shared.Game.Steps.PublicServicesStep)

	local function fresh(): any
		return StateFactory.create("Normal", SEATS, 41)
	end

	local function makeCtx(difficulty: string?): any
		return {
			rng = Rng.new(41),
			ruleSet = RuleSet.new(difficulty or "Normal"),
			-- what the M2-T7 pipeline will create fresh each resolution
			scratch = {
				wagesReceived = {},
				salesRevenue = {},
				unpaidSlots = 0,
				employedWorkers = 0,
			},
		}
	end

	local function distribute(state: any, ctx: any): any
		PublicServicesStep.new():run(state, ctx)
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

	Lib.test("Working has priority: it takes the pool before Middle (6.8)", function()
		local state = fresh()
		state.policies.PublicServices = 1 -- Universal
		state.classes.State.stock.health = 3 -- fixture: the pool
		state.classes.Middle.stock.health = 0 -- fixture: Middle is short too
		distribute(state, makeCtx())
		-- Working needs 4 Health (16 workers), has 1 -> 3 unmet -> takes all 3
		Lib.eq(state.classes.Working.stock.health, 4, "Working covered")
		Lib.eq(state.classes.Middle.stock.health, 0, "Middle got nothing (pool empty)")
		Lib.eq(state.classes.State.stock.health, 0, "State's stock given away")
		Lib.truthy(
			hasLog(state, "State gave Working 3 Health (free public services)"),
			"distribution log"
		)
		Lib.truthy(not hasLog(state, "gave Middle"), "no log for a class that got nothing")
	end)

	Lib.test("the pool is shared and the last class gets the remainder (6.8)", function()
		local state = fresh()
		state.policies.PublicServices = 1 -- Universal
		state.classes.State.stock.health = 4 -- fixture
		state.classes.State.stock.education = 1 -- fixture: nobody needs it
		state.classes.Middle.stock.health = 0 -- fixture
		distribute(state, makeCtx())
		Lib.eq(state.classes.Working.stock.health, 4, "Working took 3")
		Lib.eq(state.classes.Middle.stock.health, 1, "Middle took the last 1")
		Lib.eq(state.classes.State.stock.health, 0, "pool empty")
		-- Middle's education need is already covered, so the State's
		-- education stays with the State
		Lib.eq(state.classes.State.stock.education, 1, "leftover education stays")
		Lib.truthy(hasLog(state, "State gave Working 3 Health"), "working log")
		Lib.truthy(hasLog(state, "State gave Middle 1 Health"), "middle log")
	end)

	Lib.test("Market mode does nothing (6.8)", function()
		local state = fresh()
		state.policies.PublicServices = 0 -- Market (the default)
		state.classes.State.stock.health = 5 -- fixture
		state.classes.State.stock.education = 5 -- fixture
		distribute(state, makeCtx())
		Lib.eq(state.classes.State.stock.health, 5, "State keeps its stock")
		Lib.eq(state.classes.State.stock.education, 5, "State keeps its stock")
		Lib.eq(state.classes.Working.stock.health, 1, "Working unchanged")
		Lib.eq(#state.eventLog, 0, "no logs")
	end)

	Lib.test("only Health and Education are distributed (6.8)", function()
		local state = fresh()
		state.policies.PublicServices = 1 -- Universal
		state.classes.State.stock.food = 3 -- fixture
		state.classes.State.stock.health = 2 -- fixture
		distribute(state, makeCtx())
		-- Working needs 8 Food, has 4, but food is not distributed
		Lib.eq(state.classes.Working.stock.food, 4, "food untouched")
		Lib.eq(state.classes.State.stock.food, 3, "State keeps its food")
		-- Health is distributed, but only 2 are in the pool
		Lib.eq(state.classes.Working.stock.health, 3, "Working got the 2 available")
		Lib.eq(state.classes.State.stock.health, 0, "pool empty")
	end)

	Lib.test("Working's need follows the worker count (5.3)", function()
		local state = fresh()
		state.policies.PublicServices = 1 -- Universal
		state.classes.Working.workers = 8 -- fixture: 8 workers
		state.classes.State.stock.health = 2 -- fixture
		distribute(state, makeCtx())
		-- ceil(8 / 4) = 2 Health needed, Working has 1 -> 1 unmet
		Lib.eq(state.classes.Working.stock.health, 2, "only the unmet part is given")
		Lib.eq(state.classes.State.stock.health, 1, "one unit left over")
	end)

	Lib.test("the difficulty scales the needs (Extreme, 1.15)", function()
		local state = StateFactory.create("Extreme", SEATS, 41)
		state.policies.PublicServices = 1 -- Universal
		state.classes.State.stock.health = 5 -- fixture: exactly the scaled need
		distribute(state, makeCtx("Extreme"))
		-- Extreme: 16 workers -> base 4 Health, x1.15 rounded up = 5 needed;
		-- with the unscaled 4 the State would keep a unit
		Lib.eq(state.classes.Working.stock.health, 5, "scaled need covered")
		Lib.eq(state.classes.State.stock.health, 0, "pool empty")
		Lib.eq(state.classes.Middle.stock.health, 0, "no unit left for Middle")
	end)

	Lib.test("an empty State pool leaves everyone untouched (6.8)", function()
		local state = fresh()
		state.policies.PublicServices = 1 -- Universal
		distribute(state, makeCtx())
		Lib.eq(state.classes.Working.stock.health, 1, "Working unchanged")
		Lib.eq(state.classes.Middle.stock.health, 1, "Middle unchanged")
		Lib.eq(#state.eventLog, 0, "no logs")
	end)

	Lib.test("distributed states stay serializable and deterministic (no RNG used)", function()
		local function runOnce(): any
			local state = fresh()
			state.policies.PublicServices = 1
			state.classes.State.stock.health = 4
			state.classes.Middle.stock.health = 0
			distribute(state, makeCtx())
			return state
		end
		local a = runOnce()
		local b = runOnce()
		Lib.eq(#assertSerializable.validate(a), 0, "state serializable")
		Lib.eq(StateHash.compute(a), StateHash.compute(b), "same input -> same result")
		Lib.eq(a.classes.Working.stock.health, 4, "same distribution")
	end)
end

return M
