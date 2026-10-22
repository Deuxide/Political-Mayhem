--!nocheck
-- Scenario S5 (M5-T5; ROADMAP M5-T5): an alliance formed through the real
-- operations wins together. The shared-victory bar (11.2): both classes'
-- conditions met, the alliance at least three Days old, combined VP at
-- ceil(24 x 1.5) = 36 with each member at ceil(24 x 0.4) = 10.
--
-- The two VP totals at the start are the fixture (a natural 36-VP race takes
-- more Days than a scenario should script); the alliance, the Day loop, the
-- scoring that keeps adding VP, and the victory decision are all real code.
--
-- Runs the real Match, pipeline, Alliances and R12/R13 through
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
	print("scenario S5 (shared victory)")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local Match = Loader.require(shared.Game.Match)
	local Alliances = Loader.require(shared.Game.Ops.Alliances)

	local function newMatch(): any
		return Match.new(
			StateFactory.create("Normal", SEATS, 41),
			RuleSet.new("Normal"),
			Rng.new(41)
		)
	end

	-- Middle and Capitalist ally on Day 1 through the real proposal and
	-- acceptance, and start the match near the shared-victory bar.
	local function alliedMatch(): any
		local match = newMatch()
		local state = match:state()
		local proposal, reason = Alliances.propose(state, "Middle", "Capitalist")
		Lib.truthy(proposal ~= nil, "the proposal was made: " .. tostring(reason))
		local alliance, acceptReason = Alliances.respond(state, proposal.id, true)
		Lib.truthy(alliance ~= nil, "the alliance formed: " .. tostring(acceptReason))
		state.classes.Middle.vp = 18
		state.classes.Capitalist.vp = 17
		return match
	end

	local function hasLog(state: any, needle: string): boolean
		for _, entry in state.eventLog do
			if string.find(entry.text, needle, 1, true) ~= nil then
				return true
			end
		end
		return false
	end

	Lib.test("S5: Day 1 — the alliance is formed and is too young to win (11.2)", function()
		local match = alliedMatch()
		local state = match:state()
		Lib.eq(#state.alliances, 1, "one alliance")
		Lib.eq(state.alliances[1].formedOnDay, 1, "accepted on Day 1")
		Lib.eq(state.alliances[1].members[1], "Middle", "proposer")
		Lib.eq(state.alliances[1].members[2], "Capitalist", "accepter")
		Lib.truthy(
			hasLog(state, "Middle and Capitalist formed an alliance"),
			"the alliance is public (8.4)"
		)

		match:resolveDay(match:rng())
		local after = match:state()
		Lib.eq(after.day, 2, "day counter advanced")
		Lib.eq(after.victory, nil, "no victory at age 0")
		-- R12 kept scoring: the Middle covers its needs on Day 1, the
		-- Capitalist pays one for the tax track, the Working the wage, the
		-- State its wallet and Stability 60
		Lib.eq(after.classes.Middle.vp, 19, "Middle: needsMet")
		Lib.eq(after.classes.Capitalist.vp, 18, "Capitalist: taxCapitalistAtMost")
		Lib.eq(after.classes.Working.vp, 1, "Working: wageAtLeast")
		Lib.eq(after.classes.State.vp, 1, "State: moneyNotDecreasing (53 Stability is below 60)")
	end)

	Lib.test("S5: Day 3 — the combined bar is met, the three-Day age is not (11.2)", function()
		local match = alliedMatch()
		match:resolveDay(match:rng())
		match:resolveDay(match:rng())
		match:resolveDay(match:rng())
		local state = match:state()

		Lib.eq(state.day, 4, "three Days resolved")
		Lib.eq(state.victory, nil, "still no victory")
		Lib.eq(state.classes.Middle.vp, 19, "Middle stopped scoring after Day 1")
		Lib.eq(state.classes.Capitalist.vp, 20, "Capitalist scored every Day")
		Lib.eq(state.classes.Middle.vp + state.classes.Capitalist.vp, 39, "combined past 36")
		-- the third Day just resolved: the age it was checked at was 3 - 1
		Lib.eq(state.day - 1 - state.alliances[1].formedOnDay, 2, "the age is the missing bar")
	end)

	Lib.test("S5: Day 4 — the alliance wins together and the match ends (11.2)", function()
		local match = alliedMatch()
		for _ = 1, 3 do
			match:resolveDay(match:rng())
		end
		Lib.eq(match:state().victory, nil, "no victory before the fourth Day")

		match:resolveDay(match:rng())
		local state = match:state()
		Lib.eq(state.day, 4, "the last Day stays the last Day")
		Lib.eq(state.victory.kind, "shared", "shared victory")
		Lib.eq(#state.victory.winners, 2, "both classes")
		Lib.eq(state.victory.winners[1], "Middle", "recorded in acceptance order")
		Lib.eq(state.victory.winners[2], "Capitalist", "recorded in acceptance order")
		Lib.eq(state.victory.day, 4, "the Day it happened")
		Lib.eq(
			state.classes.Middle.vp + state.classes.Capitalist.vp,
			40,
			"19 + 21 at the Closing Bell"
		)
		Lib.truthy(
			hasLog(state, "Middle and Capitalist win together with 40 VP on Day 4"),
			"the report names both and the combined VP"
		)

		local ok, err = pcall(function()
			match:resolveDay(match:rng())
		end)
		Lib.eq(ok, false, "an ended match cannot be resolved again")
		Lib.contains(tostring(err), "the match has ended")
	end)

	Lib.test("S5: the whole scenario is deterministic", function()
		local function runScenario(): any
			local match = alliedMatch()
			for _ = 1, 4 do
				match:resolveDay(match:rng())
			end
			return match:state()
		end
		local a = runScenario()
		local b = runScenario()
		Lib.eq(StateHash.compute(a), StateHash.compute(b), "same input -> same state")
		Lib.eq(a.victory.kind, "shared", "same victory")
		Lib.eq(a.victory.day, 4, "same Day")
	end)
end

return M
