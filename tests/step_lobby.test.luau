--!nocheck
-- LobbyStep tests (M3-T1; GAME_DESIGN 7.1, R2): the conversion ratios
-- (Capitalist 2 Money per Influence, Middle 3), the per-Day lobby caps,
-- the shared Influence cap of 20, and the refusals (cannot lobby, cannot
-- afford) that cost nothing. Runs the real step on real factory states via
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
	print("lobby step")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local assertSerializable = Loader.require(shared.Game.State.assertSerializable)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local LobbyStep = Loader.require(shared.Game.Steps.LobbyStep)

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

	local function lobby(state: any, classId: string, amount: number): any
		state.drafts[classId].lobby = { amount = amount }
		LobbyStep.new():run(state, makeCtx())
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

	Lib.test("the conversion ratios are 2 Money per Influence (7.1)", function()
		local state = lobby(fresh(), "Capitalist", 3)
		Lib.eq(state.classes.Capitalist.money, 44, "50 - 3 x 2")
		Lib.eq(state.classes.Capitalist.influence, 4, "1 + 3")
		Lib.truthy(hasLog(state, "Capitalist bought 3 Influence for 6 Money"), "purchase log")
	end)

	Lib.test("Middle pays 3 Money per Influence (7.1)", function()
		local state = lobby(fresh(), "Middle", 2)
		Lib.eq(state.classes.Middle.money, 19, "25 - 2 x 3")
		Lib.eq(state.classes.Middle.influence, 4, "2 + 2")
	end)

	Lib.test("the per-Day lobby caps are enforced (7.1)", function()
		local state = fresh()
		lobby(state, "Capitalist", 5) -- cap 4
		Lib.eq(state.classes.Capitalist.money, 50, "money untouched")
		Lib.eq(state.classes.Capitalist.influence, 1, "influence untouched")
		Lib.truthy(
			hasLog(state, "Capitalist lobby skipped: at most 4 Influence per Day"),
			"capitalist cap log"
		)
		local middle = lobby(fresh(), "Middle", 3) -- cap 2
		Lib.eq(middle.classes.Middle.money, 25, "money untouched")
		Lib.truthy(
			hasLog(middle, "Middle lobby skipped: at most 2 Influence per Day"),
			"middle cap log"
		)
	end)

	Lib.test("the Influence cap of 20 is not passed (7.1)", function()
		local state = fresh()
		state.classes.Capitalist.influence = 18 -- fixture
		lobby(state, "Capitalist", 4)
		Lib.eq(state.classes.Capitalist.influence, 18, "influence untouched")
		Lib.eq(state.classes.Capitalist.money, 50, "money untouched")
		Lib.truthy(
			hasLog(state, "Capitalist lobby skipped: the Influence cap of 20 would be passed"),
			"cap log"
		)
		-- exactly up to the cap is allowed
		local ok = fresh()
		ok.classes.Capitalist.influence = 16 -- fixture
		lobby(ok, "Capitalist", 4)
		Lib.eq(ok.classes.Capitalist.influence, 20, "influence at the cap")
		Lib.eq(ok.classes.Capitalist.money, 42, "50 - 8")
	end)

	Lib.test("a lobby the class cannot afford is skipped and costs nothing (7.1)", function()
		local state = fresh()
		state.classes.Middle.money = 5 -- fixture: 2 Influence would cost 6
		lobby(state, "Middle", 2)
		Lib.eq(state.classes.Middle.money, 5, "money untouched")
		Lib.eq(state.classes.Middle.influence, 2, "influence untouched")
		Lib.truthy(hasLog(state, "Middle lobby skipped: cannot afford 6 Money"), "skip log")
	end)

	Lib.test("Working and State cannot lobby (7.1)", function()
		local state = fresh()
		lobby(state, "Working", 2)
		lobby(state, "State", 2)
		Lib.eq(state.classes.Working.money, 10, "Working money untouched")
		Lib.eq(state.classes.Working.influence, 3, "Working influence untouched")
		Lib.eq(state.classes.State.money, 30, "State money untouched")
		Lib.truthy(hasLog(state, "Working lobby skipped: Working cannot lobby"), "working log")
		Lib.truthy(hasLog(state, "State lobby skipped: State cannot lobby"), "state log")
	end)

	Lib.test("no lobby in the draft changes nothing (not even the hash)", function()
		local state = fresh()
		local before = StateHash.compute(state)
		LobbyStep.new():run(state, makeCtx())
		Lib.eq(StateHash.compute(state), before, "state untouched")
		Lib.eq(#state.eventLog, 0, "no log entries")
	end)

	Lib.test("lobbyed states stay serializable and deterministic (no RNG used)", function()
		local a = lobby(fresh(), "Capitalist", 4)
		local b = lobby(fresh(), "Capitalist", 4)
		Lib.eq(#assertSerializable.validate(a), 0, "state serializable")
		Lib.eq(StateHash.compute(a), StateHash.compute(b), "same input -> same result")
		Lib.eq(a.classes.Capitalist.money, 42, "same money")
	end)
end

return M
