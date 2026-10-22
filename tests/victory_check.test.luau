--!nocheck
-- VictoryCheck tests (M5-T2; GAME_DESIGN 11.2, R13): solo, shared, the final
-- Day comparison, collapse, and every tie-break. Runs the real step and the
-- real Match through tests/loader.luau; states at a given Day are fixtures,
-- the rules under test are not.
--
-- One branch has no test on purpose: with the shipped numbers the shared
-- per-member bar (ceil(t x 0.4)) cannot bind unless the other member is past
-- the solo bar, and a solo victory wins first — 1.5 - 0.4 > 1. The code keeps
-- the check because §11.2 states it and the numbers are tunable.

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
	print("victory check")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local Match = Loader.require(shared.Game.Match)
	local VictoryCheck = Loader.require(shared.Game.Steps.VictoryCheck)

	local function stateAt(difficulty: string, day: number): any
		local state = StateFactory.create(difficulty, SEATS, 41)
		state.day = day
		return state
	end

	local function makeCtx(difficulty: string): any
		return {
			rng = Rng.new(41),
			ruleSet = RuleSet.new(difficulty),
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

	local function run(state: any, difficulty: string): any
		VictoryCheck.new():run(state, makeCtx(difficulty or state.difficulty))
		return state
	end

	local function ally(state: any, a: string, b: string, formedOnDay: number)
		table.insert(state.alliances, {
			id = `Alliance-{#state.alliances + 1}`,
			members = { a, b },
			formedOnDay = formedOnDay,
		})
	end

	local function lastLog(state: any): string?
		if #state.eventLog == 0 then
			return nil
		end
		return state.eventLog[#state.eventLog].text
	end

	Lib.test("solo: a class at the target wins (11.2)", function()
		local state = stateAt("Normal", 5)
		state.classes.Working.vp = 24
		run(state, "Normal")
		Lib.eq(state.victory.kind, "solo", "kind")
		Lib.eq(#state.victory.winners, 1, "one winner")
		Lib.eq(state.victory.winners[1], "Working", "the class at the target")
		Lib.eq(state.victory.day, 5, "the Day it happened")
		Lib.eq(lastLog(state), "Working wins solo with 24 VP on Day 5", "the report line")
	end)

	Lib.test("solo: below the target nobody wins (11.2)", function()
		local state = stateAt("Normal", 5)
		state.classes.Working.vp = 23
		run(state, "Normal")
		Lib.eq(state.victory, nil, "no result")
	end)

	Lib.test(
		"solo: ties go to the higher VP, then the higher Money, then CLASS_IDS (11.2)",
		function()
			-- more VP beats less VP, whatever the wallets
			local vp = stateAt("Normal", 5)
			vp.classes.Working.vp = 26
			vp.classes.Capitalist.vp = 25
			run(vp, "Normal")
			Lib.eq(vp.victory.winners[1], "Working", "higher VP wins")

			-- equal VP: the richer wallet
			local money = stateAt("Normal", 5)
			money.classes.Working.vp = 24
			money.classes.Capitalist.vp = 24
			run(money, "Normal")
			Lib.eq(money.victory.winners[1], "Capitalist", "equal VP, richer wallet")

			-- equal VP and money: the earlier class in CLASS_IDS order
			local order = stateAt("Normal", 5)
			order.classes.Working.vp = 24
			order.classes.Middle.vp = 24
			order.classes.Middle.money = order.classes.Working.money
			run(order, "Normal")
			Lib.eq(order.victory.winners[1], "Working", "the deterministic fallback")
		end
	)

	Lib.test("shared: an alliance of age 3 with 36 combined and 10 each wins (11.2)", function()
		local state = stateAt("Normal", 5)
		state.classes.Middle.vp = 18
		state.classes.Capitalist.vp = 18
		ally(state, "Middle", "Capitalist", 2) -- age 3 on Day 5
		run(state, "Normal")
		Lib.eq(state.victory.kind, "shared", "kind")
		Lib.eq(#state.victory.winners, 2, "both classes")
		Lib.eq(state.victory.winners[1], "Middle", "first member")
		Lib.eq(state.victory.winners[2], "Capitalist", "second member")
		Lib.eq(
			lastLog(state),
			"Middle and Capitalist win together with 36 VP on Day 5",
			"the report line"
		)
	end)

	Lib.test("shared: a younger alliance does not win (11.2)", function()
		local state = stateAt("Normal", 5)
		state.classes.Middle.vp = 18
		state.classes.Capitalist.vp = 18
		ally(state, "Middle", "Capitalist", 3) -- age 2
		run(state, "Normal")
		Lib.eq(state.victory, nil, "no result yet")
	end)

	Lib.test("shared: the combined minimum is real (11.2)", function()
		local state = stateAt("Normal", 5)
		state.classes.Middle.vp = 10
		state.classes.Capitalist.vp = 20 -- 30 < ceil(24 x 1.5) = 36
		ally(state, "Middle", "Capitalist", 2)
		run(state, "Normal")
		Lib.eq(state.victory, nil, "each is past its bar, the combined is not")
	end)

	Lib.test("final Day: an alliance compares at 70 percent, any age (11.2)", function()
		local state = stateAt("Normal", 12)
		state.classes.Working.vp = 20
		state.classes.Middle.vp = 15
		state.classes.Capitalist.vp = 15
		ally(state, "Middle", "Capitalist", 12) -- age 0: the final Day has no age bar
		run(state, "Normal")
		Lib.eq(state.victory.kind, "final", "kind")
		Lib.eq(state.victory.winners[1], "Middle", "alliance member")
		Lib.eq(state.victory.winners[2], "Capitalist", "alliance member")
		Lib.eq(
			lastLog(state),
			"Middle and Capitalist win the final count with 21 VP on Day 12",
			"floor(30 x 0.7) = 21 beats 20"
		)
	end)

	Lib.test("final Day: a class can beat every alliance (11.2)", function()
		local state = stateAt("Normal", 12)
		state.classes.Working.vp = 23
		state.classes.Middle.vp = 5
		state.classes.Capitalist.vp = 5
		ally(state, "Middle", "Capitalist", 1)
		run(state, "Normal")
		Lib.eq(state.victory.kind, "final", "kind")
		Lib.eq(#state.victory.winners, 1, "one winner")
		Lib.eq(state.victory.winners[1], "Working", "the class above the alliance")
	end)

	Lib.test("final Day: ties go to the higher combined Money (11.2)", function()
		local state = stateAt("Normal", 12)
		state.classes.Capitalist.vp = 21 -- money 50
		state.classes.Working.vp = 15 -- money 10
		state.classes.Middle.vp = 15 -- money 25
		ally(state, "Working", "Middle", 12) -- floor(30 x 0.7) = 21, combined money 35
		run(state, "Normal")
		Lib.eq(state.victory.kind, "final", "kind")
		Lib.eq(state.victory.winners[1], "Capitalist", "50 beats 35")
	end)

	Lib.test("collapse: two Days at stability 0 end it with no winner on Hard (11.2)", function()
		local hard = stateAt("Hard", 5)
		hard.collapseCounter = 2
		run(hard, "Hard")
		Lib.eq(hard.victory.kind, "collapse", "kind")
		Lib.eq(#hard.victory.winners, 0, "no winner")
		Lib.eq(hard.victory.day, 5, "the Day it happened")
		Lib.eq(lastLog(hard), "The world collapsed on Day 5 — no winner", "the report line")
	end)

	Lib.test("collapse: a difficulty without collapse plays on (12)", function()
		local normal = stateAt("Normal", 5)
		normal.collapseCounter = 2
		run(normal, "Normal")
		Lib.eq(normal.victory, nil, "Normal does not collapse")
	end)

	Lib.test("an ended match is left alone (11.2)", function()
		local state = stateAt("Normal", 5)
		state.victory = { kind = "solo", winners = { "State" }, day = 4 }
		local logs = #state.eventLog
		run(state, "Normal")
		Lib.eq(state.victory.day, 4, "the result is not recomputed")
		Lib.eq(#state.eventLog, logs, "and not logged twice")
	end)

	Lib.test("the match refuses to resolve past its end (D-070)", function()
		local match = Match.new(stateAt("Normal", 5), RuleSet.new("Normal"), Rng.new(41))
		match:state().victory = { kind = "collapse", winners = {}, day = 5 }
		local ok, err = pcall(function()
			match:resolveDay(match:rng())
		end)
		Lib.eq(ok, false, "resolveDay raises")
		Lib.contains(tostring(err), "the match has ended", "with the reason")
	end)

	Lib.test("the last Day's resolution ends the match and keeps the Day (11.2, D-070)", function()
		local match =
			Match.new(StateFactory.create("Normal", SEATS, 41), RuleSet.new("Normal"), Rng.new(41))
		match:state().day = 12
		local state = match:resolveDay(match:rng())
		-- the Day's scoring: 1 VP each, so the final comparison ties on VP and
		-- the Capitalist's larger wallet decides
		Lib.eq(state.victory.kind, "final", "kind")
		Lib.eq(state.victory.winners[1], "Capitalist", "the richer class")
		Lib.eq(state.victory.day, 12, "the last Day")
		Lib.eq(state.day, 12, "R14 does not advance past the end")
	end)
end

return M
