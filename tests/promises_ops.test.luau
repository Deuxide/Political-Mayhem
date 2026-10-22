--!nocheck
-- Promise tests (M4-T2; GAME_DESIGN 8.3): creating a promise from a spec
-- and auditing it per kind — Deliver, VoteYes, NoStrike, NoBreakAlliance —
-- one test per kind for kept and broken, plus the creation rules. Runs the
-- real modules and the real Bills step on real factory states via
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
	print("promise ops")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local assertSerializable = Loader.require(shared.Game.State.assertSerializable)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local Bills = Loader.require(shared.Game.Ops.Bills)
	local Promises = Loader.require(shared.Game.Ops.Promises)
	local Transfers = Loader.require(shared.Game.Ops.Transfers)
	local BillsStep = Loader.require(shared.Game.Steps.BillsStep)

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

	Lib.test("a promise is created from its spec (8.3)", function()
		local state = fresh()
		local promise, reason = Promises.create(state, "Middle", "Working", {
			kind = "Deliver",
			resource = "Money",
			amount = 5,
			to = "Working",
			byDay = 3,
		})
		Lib.truthy(promise ~= nil, "created: " .. tostring(reason))
		Lib.eq(promise.id, "Promise-1", "promise id")
		Lib.eq(promise.kind, "Deliver", "kind")
		Lib.eq(promise.from, "Middle", "promisor")
		Lib.eq(promise.to, "Working", "promisee")
		Lib.eq(promise.createdDay, 1, "created on Day 1")
		Lib.eq(promise.status, "open", "open")
		Lib.eq(#state.promises, 1, "one promise in the state")
	end)

	Lib.test("a promise to itself is refused (8.3)", function()
		local state = fresh()
		local promise, reason = Promises.create(state, "Middle", "Middle", {
			kind = "Deliver",
			resource = "Money",
			amount = 5,
			to = "Middle",
			byDay = 3,
		})
		Lib.eq(promise, nil, "refused")
		Lib.eq(reason, "a class cannot promise something to itself", "reason")
	end)

	Lib.test("a Deliver promise is kept when the transfer happened (8.3)", function()
		local state = fresh()
		local promise = Promises.create(state, "Middle", "Working", {
			kind = "Deliver",
			resource = "Money",
			amount = 5,
			to = "Working",
			byDay = 3,
		})
		Transfers.execute(state, "Middle", "Working", { Money = 5 })
		Lib.eq(promise.progress.delivered, 5, "the transfer counted")
		Lib.eq(Promises.audit(state, promise, 3), "kept", "kept at the Closing Bell of byDay")
	end)

	Lib.test("a Deliver promise is broken when the transfer fell short (8.3)", function()
		local state = fresh()
		local promise = Promises.create(state, "Middle", "Working", {
			kind = "Deliver",
			resource = "Money",
			amount = 5,
			to = "Working",
			byDay = 3,
		})
		Transfers.execute(state, "Middle", "Working", { Money = 2 })
		Lib.eq(promise.progress.delivered, 2, "only 2 arrived")
		Lib.eq(Promises.audit(state, promise, 1), "open", "still running before byDay")
		Lib.eq(Promises.audit(state, promise, 3), "broken", "broken at byDay")
	end)

	Lib.test("a transfer between other classes does not count (8.3)", function()
		local state = fresh()
		local promise = Promises.create(state, "Middle", "Working", {
			kind = "Deliver",
			resource = "Money",
			amount = 5,
			to = "Working",
			byDay = 3,
		})
		Transfers.execute(state, "Capitalist", "Working", { Money = 9 })
		Lib.eq(promise.progress.delivered, 0, "nothing counted")
		Lib.eq(Promises.audit(state, promise, 3), "broken", "broken")
	end)

	Lib.test("a VoteYes promise is kept when the yes vote was cast (8.3)", function()
		local state = fresh()
		local promise = Promises.create(state, "Working", "Middle", {
			kind = "VoteYes",
			policyId = "Tariff",
			level = 1,
			byDay = 3,
		})
		-- the Working votes yes on a Tariff bill
		local bill = Bills.propose(state, "State", "Tariff", 1, 60)
		state.drafts.Working.votes[bill.id] = { side = "yes", influence = 1 }
		BillsStep.new():run(state, makeCtx())
		Lib.eq(promise.progress.yesVoted, true, "the vote counted")
		Lib.eq(Promises.audit(state, promise, 3), "kept", "kept")
	end)

	Lib.test("a VoteYes promise is broken without the vote (8.3)", function()
		local state = fresh()
		local promise = Promises.create(state, "Working", "Middle", {
			kind = "VoteYes",
			policyId = "Tariff",
			level = 1,
			byDay = 3,
		})
		-- the bill passes, but the Working did not vote on it
		local bill = Bills.propose(state, "State", "Tariff", 1, 60)
		state.drafts.Capitalist.votes[bill.id] = { side = "yes", influence = 3 }
		BillsStep.new():run(state, makeCtx())
		Lib.eq(promise.progress.yesVoted, false, "no vote counted")
		Lib.eq(Promises.audit(state, promise, 3), "broken", "broken")
	end)

	Lib.test("a NoStrike promise is kept while the strike does not happen (8.3)", function()
		local state = fresh()
		local promise = Promises.create(state, "Working", "Capitalist", {
			kind = "NoStrike",
			untilDay = 3,
		})
		Lib.eq(Promises.audit(state, promise, 1), "open", "still running")
		Lib.eq(Promises.audit(state, promise, 3), "kept", "kept at untilDay")
	end)

	Lib.test("a NoStrike promise is broken by a strike (8.3)", function()
		local state = fresh()
		local promise = Promises.create(state, "Working", "Capitalist", {
			kind = "NoStrike",
			untilDay = 3,
		})
		Promises.deliver(state, { kind = "Strike", from = "Working", to = "Capitalist" })
		Lib.eq(promise.progress.struck, true, "the strike was seen")
		Lib.eq(Promises.audit(state, promise, 1), "broken", "broken at once")
	end)

	Lib.test("only Working can promise not to strike (8.3)", function()
		local state = fresh()
		local promise, reason = Promises.create(state, "Middle", "Capitalist", {
			kind = "NoStrike",
			untilDay = 3,
		})
		Lib.eq(promise, nil, "refused")
		Lib.eq(reason, "only Working can promise not to strike", "reason")
	end)

	Lib.test("a NoBreakAlliance promise is kept while the alliance holds (8.3)", function()
		local state = fresh()
		local promise = Promises.create(state, "Middle", "Capitalist", {
			kind = "NoBreakAlliance",
			untilDay = 3,
		})
		Lib.eq(Promises.audit(state, promise, 1), "open", "still running")
		Lib.eq(Promises.audit(state, promise, 3), "kept", "kept at untilDay")
	end)

	Lib.test("a NoBreakAlliance promise is broken by a broken alliance (8.3)", function()
		local state = fresh()
		local promise = Promises.create(state, "Middle", "Capitalist", {
			kind = "NoBreakAlliance",
			untilDay = 3,
		})
		-- the promisee breaks the alliance: the promise is broken all the
		-- same (8.3 watches the alliance, not the actor)
		Promises.deliver(state, { kind = "BreakAlliance", from = "Capitalist", to = "Middle" })
		Lib.eq(promise.progress.broken, true, "the break was seen")
		Lib.eq(Promises.audit(state, promise, 1), "broken", "broken at once")
	end)

	Lib.test("a break between other classes does not count (8.3)", function()
		local state = fresh()
		local promise = Promises.create(state, "Middle", "Capitalist", {
			kind = "NoBreakAlliance",
			untilDay = 3,
		})
		Promises.deliver(state, { kind = "BreakAlliance", from = "Working", to = "State" })
		Lib.eq(promise.progress.broken, false, "nothing counted")
		Lib.eq(Promises.audit(state, promise, 3), "kept", "kept")
	end)

	Lib.test("promised states stay serializable and deterministic (no RNG used)", function()
		local function runOnce(): any
			local state = fresh()
			local promise = Promises.create(state, "Middle", "Working", {
				kind = "Deliver",
				resource = "Money",
				amount = 5,
				to = "Working",
				byDay = 3,
			})
			Transfers.execute(state, "Middle", "Working", { Money = 5 })
			Promises.audit(state, promise, 3)
			return state
		end
		local a = runOnce()
		local b = runOnce()
		Lib.eq(#assertSerializable.validate(a), 0, "state serializable")
		Lib.eq(StateHash.compute(a), StateHash.compute(b), "same input -> same result")
		Lib.eq(a.promises[1].progress.delivered, 5, "same delivery")
	end)
end

return M
