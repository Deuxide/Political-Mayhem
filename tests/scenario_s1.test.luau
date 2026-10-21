--!nocheck
-- Scenario S1 (M2-T7; ROADMAP M2-T7): three Days with no player actions
-- resolve to the recorded expected state. The record below is the design's
-- own arithmetic (GAME_DESIGN 5.2, 5.3, 6.9): nobody works, so no wages
-- and no production, the needs eat the starting stock, and the unmet
-- needs grind Stability down by 7 the first Day and by the capped 10 on
-- every Day after. Money never moves, and the State receives nothing.
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
	print("scenario S1")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local Match = Loader.require(shared.Game.Match)

	local function newMatch(): any
		local state = StateFactory.create("Normal", SEATS, 41)
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

	Lib.test("S1: Day 1 matches the recorded state", function()
		local match = newMatch()
		local state = resolve(match)

		-- the Day counter advanced, the Window is still open
		Lib.eq(state.day, 2, "day counter advanced")
		Lib.eq(state.phase, "Window", "phase unchanged")
		-- nobody worked, so no money moved and no line produced
		Lib.eq(state.classes.Working.money, 10, "Working money")
		Lib.eq(state.classes.Middle.money, 25, "Middle money")
		Lib.eq(state.classes.Capitalist.money, 50, "Capitalist money")
		Lib.eq(state.classes.State.money, 30, "State money")
		for _, line in state.lines do
			Lib.eq(line.assigned, 0, `no one is assigned to {line.id}`)
		end
		-- the needs ate the starting stock: Working 8 Food + 4 Health needed,
		-- 4 + 1 in stock -> 4 Food and 3 Health unmet
		Lib.eq(state.classes.Working.stock.food, 0, "Working food consumed")
		Lib.eq(state.classes.Working.stock.health, 0, "Working health consumed")
		Lib.eq(state.classes.Middle.stock.food, 0, "Middle food consumed")
		Lib.eq(state.classes.Middle.stock.goods, 0, "Middle goods consumed")
		Lib.eq(state.classes.Middle.stock.education, 0, "Middle education consumed")
		Lib.eq(state.classes.Capitalist.stock.food, 0, "Capitalist food consumed")
		Lib.eq(state.classes.Capitalist.stock.goods, 0, "Capitalist goods consumed")
		-- Capitalist needs no education, so its 3 stay
		Lib.eq(state.classes.Capitalist.stock.education, 3, "Capitalist education kept")
		-- 7 unmet units -> stability 60 - 7
		Lib.eq(state.stability, 53, "stability after Day 1")
		Lib.eq(state.collapseCounter, 0, "no collapse")
		-- the Evening Report entries of Day 1
		Lib.eq(#state.eventLog, 3, "three log entries")
		Lib.truthy(hasLog(state, "Working could not cover 4 Food and 3 Health"), "unmet entry")
		Lib.truthy(hasLog(state, "Stability -7 (7 unmet need unit(s))"), "stability entry")
		Lib.truthy(hasLog(state, "Day 1 closed"), "day entry")
	end)

	Lib.test("S1: Day 2 matches the recorded state", function()
		local match = newMatch()
		resolve(match)
		local state = resolve(match)

		Lib.eq(state.day, 3, "day counter advanced")
		-- the stock is gone, so every need is unmet: Working 12, Middle 5,
		-- Capitalist 4 = 21 units -> the penalty is capped at -10
		Lib.eq(state.stability, 43, "stability after Day 2")
		Lib.eq(state.collapseCounter, 0, "no collapse")
		Lib.eq(state.classes.Working.money, 10, "Working money")
		Lib.eq(state.classes.State.money, 30, "State money")
		Lib.eq(#state.eventLog, 8, "three more entries")
		Lib.truthy(
			hasLog(state, "Working could not cover 8 Food and 4 Health"),
			"working unmet entry"
		)
		Lib.truthy(
			hasLog(state, "Middle could not cover 2 Food and 1 Goods and 1 Health and 1 Education"),
			"middle unmet entry"
		)
		Lib.truthy(
			hasLog(state, "Capitalist could not cover 1 Food and 2 Goods and 1 Health"),
			"capitalist unmet entry"
		)
		Lib.truthy(hasLog(state, "Stability -10 (21 unmet need unit(s))"), "stability entry")
		Lib.truthy(hasLog(state, "Day 2 closed"), "day entry")
	end)

	Lib.test("S1: Day 3 matches the recorded state", function()
		local match = newMatch()
		resolve(match)
		resolve(match)
		local state = resolve(match)

		Lib.eq(state.day, 4, "day counter advanced")
		Lib.eq(state.stability, 33, "stability after Day 3")
		Lib.eq(state.collapseCounter, 0, "no collapse")
		Lib.eq(state.classes.Working.money, 10, "Working money")
		Lib.eq(state.classes.Middle.money, 25, "Middle money")
		Lib.eq(state.classes.Capitalist.money, 50, "Capitalist money")
		Lib.eq(state.classes.State.money, 30, "State money")
		Lib.eq(#state.eventLog, 13, "five more entries")
		Lib.truthy(hasLog(state, "Stability -10 (21 unmet need unit(s))"), "stability entry")
		Lib.truthy(hasLog(state, "Day 3 closed"), "day entry")
	end)

	Lib.test("S1: the whole scenario is deterministic", function()
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

	Lib.test("S1: the drafts roll forward and the per-Day fields clear (9)", function()
		local match = newMatch()
		local state = match:state()
		-- a per-Day action and a sticky one
		state.drafts.Middle.build = { lineType = "Farm" }
		state.drafts.Middle.openSlots["Farm-1"] = 1
		state.drafts.Middle.market.sell["food"] = 2
		state.drafts.Working.assign["Farm-1"] = 1
		resolve(match)
		local after = match:state()
		Lib.eq(after.drafts.Middle.build, nil, "build cleared")
		Lib.eq(after.drafts.Middle.market.sell["food"], nil, "market cleared")
		Lib.eq(after.drafts.Middle.openSlots["Farm-1"], 1, "openSlots is sticky")
		Lib.eq(after.drafts.Working.assign["Farm-1"], 1, "assign is sticky")
	end)
end

return M
