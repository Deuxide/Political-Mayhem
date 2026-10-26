--!nocheck
-- Bills ops tests (M3-T2; GAME_DESIGN 7.3): the propose validation (cost,
-- cutoff, live limit, one bill per class, level range and step limit,
-- disabled tracks) and the vote tally (base votes + committed Influence,
-- quorum 5, ties fail, secret ballots, Influence spent on a lost bill).
-- Runs the real module on real factory states via tests/loader.luau.

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
	print("bills ops")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local Bills = Loader.require(shared.Game.Ops.Bills)

	local function fresh(): any
		return StateFactory.create("Normal", SEATS, 41)
	end

	local function vote(
		state: any,
		classId: string,
		billId: string,
		side: string,
		influence: number
	)
		state.drafts[classId].votes[billId] = { side = side, influence = influence }
	end

	Lib.test("a valid proposal creates a bill and costs 1 Influence (7.3)", function()
		local state = fresh()
		local bill, reason = Bills.propose(state, "Capitalist", "Tariff", 1, 60)
		Lib.truthy(bill ~= nil, "proposal accepted")
		Lib.eq(reason, "", "no reason")
		Lib.eq(#state.bills, 1, "one live bill")
		Lib.eq(bill.id, "Bill-1", "bill id")
		Lib.eq(bill.policyId, "Tariff", "policy")
		Lib.eq(bill.level, 1, "level")
		Lib.eq(bill.proposer, "Capitalist", "proposer")
		Lib.eq(bill.proposedDay, 1, "proposed Day")
		Lib.eq(state.classes.Capitalist.influence, 0, "1 - 1 Influence")
	end)

	Lib.test("the State proposes for free (7.3)", function()
		local state = fresh()
		local bill = Bills.propose(state, "State", "Tariff", 1, 60)
		Lib.truthy(bill ~= nil, "proposal accepted")
		Lib.eq(state.classes.State.influence, 2, "influence untouched")
	end)

	Lib.test("a class without the Influence cannot propose (7.3)", function()
		local state = fresh()
		state.classes.Capitalist.influence = 0 -- fixture
		local bill, reason = Bills.propose(state, "Capitalist", "Tariff", 1, 60)
		Lib.eq(bill, nil, "refused")
		Lib.eq(reason, "Capitalist has not enough Influence to propose", "reason")
		Lib.eq(#state.bills, 0, "no bill created")
	end)

	Lib.test("proposals close 20 s before the Window ends (7.3)", function()
		local state = fresh()
		local bill, reason = Bills.propose(state, "Capitalist", "Tariff", 1, 20)
		Lib.eq(bill, nil, "refused at the cutoff")
		Lib.eq(reason, "the proposal window has closed", "reason")
		local ok = fresh()
		local accepted = Bills.propose(ok, "Capitalist", "Tariff", 1, 21)
		Lib.truthy(accepted ~= nil, "accepted one second before the cutoff")
	end)

	Lib.test("at most 2 bills may be live at once (7.3)", function()
		local state = fresh()
		Bills.propose(state, "Capitalist", "Tariff", 1, 60)
		Bills.propose(state, "Middle", "TaxMiddle", 2, 60)
		local bill, reason = Bills.propose(state, "State", "PublicServices", 1, 60)
		Lib.eq(bill, nil, "third bill refused")
		Lib.eq(reason, "at most 2 bills can be live at once", "reason")
		Lib.eq(#state.bills, 2, "still two bills")
	end)

	Lib.test("a class may propose one bill per Day (7.3)", function()
		local state = fresh()
		Bills.propose(state, "Capitalist", "Tariff", 1, 60)
		local bill, reason = Bills.propose(state, "Capitalist", "TaxMiddle", 2, 60)
		Lib.eq(bill, nil, "second bill refused")
		Lib.eq(reason, "Capitalist already proposed a bill today", "reason")
		Lib.eq(#state.bills, 1, "one bill")
	end)

	Lib.test("a track with 4+ levels moves by at most 1 step (7.3)", function()
		local state = fresh()
		-- TaxWorking starts at level 1
		local bill, reason = Bills.propose(state, "Capitalist", "TaxWorking", 3, 60)
		Lib.eq(bill, nil, "two steps refused")
		Lib.eq(reason, "TaxWorking changes by at most 1 step", "reason")
		local ok = fresh()
		local accepted = Bills.propose(ok, "Capitalist", "TaxWorking", 2, 60)
		Lib.truthy(accepted ~= nil, "one step accepted")
	end)

	Lib.test("a shorter track may jump to any level (7.3)", function()
		local state = fresh()
		-- Tariff has 3 levels and starts at 0
		local bill = Bills.propose(state, "Capitalist", "Tariff", 2, 60)
		Lib.truthy(bill ~= nil, "two steps accepted")
	end)

	Lib.test("the legal target bounds are shared with the UI (7.3)", function()
		local wageLow, wageHigh = Bills.targetBounds("Wage", 2)
		Lib.eq(wageLow, 1, "Wage low")
		Lib.eq(wageHigh, 3, "Wage high")

		local taxLow, taxHigh = Bills.targetBounds("TaxWorking", 1)
		Lib.eq(taxLow, 0, "TaxWorking low")
		Lib.eq(taxHigh, 2, "TaxWorking high")

		local tariffLow, tariffHigh = Bills.targetBounds("Tariff", 1)
		Lib.eq(tariffLow, 0, "Tariff low")
		Lib.eq(tariffHigh, 2, "Tariff high")
	end)

	Lib.test("the level must be inside the track's range (7.3)", function()
		local state = fresh()
		local bill, reason = Bills.propose(state, "Capitalist", "Tariff", 3, 60)
		Lib.eq(bill, nil, "refused")
		Lib.eq(reason, "level 3 is out of range for Tariff", "reason")
	end)

	Lib.test("a track that is not active in this match cannot be proposed (7.2)", function()
		local state = StateFactory.create("Easy", SEATS, 41)
		local bill, reason = Bills.propose(state, "Capitalist", "TaxWorking", 2, 60)
		Lib.eq(bill, nil, "refused")
		Lib.eq(reason, "the TaxWorking track is not active in this match", "reason")
	end)

	Lib.test("a bill passes with the quorum and more yes than no (7.3)", function()
		local state = fresh()
		local bill = Bills.propose(state, "Capitalist", "Tariff", 1, 60)
		-- Working: 4 base votes + 1 committed Influence = 5
		vote(state, "Working", bill.id, "yes", 1)
		local tally = Bills.tally(state, bill.id)
		Lib.eq(tally.yesWeight, 5, "yes weight")
		Lib.eq(tally.noWeight, 0, "no weight")
		Lib.eq(tally.passed, true, "passed")
		Lib.eq(tally.reason, "passed", "reason")
	end)

	Lib.test("a bill without the quorum fails (7.3)", function()
		local state = fresh()
		local bill = Bills.propose(state, "Capitalist", "Tariff", 1, 60)
		vote(state, "Working", bill.id, "yes", 0) -- 4 base votes only
		local tally = Bills.tally(state, bill.id)
		Lib.eq(tally.yesWeight, 4, "yes weight")
		Lib.eq(tally.passed, false, "failed")
		Lib.eq(tally.reason, "not enough support", "reason")
	end)

	Lib.test("more votes against than for fails (7.3)", function()
		local state = fresh()
		local bill = Bills.propose(state, "Capitalist", "Tariff", 1, 60)
		vote(state, "Working", bill.id, "no", 0)
		local tally = Bills.tally(state, bill.id)
		Lib.eq(tally.noWeight, 4, "no weight")
		Lib.eq(tally.passed, false, "failed")
		Lib.eq(tally.reason, "more against than for", "reason")
	end)

	Lib.test("a tie fails (7.3)", function()
		local state = fresh()
		local bill = Bills.propose(state, "Capitalist", "Tariff", 1, 60)
		vote(state, "Working", bill.id, "yes", 0) -- 4
		vote(state, "Middle", bill.id, "no", 1) -- 3 + 1
		local tally = Bills.tally(state, bill.id)
		Lib.eq(tally.yesWeight, 4, "yes weight")
		Lib.eq(tally.noWeight, 4, "no weight")
		Lib.eq(tally.passed, false, "failed")
		Lib.eq(tally.reason, "tie", "reason")
	end)

	Lib.test("an abstaining class adds nothing (7.3)", function()
		local state = fresh()
		local bill = Bills.propose(state, "Capitalist", "Tariff", 1, 60)
		vote(state, "Working", bill.id, "yes", 0)
		local tally = Bills.tally(state, bill.id)
		Lib.eq(tally.yesWeight, 4, "only the voting class counts")
		Lib.eq(tally.noWeight, 0, "no abstentions")
	end)

	Lib.test("the tally exposes no ballots (secret until Closing Bell, 7.3/13)", function()
		local state = fresh()
		local bill = Bills.propose(state, "Capitalist", "Tariff", 1, 60)
		vote(state, "Working", bill.id, "yes", 2)
		vote(state, "Middle", bill.id, "no", 1)
		local tally = Bills.tally(state, bill.id)
		local fields = 0
		for _ in tally do
			fields += 1
		end
		Lib.eq(fields, 4, "only the aggregate fields")
		Lib.eq(tally.yesWeight, 6, "yes weight")
		Lib.eq(tally.noWeight, 4, "no weight")
	end)

	Lib.test("the committed Influence is spent even when the bill fails (7.3)", function()
		local state = fresh()
		local bill = Bills.propose(state, "Capitalist", "Tariff", 1, 60)
		state.classes.Working.influence = 3 -- fixture
		vote(state, "Working", bill.id, "no", 3)
		local tally = Bills.tally(state, bill.id)
		Lib.eq(tally.passed, false, "the bill fails")
		local spent = Bills.spendCommitted(state, bill.id)
		Lib.eq(spent.Working, 3, "3 Influence spent")
		Lib.eq(state.classes.Working.influence, 0, "influence gone")
	end)

	Lib.test("the committed Influence is clamped to what the class has (7.1)", function()
		local state = fresh()
		local bill = Bills.propose(state, "Capitalist", "Tariff", 1, 60)
		state.classes.Working.influence = 2 -- fixture
		vote(state, "Working", bill.id, "yes", 5)
		local tally = Bills.tally(state, bill.id)
		Lib.eq(tally.yesWeight, 6, "4 base votes + 2 Influence")
		local spent = Bills.spendCommitted(state, bill.id)
		Lib.eq(spent.Working, 2, "only 2 spent")
		Lib.eq(state.classes.Working.influence, 0, "influence gone")
	end)
end

return M
