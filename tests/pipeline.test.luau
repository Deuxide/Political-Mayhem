--!nocheck
-- ResolutionPipeline tests (M2-T7; GAME_DESIGN section 10): the steps run in
-- the section 10 order, the Day resolves on a working copy of the state
-- (the previous state object is never mutated in place), and the steps that
-- later milestones own do nothing yet. Runs the real Match, pipeline, and
-- steps through tests/loader.luau.

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
	print("resolution pipeline")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local Match = Loader.require(shared.Game.Match)

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

	Lib.test("the market income is taxed in the same Day (R6 before R7)", function()
		local match = newMatch()
		local state = match:state()
		state.policies.TaxMiddle = 3 -- 30%
		state.drafts.Middle.market.sell["food"] = 2 -- Middle has 2 Food
		match:resolveDay(match:rng())
		local after = match:state()
		-- sold for 4, taxed at 30% -> 1 to the State
		Lib.eq(after.classes.Middle.money, 28, "25 + 4 - 1")
		Lib.eq(after.classes.State.money, 31, "State received the tax")
		Lib.truthy(hasLog(after, "Middle sold 2 Food for 4 Money"), "sell entry")
		Lib.truthy(hasLog(after, "Middle paid 1 Money tax (30%)"), "tax entry")
	end)

	Lib.test("the Day resolves on a copy: the old state object is untouched", function()
		local match = newMatch()
		local before = match:state()
		local after = match:resolveDay(match:rng())
		Lib.eq(before.day, 1, "the old state object still says day 1")
		Lib.eq(before.stability, 60, "the old state object still has the old stability")
		Lib.eq(after.day, 2, "the resolved state advanced the Day")
		Lib.truthy(match:state() == after, "the live state is the resolved copy")
	end)

	Lib.test("R1 validates the drafts before the economy steps use them", function()
		local match = newMatch()
		local state = match:state()
		state.drafts.Capitalist.build = { lineType = "Spaceship" }
		match:resolveDay(match:rng())
		local after = match:state()
		-- R1 dropped the field, so the Build step never saw it
		Lib.truthy(
			hasLog(after, "Capitalist build dropped: unknown line type Spaceship"),
			"the lock entry, not the build entry"
		)
		local lines = 0
		for _ in after.lines do
			lines += 1
		end
		Lib.eq(lines, 10, "no line was queued")
	end)

	Lib.test("the steps later milestones own change nothing yet", function()
		local match = newMatch()
		match:resolveDay(match:rng())
		local state = match:state()
		-- no Influence income yet (R10 is a stub), no VP (R12), no victory
		Lib.eq(state.classes.Working.influence, 3, "Working influence untouched")
		Lib.eq(state.classes.Middle.influence, 2, "Middle influence untouched")
		Lib.eq(state.classes.Capitalist.influence, 1, "Capitalist influence untouched")
		Lib.eq(state.classes.State.influence, 2, "State influence untouched")
	end)
end

return M
