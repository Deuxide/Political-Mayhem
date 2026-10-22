--!nocheck
-- InfluenceStep tests (M3-T1; GAME_DESIGN 7.1, R10): every class gains its
-- per-Day Influence income and nobody passes the shared cap of 20. Runs
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
	print("influence step")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local assertSerializable = Loader.require(shared.Game.State.assertSerializable)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local InfluenceStep = Loader.require(shared.Game.Steps.InfluenceStep)

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

	local function income(state: any): any
		InfluenceStep.new():run(state, makeCtx())
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

	Lib.test("every class gains its per-Day Influence income (7.1)", function()
		local state = income(fresh())
		Lib.eq(state.classes.Working.influence, 6, "3 + 3")
		Lib.eq(state.classes.Middle.influence, 4, "2 + 2")
		Lib.eq(state.classes.Capitalist.influence, 2, "1 + 1")
		Lib.eq(state.classes.State.influence, 4, "2 + 2")
		Lib.truthy(hasLog(state, "Working gained 3 Influence"), "working log")
		Lib.truthy(hasLog(state, "Capitalist gained 1 Influence"), "capitalist log")
	end)

	Lib.test("the Influence is capped at 20 (7.1)", function()
		local state = fresh()
		state.classes.Working.influence = 19 -- fixture
		income(state)
		Lib.eq(state.classes.Working.influence, 20, "capped at 20")
		Lib.truthy(hasLog(state, "Working gained 1 Influence"), "only the fitting part")
	end)

	Lib.test("a class at the cap gains nothing and logs nothing (7.1)", function()
		local state = fresh()
		state.classes.Working.influence = 20 -- fixture
		income(state)
		Lib.eq(state.classes.Working.influence, 20, "unchanged")
		Lib.truthy(not hasLog(state, "Working gained"), "no log")
	end)

	Lib.test("influenced states stay serializable and deterministic (no RNG used)", function()
		local a = income(fresh())
		local b = income(fresh())
		Lib.eq(#assertSerializable.validate(a), 0, "state serializable")
		Lib.eq(StateHash.compute(a), StateHash.compute(b), "same input -> same result")
		Lib.eq(a.classes.Working.influence, 6, "same influence")
	end)
end

return M
