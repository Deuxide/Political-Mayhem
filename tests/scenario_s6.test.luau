--!nocheck
-- Scenario S6 (M5-T5; ROADMAP M5-T5): on Hard, with nobody acting, Stability
-- slides to 0 and stays there; two consecutive Days at 0 end the match with
-- no winner (11.2, 12). Every number below is the design's arithmetic applied
-- to the factory state (5.3, 6.9): Stability starts at 60, the unmet-needs
-- penalty is capped at -10 per Day, and Day 1 takes 7 units of Working needs
-- (4 food + 3 health) because nobody staffs or sells anything.
--
-- Hard is the first difficulty with `collapseEnabled` (12) and runs 14
-- rounds, so the final-Day comparison cannot pre-empt the collapse.
--
-- Runs the real Match, pipeline, R9 (Upkeep) and R13 (VictoryCheck) through
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
	print("scenario S6 (collapse)")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local Match = Loader.require(shared.Game.Match)

	local function newMatch(): any
		return Match.new(StateFactory.create("Hard", SEATS, 41), RuleSet.new("Hard"), Rng.new(41))
	end

	local function hasLog(state: any, needle: string): boolean
		for _, entry in state.eventLog do
			if string.find(entry.text, needle, 1, true) ~= nil then
				return true
			end
		end
		return false
	end

	Lib.test("S6: Stability falls to 0 on Day 7 and the counter starts (6.9, 11.2)", function()
		local match = newMatch()
		-- 53 = 60 - 7 unmet, then the -10 cap every Day after
		local expected = { 53, 43, 33, 23, 13, 3, 0 }
		for day = 1, 7 do
			match:resolveDay(match:rng())
			local state = match:state()
			Lib.eq(state.stability, expected[day], `Day {day} Stability`)
			Lib.eq(state.collapseCounter, if day < 7 then 0 else 1, `Day {day} collapse counter`)
			Lib.eq(state.victory, nil, `Day {day}: one Day at 0 is not a collapse`)
			Lib.eq(state.day, day + 1, `Day {day}: the match goes on`)
		end
	end)

	Lib.test("S6: the second Day at 0 collapses the world with no winner (11.2)", function()
		local match = newMatch()
		for _ = 1, 7 do
			match:resolveDay(match:rng())
		end
		match:resolveDay(match:rng())

		local state = match:state()
		Lib.eq(state.stability, 0, "Stability stays 0")
		Lib.eq(state.collapseCounter, 2, "two consecutive Days at 0")
		Lib.eq(state.day, 8, "the last Day stays the last Day")
		Lib.eq(state.victory.kind, "collapse", "collapse")
		Lib.eq(#state.victory.winners, 0, "no winner")
		Lib.eq(state.victory.day, 8, "the Day it happened")
		Lib.truthy(hasLog(state, "The world collapsed on Day 8 — no winner"), "the report line")

		local ok, err = pcall(function()
			match:resolveDay(match:rng())
		end)
		Lib.eq(ok, false, "an ended match cannot be resolved again")
		Lib.contains(tostring(err), "the match has ended")
	end)

	Lib.test("S6: the whole scenario is deterministic", function()
		local function runScenario(): any
			local match = newMatch()
			for _ = 1, 8 do
				match:resolveDay(match:rng())
			end
			return match:state()
		end
		local a = runScenario()
		local b = runScenario()
		Lib.eq(StateHash.compute(a), StateHash.compute(b), "same input -> same state")
		Lib.eq(a.victory.kind, "collapse", "same ending")
	end)
end

return M
