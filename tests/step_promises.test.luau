--!nocheck
-- Promises step tests (M4-T3; GAME_DESIGN 8.3, R11): the promises that
-- are due are judged at the Closing Bell, the promisor's reputation
-- counts it, and the outcome is public — the log line names both classes.
-- Also the reputation score (kept + 1) / (kept + broken + 2) and its 0 to 5
-- stars. Runs the real step on real factory states via tests/loader.luau.

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
	print("promises step")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local Match = Loader.require(shared.Game.Match)
	local Promises = Loader.require(shared.Game.Ops.Promises)
	local Reputation = Loader.require(shared.Game.Ops.Reputation)
	local Transfers = Loader.require(shared.Game.Ops.Transfers)
	local PromisesStep = Loader.require(shared.Game.Steps.PromisesStep)

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
			},
		}
	end

	local function audit(state: any): any
		PromisesStep.new():run(state, makeCtx())
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

	Lib.test("a kept promise counts and is public (8.3)", function()
		local state = fresh()
		local promise = Promises.create(state, "Middle", "Working", {
			kind = "Deliver",
			resource = "Money",
			amount = 5,
			to = "Working",
			byDay = 1,
		})
		Transfers.execute(state, "Middle", "Working", { Money = 5 })
		audit(state)
		Lib.eq(promise.status, "kept", "the promise was kept")
		Lib.eq(state.reputation.Middle.kept, 1, "the promisor kept one")
		Lib.eq(state.reputation.Middle.broken, 0, "and broke none")
		Lib.eq(state.reputation.Working.kept, 0, "the promisee is unaffected")
		Lib.truthy(
			hasLog(state, "Middle kept their Deliver promise to Working"),
			"the log names both classes"
		)
	end)

	Lib.test("a broken promise counts and is public (8.3)", function()
		local state = fresh()
		local promise = Promises.create(state, "Middle", "Working", {
			kind = "Deliver",
			resource = "Money",
			amount = 5,
			to = "Working",
			byDay = 1,
		})
		Transfers.execute(state, "Middle", "Working", { Money = 2 })
		audit(state)
		Lib.eq(promise.status, "broken", "the promise was broken")
		Lib.eq(state.reputation.Middle.broken, 1, "the promisor broke one")
		Lib.truthy(
			hasLog(state, "Middle broke their Deliver promise to Working"),
			"the log names both classes"
		)
	end)

	Lib.test("a promise that is not due yet stays open (8.3)", function()
		local state = fresh()
		local promise = Promises.create(state, "Middle", "Working", {
			kind = "Deliver",
			resource = "Money",
			amount = 5,
			to = "Working",
			byDay = 3,
		})
		audit(state)
		Lib.eq(promise.status, "open", "still open")
		Lib.eq(state.reputation.Middle.kept, 0, "nothing counted")
		Lib.eq(state.reputation.Middle.broken, 0, "nothing counted")
		Lib.eq(#state.eventLog, 0, "no log")
	end)

	Lib.test("a promise is judged once (8.3)", function()
		local state = fresh()
		local promise = Promises.create(state, "Middle", "Working", {
			kind = "Deliver",
			resource = "Money",
			amount = 5,
			to = "Working",
			byDay = 1,
		})
		Transfers.execute(state, "Middle", "Working", { Money = 5 })
		audit(state)
		audit(state)
		Lib.eq(state.reputation.Middle.kept, 1, "counted once")
		Lib.eq(promise.status, "kept", "still kept")
	end)

	Lib.test("a strike in the draft breaks a NoStrike promise (8.3)", function()
		local state = fresh()
		local promise = Promises.create(state, "Working", "Capitalist", {
			kind = "NoStrike",
			untilDay = 5,
		})
		state.drafts.Working.strike = { target = "Capitalist" }
		audit(state)
		Lib.eq(promise.status, "broken", "the promise was broken at once")
		Lib.eq(state.reputation.Working.broken, 1, "the promisor broke one")
		Lib.truthy(
			hasLog(state, "Working broke their NoStrike promise to Capitalist"),
			"the log names both classes"
		)
	end)

	Lib.test("the reputation score is (kept + 1) / (kept + broken + 2) (8.3)", function()
		Lib.eq(Reputation.score({ kept = 0, broken = 0 }), 0.5, "a fresh class")
		Lib.eq(Reputation.score({ kept = 2, broken = 1 }), 0.6, "two kept, one broken")
		Lib.eq(Reputation.score({ kept = 3, broken = 3 }), 0.5, "evenly split")
		Lib.eq(Reputation.score({ kept = 9, broken = 0 }), 10 / 11, "never perfect")
		Lib.eq(Reputation.stars({ kept = 0, broken = 0 }), 2.5, "a fresh class has 2.5 stars")
		Lib.eq(Reputation.stars({ kept = 2, broken = 1 }), 3, "two kept, one broken")
	end)

	Lib.test("the R11 step runs inside the pipeline (10)", function()
		local match =
			Match.new(StateFactory.create("Normal", SEATS, 41), RuleSet.new("Normal"), Rng.new(41))
		local state = match:state()
		Promises.create(state, "Middle", "Working", {
			kind = "Deliver",
			resource = "Money",
			amount = 5,
			to = "Working",
			byDay = 1,
		})
		Transfers.execute(state, "Middle", "Working", { Money = 5 })
		match:resolveDay(match:rng())
		local after = match:state()
		Lib.eq(after.promises[1].status, "kept", "the pipeline judged the promise")
		Lib.eq(after.reputation.Middle.kept, 1, "the reputation counted it")
		Lib.truthy(
			hasLog(after, "Middle kept their Deliver promise to Working"),
			"the log is in the Day's report"
		)
	end)
end

return M
