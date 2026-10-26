--!nocheck
-- Alliance tests (M4-T4; GAME_DESIGN 8.4): proposing, accepting, breaking,
-- the age in Days, and the rule that a class has at most one alliance. Also
-- that a break is public and breaks the NoBreakAlliance promises between
-- the two classes (8.3). Runs the real module on real factory states via
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
	print("alliance ops")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local assertSerializable = Loader.require(shared.Game.State.assertSerializable)
	local Alliances = Loader.require(shared.Game.Ops.Alliances)
	local Promises = Loader.require(shared.Game.Ops.Promises)

	local function fresh(): any
		return StateFactory.create("Normal", SEATS, 41)
	end

	local function hasLog(state: any, needle: string): boolean
		for _, entry in state.eventLog do
			if string.find(entry.text, needle, 1, true) ~= nil then
				return true
			end
		end
		return false
	end

	Lib.test("a proposal is pending until it is accepted (8.4)", function()
		local state = fresh()
		local proposal, reason = Alliances.propose(state, "Middle", "Capitalist")
		Lib.truthy(proposal ~= nil, "accepted: " .. tostring(reason))
		Lib.eq(proposal.from, "Middle", "the proposer")
		Lib.eq(proposal.to, "Capitalist", "the recipient")
		Lib.eq(proposal.proposedDay, 1, "proposed on Day 1")
		Lib.eq(#state.allianceProposals, 1, "one pending proposal")
		Lib.eq(#state.alliances, 0, "no alliance yet")
	end)

	Lib.test("accepting forms the alliance (8.4)", function()
		local state = fresh()
		local proposal = Alliances.propose(state, "Middle", "Capitalist")
		local alliance, reason = Alliances.respond(state, proposal.id, true)
		Lib.truthy(alliance ~= nil, "accepted: " .. tostring(reason))
		Lib.eq(alliance.id, "Alliance-1", "alliance id")
		Lib.eq(#alliance.members, 2, "two members")
		Lib.eq(alliance.formedOnDay, 1, "formed on Day 1")
		Lib.eq(#state.alliances, 1, "one alliance")
		Lib.eq(#state.allianceProposals, 0, "the proposal is gone")
		Lib.truthy(
			hasLog(state, "Middle and Capitalist formed an alliance"),
			"the alliance is public"
		)
	end)

	Lib.test("declining drops the proposal and forms nothing (8.4)", function()
		local state = fresh()
		local proposal = Alliances.propose(state, "Middle", "Capitalist")
		local alliance = Alliances.respond(state, proposal.id, false)
		Lib.eq(alliance, nil, "no alliance")
		Lib.eq(#state.alliances, 0, "no alliance")
		Lib.eq(#state.allianceProposals, 0, "the proposal is gone")
	end)

	Lib.test("a class may have at most one alliance (8.4)", function()
		local state = fresh()
		local first = Alliances.propose(state, "Middle", "Capitalist")
		Alliances.respond(state, first.id, true)
		-- the Middle is already allied
		local second, reason = Alliances.propose(state, "Middle", "Working")
		Lib.eq(second, nil, "refused")
		Lib.eq(reason, "Middle already has an alliance", "reason")
		-- and so is the Capitalist
		local third, reason3 = Alliances.propose(state, "State", "Capitalist")
		Lib.eq(third, nil, "refused")
		Lib.eq(reason3, "Capitalist already has an alliance", "reason")
		Lib.eq(#state.alliances, 1, "still one alliance")
	end)

	Lib.test("an alliance is checked again when the proposal is accepted (8.4)", function()
		local state = fresh()
		local proposal = Alliances.propose(state, "Middle", "Capitalist")
		-- the Capitalist allies with the State in the meantime
		local other = Alliances.propose(state, "State", "Capitalist")
		Alliances.respond(state, other.id, true)
		local alliance, reason = Alliances.respond(state, proposal.id, true)
		Lib.eq(alliance, nil, "refused")
		Lib.eq(reason, "Capitalist already has an alliance", "reason")
		Lib.eq(#state.alliances, 1, "still one alliance")
	end)

	Lib.test("a class cannot ally with itself (8.4)", function()
		local state = fresh()
		local proposal, reason = Alliances.propose(state, "Middle", "Middle")
		Lib.eq(proposal, nil, "refused")
		Lib.eq(reason, "a class cannot ally with itself", "reason")
	end)

	Lib.test("the same pair cannot have two live proposals (8.4)", function()
		local state = fresh()
		Alliances.propose(state, "Middle", "Capitalist")
		local again, reason = Alliances.propose(state, "Middle", "Capitalist")
		Lib.eq(again, nil, "refused")
		Lib.eq(reason, "there is already a pending alliance proposal", "reason")
		local reverse = Alliances.propose(state, "Capitalist", "Middle")
		Lib.eq(reverse, nil, "the reverse direction is the same pair")
		Lib.eq(#state.allianceProposals, 1, "still one proposal")
	end)

	Lib.test("expiring proposals clears only the pending ones (8.4)", function()
		local state = fresh()
		Alliances.propose(state, "Middle", "Capitalist")
		Alliances.propose(state, "Working", "State")
		local alliance = Alliances.respond(state, state.allianceProposals[2].id, true)
		Lib.truthy(alliance ~= nil, "the Working-State alliance formed")
		Lib.eq(Alliances.expireProposals(state), 1, "only the pending one expired")
		Lib.eq(#state.allianceProposals, 0, "none left")
		Lib.eq(#state.alliances, 1, "the active alliance stays")
		Lib.eq(Alliances.expireProposals(state), 0, "idempotent")
	end)

	Lib.test("the end-of-Day step drops unanswered proposals (8.4)", function()
		local state = fresh()
		Alliances.propose(state, "Middle", "Capitalist")
		Alliances.propose(state, "Working", "State")
		local DayEndStep = Loader.require(shared.Game.Steps.DayEndStep)
		DayEndStep.new():run(state, {})
		Lib.eq(#state.allianceProposals, 0, "the Window's proposals are gone")
		Lib.eq(state.day, 2, "the Day advanced")
	end)

	Lib.test("either side may break the alliance, and the break is public (8.4)", function()
		local state = fresh()
		local proposal = Alliances.propose(state, "Middle", "Capitalist")
		Alliances.respond(state, proposal.id, true)
		local ok, reason = Alliances.breakAlliance(state, "Capitalist")
		Lib.eq(ok, true, "broken: " .. tostring(reason))
		Lib.eq(#state.alliances, 0, "no alliance left")
		Lib.eq(Alliances.allianceOf(state, "Middle"), nil, "the Middle is free")
		Lib.truthy(
			hasLog(state, "Capitalist broke the alliance with Middle"),
			"the break is public"
		)
	end)

	Lib.test("a class without an alliance cannot break one (8.4)", function()
		local state = fresh()
		local ok, reason = Alliances.breakAlliance(state, "Middle")
		Lib.eq(ok, false, "refused")
		Lib.eq(reason, "Middle has no alliance to break", "reason")
	end)

	Lib.test("a break breaks the NoBreakAlliance promises between the two (8.3)", function()
		local state = fresh()
		local promise = Promises.create(state, "Middle", "Capitalist", {
			kind = "NoBreakAlliance",
			untilDay = 5,
		})
		local proposal = Alliances.propose(state, "Middle", "Capitalist")
		Alliances.respond(state, proposal.id, true)
		Alliances.breakAlliance(state, "Middle")
		Lib.eq(promise.progress.broken, true, "the promise saw the break")
		Lib.eq(Promises.audit(state, promise, 1), "broken", "and is broken")
	end)

	Lib.test("the age counts the Days from the acceptance (8.4)", function()
		local state = fresh()
		local proposal = Alliances.propose(state, "Middle", "Capitalist")
		local alliance = Alliances.respond(state, proposal.id, true)
		Lib.eq(Alliances.age(state, alliance), 0, "age 0 on the Day it formed")
		state.day = 3
		Lib.eq(Alliances.age(state, alliance), 2, "age 2 two Days later")
	end)

	Lib.test("allied states stay serializable and deterministic (no RNG used)", function()
		local function runOnce(): any
			local state = fresh()
			local proposal = Alliances.propose(state, "Middle", "Capitalist")
			Alliances.respond(state, proposal.id, true)
			return state
		end
		local a = runOnce()
		local b = runOnce()
		Lib.eq(#assertSerializable.validate(a), 0, "state serializable")
		Lib.eq(StateHash.compute(a), StateHash.compute(b), "same input -> same result")
		Lib.eq(#a.alliances, 1, "one alliance")
	end)
end

return M
