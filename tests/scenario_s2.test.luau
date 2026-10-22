--!nocheck
-- Scenario S2 (M3-T5; ROADMAP M3-T5): three Days with a strike. Working
-- strikes the Capitalist and staffs both the Middle's farm and the
-- Capitalist's factory; the struck line produces nothing and pays no
-- wage, while the untouched farm works normally. The record below is the
-- design's own arithmetic (GAME_DESIGN 5.2, 5.3, 6.4, 6.5, 6.9, 7.1).
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
	print("scenario S2 (strike)")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local Match = Loader.require(shared.Game.Match)

	local function newMatch(): any
		local state = StateFactory.create("Normal", SEATS, 41)
		-- the strike is sticky, and so are the assignments
		state.drafts.Working.strike = { target = "Capitalist" }
		state.drafts.Working.assign["Farm-1"] = 2 -- Middle's farm
		state.drafts.Working.assign["Factory-1"] = 2 -- Capitalist's factory
		return Match.new(state, RuleSet.new("Normal"), Rng.new(41))
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

	Lib.test("S2: Day 1 matches the recorded state", function()
		local match = newMatch()
		local state = resolve(match)

		Lib.eq(state.day, 2, "day counter advanced")
		-- the Middle's farm works: 2 slots at the wage of 2 = 4 Money, and
		-- 2 slots x 2 Food = 4 Food
		Lib.eq(state.classes.Middle.money, 21, "25 - 4 wages")
		Lib.eq(state.classes.Middle.stock.food, 4, "6 produced and eaten, 4 left")
		-- the struck factory is idle: no wages, no output
		Lib.eq(state.classes.Capitalist.money, 50, "no wages for the struck line")
		Lib.eq(state.classes.Capitalist.stock.goods, 0, "no output, the 2 Goods eaten")
		-- the Working gets the farm's wages only
		Lib.eq(state.classes.Working.money, 14, "10 + 4 wages")
		Lib.eq(state.classes.State.money, 30, "no tax")
		-- 7 unmet units (Working 4 Food + 3 Health) -> stability 60 - 7
		Lib.eq(state.stability, 53, "stability after Day 1")
		Lib.eq(state.classes.Working.influence, 6, "Working influence")
		Lib.eq(state.classes.Capitalist.influence, 2, "Capitalist influence")
		Lib.truthy(
			hasLog(state, "Working's strike idles Capitalist: 1 staffed line(s)"),
			"strike entry"
		)
		Lib.truthy(hasLog(state, "Middle Farm-1 produced 4 Food"), "production entry")
		Lib.truthy(hasLog(state, "Middle paid 4 Money in wages for 2 slot(s)"), "wage entry")
		Lib.truthy(not hasLog(state, "Factory-1 produced"), "the struck line produced nothing")
		Lib.eq(#state.eventLog, 15, "fifteen log entries")
	end)

	Lib.test("S2: Day 2 matches the recorded state", function()
		local match = newMatch()
		resolve(match)
		local state = resolve(match)

		Lib.eq(state.day, 3, "day counter advanced")
		Lib.eq(state.classes.Middle.money, 17, "21 - 4 wages")
		Lib.eq(state.classes.Middle.stock.food, 6, "4 + 4 produced, 2 eaten")
		Lib.eq(state.classes.Working.money, 18, "14 + 4 wages")
		Lib.eq(state.classes.Capitalist.money, 50, "still no wages")
		-- 19 unmet units -> the penalty is capped at -10
		Lib.eq(state.stability, 43, "stability after Day 2")
		Lib.eq(state.classes.Working.influence, 9, "Working influence")
		Lib.eq(#state.eventLog, 31, "sixteen more entries")
		Lib.truthy(
			hasLog(state, "Middle could not cover 1 Goods and 1 Health and 1 Education"),
			"middle unmet entry (its Food is covered by its own production)"
		)
	end)

	Lib.test("S2: Day 3 matches the recorded state", function()
		local match = newMatch()
		resolve(match)
		resolve(match)
		local state = resolve(match)

		Lib.eq(state.day, 4, "day counter advanced")
		Lib.eq(state.classes.Middle.money, 13, "17 - 4 wages")
		Lib.eq(state.classes.Middle.stock.food, 8, "6 + 4 produced, 2 eaten")
		Lib.eq(state.classes.Working.money, 22, "18 + 4 wages")
		Lib.eq(state.classes.Capitalist.money, 50, "still no wages")
		Lib.eq(state.stability, 33, "stability after Day 3")
		Lib.eq(#state.eventLog, 47, "sixteen more entries")
	end)

	Lib.test("S2: the whole scenario is deterministic", function()
		local function runScenario(): any
			local match = newMatch()
			resolve(match)
			resolve(match)
			return resolve(match)
		end
		local a = runScenario()
		local b = runScenario()
		Lib.eq(StateHash.compute(a), StateHash.compute(b), "same input -> same state")
		Lib.eq(a.stability, 33, "same stability")
		Lib.eq(a.day, 4, "same day")
	end)
end

return M
