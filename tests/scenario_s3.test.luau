--!nocheck
-- Scenario S3 (M3-T5; ROADMAP M3-T5): a lobbied bill passes. On Day 1 the
-- Capitalist lobbies Influence with Money; on Day 2 it proposes a bill and
-- commits that Influence to the vote, which is exactly what carries the
-- bill over the quorum of 5 — without the lobby the same vote would stay
-- at 3. The bill raises the Tariff, and the new tariff is already in force
-- in that same Day's market (GAME_DESIGN 7.3, 6.6).
--
-- Runs the real Match, pipeline, and steps through tests/loader.luau.

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
	print("scenario S3 (lobbied bill passes)")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local Match = Loader.require(shared.Game.Match)
	local Bills = Loader.require(shared.Game.Ops.Bills)

	local function newMatch(): any
		return Match.new(
			StateFactory.create("Normal", SEATS, 41),
			RuleSet.new("Normal"),
			Rng.new(41)
		)
	end

	local function resolve(match: any): any
		match:resolveDay(match:rng())
		return match:state()
	end

	local function hasLog(state: any, needle: string): boolean
		for _, entry in state.eventLog do
			if string.find(entry.text, needle, 1, true) ~= nil then
				return true
			end
		end
		return false
	end

	Lib.test("S3: Day 1 — the lobby buys Influence with Money (7.1)", function()
		local match = newMatch()
		match:state().drafts.Capitalist.lobby = { amount = 4 }
		local state = resolve(match)

		Lib.eq(state.day, 2, "day counter advanced")
		-- 4 Influence at 2 Money each
		Lib.eq(state.classes.Capitalist.money, 42, "50 - 8")
		-- 1 starting Influence + 4 lobbied + 1 income
		Lib.eq(state.classes.Capitalist.influence, 6, "1 + 4 + 1")
		Lib.eq(state.stability, 53, "7 unmet units, as in S1")
		Lib.truthy(hasLog(state, "Capitalist bought 4 Influence for 8 Money"), "lobby entry")
		Lib.eq(#state.eventLog, 12, "twelve log entries")
	end)

	Lib.test("S3: Day 2 — the lobbied bill passes and the Tariff bites (7.3, 6.6)", function()
		local match = newMatch()
		match:state().drafts.Capitalist.lobby = { amount = 4 }
		resolve(match)

		-- the live proposal, during the Window: the Capitalist spends 1
		-- Influence on the proposal and commits 4 to the vote
		local state = match:state()
		local bill = Bills.propose(state, "Capitalist", "Tariff", 1, 60)
		Lib.truthy(bill ~= nil, "the bill was proposed")
		state.drafts.Capitalist.votes[bill.id] = { side = "yes", influence = 4 }
		-- and it buys Goods, which the new tariff makes more expensive
		state.drafts.Capitalist.market.buy["goods"] = 2

		local after = resolve(match)

		Lib.eq(after.day, 3, "day counter advanced")
		-- the vote: 2 base votes + 4 committed Influence = 6, over the
		-- quorum of 5 (without the lobby it would be 3 and fail)
		Lib.eq(after.policies.Tariff, 1, "the Tariff is now level 1")
		Lib.truthy(hasLog(after, "Tariff is now level 1 (6 for, 0 against)"), "bill entry")
		Lib.truthy(hasLog(after, "Capitalist spent 4 Influence on its vote"), "spend entry")
		-- 6 - 1 proposal - 4 vote + 1 income = 2
		Lib.eq(after.classes.Capitalist.influence, 2, "influence after the vote")
		-- the import price is now 6 + 1 = 7 per unit, 2 units = 14
		Lib.eq(after.classes.Capitalist.money, 28, "42 - 14")
		Lib.eq(after.classes.State.money, 32, "State collected 2 tariff")
		Lib.truthy(
			hasLog(after, "Capitalist bought 2 Goods for 14 Money (incl. 2 Money tariff)"),
			"market entry"
		)
		-- 19 unmet units -> the penalty is capped at -10
		Lib.eq(after.stability, 43, "stability after Day 2")
		Lib.eq(#after.eventLog, 27, "fifteen more entries")
	end)

	Lib.test("S3: without the lobby the same vote would not pass (7.3)", function()
		-- the same Day 2 vote, but the Capitalist never lobbied: it has 1
		-- Influence, so it can only commit 1 -> 3 votes, under the quorum
		local match = newMatch()
		resolve(match)
		local state = match:state()
		local bill = Bills.propose(state, "Capitalist", "Tariff", 1, 60)
		Lib.truthy(bill ~= nil, "the bill was proposed")
		state.drafts.Capitalist.votes[bill.id] = { side = "yes", influence = 1 }
		local after = resolve(match)
		Lib.eq(after.policies.Tariff, 0, "the bill failed")
		Lib.truthy(hasLog(after, "The bill on Tariff failed (3 for, 0 against"), "failure entry")
	end)

	Lib.test("S3: the whole scenario is deterministic", function()
		local function runScenario(): any
			local match = newMatch()
			match:state().drafts.Capitalist.lobby = { amount = 4 }
			resolve(match)
			local state = match:state()
			local bill = Bills.propose(state, "Capitalist", "Tariff", 1, 60)
			state.drafts.Capitalist.votes[bill.id] = { side = "yes", influence = 4 }
			state.drafts.Capitalist.market.buy["goods"] = 2
			return resolve(match)
		end
		local a = runScenario()
		local b = runScenario()
		Lib.eq(StateHash.compute(a), StateHash.compute(b), "same input -> same state")
		Lib.eq(a.policies.Tariff, 1, "same Tariff")
		Lib.eq(a.classes.Capitalist.money, 28, "same money")
	end)
end

return M
