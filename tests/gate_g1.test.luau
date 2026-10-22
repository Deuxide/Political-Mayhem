--!nocheck
-- Gate G1 (ROADMAP M5 "Milestone gate G1", headless engine complete): a
-- scripted match runs start to finish headlessly via Match:resolveDay with
-- fixed drafts and reaches a victory result. Command: `lune run tests/run`
-- (this suite runs every time).
--
-- The script: the Working staffs two of the Middle's farms every Day, the
-- Middle tries to build a Farm every Day and sells one Food, and nobody
-- changes a policy. On Normal the solo target is 24, so the hand-derived
-- score at the Day-12 Closing Bell is
--   Working   12  wageAtLeast every Day (4/16 staffed is below the 75% bar)
--   Middle    13  needsMet on Day 1 + moneyGainAtLeast every Day (farm sales)
--   Capitalist 12  taxCapitalistAtMost every Day
--   State     12  moneyNotDecreasing every Day (Stability is under 60 from Day 2)
-- with nobody near 24, so the final-Day comparison (11.2) picks the Middle
-- alone. Stability reaches 0 on Day 6 and stays there for the rest of the
-- match — Normal has `collapseEnabled` off (12), so the match still plays all
-- 12 Days and ends with the final comparison instead of a collapse.
--
-- Runs the real Match, pipeline, R12/R13/R14 and the PlayerViewBuilder
-- through tests/loader.luau.

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
	print("gate G1 (full headless match)")
	local shared = Loader.mount("src/shared")
	local Types = Loader.require(shared.Game.Types)
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local Match = Loader.require(shared.Game.Match)
	local PlayerViewBuilder = Loader.require(shared.Game.Behaviors.InfoModes.PlayerViewBuilder)
	local assertSerializable = Loader.require(shared.Game.State.assertSerializable)

	-- The fixed draft: the same commands every Day, whether or not the engine
	-- can carry them out that Day (an unaffordable build is skipped, logged,
	-- never an error).
	local function applyFixedDraft(state: any)
		state.drafts.Working.assign["Farm-1"] = 2
		state.drafts.Working.assign["Farm-2"] = 2
		state.drafts.Middle.build = { lineType = "Farm" }
		state.drafts.Middle.market.sell["food"] = 1
	end

	local function play(): any
		local match =
			Match.new(StateFactory.create("Normal", SEATS, 41), RuleSet.new("Normal"), Rng.new(41))
		for _ = 1, 12 do
			Lib.eq(match:state().victory, nil, "the match is still running before the Day")
			applyFixedDraft(match:state())
			match:resolveDay(match:rng())
		end
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

	Lib.test("G1: twelve scripted Days end in a final-Day victory (11.2)", function()
		local match = play()
		local state = match:state()

		Lib.eq(state.day, 12, "the last Day stays the last Day")
		Lib.eq(state.victory.kind, "final", "the final-Day comparison decides")
		Lib.eq(state.victory.day, 12, "on the last Day")
		Lib.eq(#state.victory.winners, 1, "one winner")
		Lib.eq(state.victory.winners[1], "Middle", "the Middle scored once more than the rest")

		-- the hand-derived Closing Bell score
		Lib.eq(state.classes.Middle.vp, 13, "Middle: needsMet + moneyGainAtLeast")
		Lib.eq(state.classes.Working.vp, 12, "Working: wageAtLeast")
		Lib.eq(state.classes.Capitalist.vp, 12, "Capitalist: taxCapitalistAtMost")
		Lib.eq(state.classes.State.vp, 12, "State: moneyNotDecreasing")

		Lib.truthy(
			hasLog(state, "Middle wins the final count with 13 VP on Day 12"),
			"the report line"
		)
	end)

	Lib.test("G1: the fixed drafts went through the real steps", function()
		local match =
			Match.new(StateFactory.create("Normal", SEATS, 41), RuleSet.new("Normal"), Rng.new(41))
		applyFixedDraft(match:state())
		match:resolveDay(match:rng())
		local state = match:state()
		Lib.truthy(state.lines["Farm-4"] ~= nil, "the Middle's build landed")
		Lib.truthy(state.classes.Working.money > 10, "the Working was paid wages")
		Lib.eq(state.drafts.Working.assign["Farm-1"], 2, "assign is sticky (9)")
		Lib.eq(state.drafts.Middle.build, nil, "a carried-out build is one-shot (9)")
		Lib.eq(state.drafts.Middle.market.sell["food"], nil, "a carried-out sale is one-shot (9)")
	end)

	Lib.test("G1: Normal never collapses, even with Stability at 0 (11.2, 12)", function()
		local state = play():state()
		Lib.eq(state.stability, 0, "Stability reached 0")
		Lib.truthy(state.collapseCounter >= 2, "the counter is past the limit")
		Lib.eq(state.victory.kind, "final", "yet the match ended on the final Day")
	end)

	Lib.test("G1: the finished match is plain, viewable data and cannot continue", function()
		local match = play()
		local state = match:state()
		assertSerializable.assert(state)
		for _, viewer in Types.CLASS_IDS do
			local view = PlayerViewBuilder.build(state, RuleSet.new("Normal"), viewer)
			assertSerializable.assert(view)
			Lib.eq(view.viewer, viewer, "every class gets a view")
			Lib.eq(view.victory.kind, "final", "the result travels")
		end

		local ok, err = pcall(function()
			match:resolveDay(match:rng())
		end)
		Lib.eq(ok, false, "an ended match cannot be resolved again")
		Lib.contains(tostring(err), "the match has ended")
	end)

	Lib.test("G1: the whole gate is deterministic", function()
		local a = play():state()
		local b = play():state()
		Lib.eq(StateHash.compute(a), StateHash.compute(b), "same input -> same state")
		Lib.eq(a.victory.kind, b.victory.kind, "same victory kind")
		Lib.eq(a.victory.winners[1], b.victory.winners[1], "same winner")
	end)
end

return M
