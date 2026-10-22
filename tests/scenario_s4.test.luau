--!nocheck
-- Scenario S4 (M4-T5; ROADMAP M4-T5): a trade carries a promise, the
-- delivery falls short, and the broken promise shows up in the Evening
-- Report and in the promisor's reputation. The record below is the
-- design's own arithmetic (GAME_DESIGN 5.2, 5.3, 6.7, 6.9, 8.2, 8.3).
--
-- Runs the real Match, pipeline, and modules through tests/loader.luau.

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
	print("scenario S4 (broken promise)")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local Match = Loader.require(shared.Game.Match)
	local Trade = Loader.require(shared.Game.Ops.Trade)
	local Transfers = Loader.require(shared.Game.Ops.Transfers)

	local function newMatch(): any
		return Match.new(
			StateFactory.create("Normal", SEATS, 41),
			RuleSet.new("Normal"),
			Rng.new(41)
		)
	end

	local function hasLog(state: any, needle: string): boolean
		for _, entry in state.eventLog do
			if string.find(entry.text, needle, 1, true) ~= nil then
				return true
			end
		end
		return false
	end

	-- The trade that carries the promise: the Middle gives 5 Money for 2
	-- Goods and promises to deliver 3 Money to the Capitalist by Day 2.
	local function tradeWithPromise(match: any)
		local state = match:state()
		local offer = Trade.propose(state, "Middle", "Capitalist", { Money = 5 }, { Goods = 2 }, {
			{
				kind = "Deliver",
				resource = "Money",
				amount = 3,
				to = "Capitalist",
				byDay = 2,
			},
		}, 120)
		Lib.truthy(offer ~= nil, "the offer was made")
		local ok, reason = Trade.respond(state, offer.id, true, 10)
		Lib.eq(ok, true, "the trade was accepted: " .. tostring(reason))
	end

	Lib.test("S4: Day 1 — the trade runs and the promise is open", function()
		local match = newMatch()
		tradeWithPromise(match)
		local state = match:state()
		-- the immediate parts of the trade moved
		Lib.eq(state.classes.Middle.money, 20, "25 - 5")
		Lib.eq(state.classes.Capitalist.money, 55, "50 + 5")
		Lib.eq(state.classes.Middle.stock.goods, 3, "1 + 2")
		Lib.eq(state.classes.Capitalist.stock.goods, 0, "2 - 2")
		-- the promise was created and is still running
		Lib.eq(#state.promises, 1, "one promise")
		Lib.eq(state.promises[1].kind, "Deliver", "kind")
		Lib.eq(state.promises[1].from, "Middle", "promisor")
		Lib.eq(state.promises[1].to, "Capitalist", "promisee")
		Lib.eq(state.promises[1].status, "open", "open")
		Lib.eq(state.promises[1].progress.delivered, 0, "the trade itself is not the delivery")
		-- the trade is in the report
		Lib.truthy(
			hasLog(state, "Middle gave Capitalist 5 Money and received 2 Goods"),
			"the trade entry"
		)

		-- now the Day resolves
		match:resolveDay(match:rng())
		local after = match:state()
		Lib.eq(after.day, 2, "day counter advanced")
		-- 9 unmet units: Working 7 and the Capitalist 2 (it gave its Goods
		-- away) -> stability 60 - 9
		Lib.eq(after.stability, 51, "stability after Day 1")
		-- the promise is not due yet: nothing is counted
		Lib.eq(after.promises[1].status, "open", "still open")
		Lib.eq(after.reputation.Middle.kept, 0, "nothing kept")
		Lib.eq(after.reputation.Middle.broken, 0, "nothing broken")
		Lib.truthy(not hasLog(after, "promise"), "no promise entry yet")
		Lib.eq(#after.eventLog, 13, "thirteen log entries")
	end)

	Lib.test("S4: Day 2 — the short delivery breaks the promise in the open", function()
		local match = newMatch()
		tradeWithPromise(match)
		match:resolveDay(match:rng())

		-- the Middle delivers 2 of the 3 promised Money
		local state = match:state()
		local ok = Transfers.execute(state, "Middle", "Capitalist", { Money = 2 })
		Lib.eq(ok, true, "the delivery happened")
		Lib.eq(state.promises[1].progress.delivered, 2, "2 of 3 arrived")

		match:resolveDay(match:rng())
		local after = match:state()

		Lib.eq(after.day, 3, "day counter advanced")
		Lib.eq(after.promises[1].status, "broken", "the promise was broken")
		Lib.eq(after.reputation.Middle.broken, 1, "the promisor's reputation counts it")
		Lib.eq(after.reputation.Middle.kept, 0, "and kept none")
		Lib.eq(after.reputation.Capitalist.broken, 0, "the promisee is unaffected")
		Lib.truthy(
			hasLog(after, "Middle broke their Deliver promise to Capitalist"),
			"the broken promise is public and names both classes"
		)
		-- 20 unmet units -> the penalty is capped at -10
		Lib.eq(after.stability, 41, "stability after Day 2")
		Lib.eq(after.classes.Middle.money, 18, "20 - 2 delivered")
		Lib.eq(after.classes.Capitalist.money, 57, "55 + 2 delivered")
		Lib.eq(#after.eventLog, 26, "thirteen more entries")
	end)

	Lib.test("S4: a promise that is delivered in full is kept instead", function()
		local match = newMatch()
		tradeWithPromise(match)
		match:resolveDay(match:rng())
		-- the Middle delivers the full 3
		local state = match:state()
		Transfers.execute(state, "Middle", "Capitalist", { Money = 3 })
		match:resolveDay(match:rng())
		local after = match:state()
		Lib.eq(after.promises[1].status, "kept", "the promise was kept")
		Lib.eq(after.reputation.Middle.kept, 1, "the promisor kept one")
		Lib.eq(after.reputation.Middle.broken, 0, "and broke none")
		Lib.truthy(
			hasLog(after, "Middle kept their Deliver promise to Capitalist"),
			"the kept promise is public too"
		)
	end)

	Lib.test("S4: the whole scenario is deterministic", function()
		local function runScenario(): any
			local match = newMatch()
			tradeWithPromise(match)
			match:resolveDay(match:rng())
			local state = match:state()
			Transfers.execute(state, "Middle", "Capitalist", { Money = 2 })
			match:resolveDay(match:rng())
			return match:state()
		end
		local a = runScenario()
		local b = runScenario()
		Lib.eq(StateHash.compute(a), StateHash.compute(b), "same input -> same state")
		Lib.eq(a.stability, 41, "same stability")
		Lib.eq(a.reputation.Middle.broken, 1, "same reputation")
	end)
end

return M
