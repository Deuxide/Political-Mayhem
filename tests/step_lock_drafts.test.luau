--!nocheck
-- LockDraftsStep tests (M2-T7; GAME_DESIGN section 9, R1): invalid draft
-- fields are dropped with a log entry, valid ones survive, and the fields
-- that section 9 calls "ignored" (an assignment above the open slots, a
-- build the class may not make) are left for the steps that own them.
-- Runs the real step on real factory states via tests/loader.luau.

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
	print("lock drafts step")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local LockDraftsStep = Loader.require(shared.Game.Steps.LockDraftsStep)

	local function fresh(): any
		return StateFactory.create("Normal", SEATS, 41)
	end

	local function makeCtx(): any
		return {
			rng = Rng.new(41),
			ruleSet = RuleSet.new("Normal"),
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

	local function lock(state: any): any
		LockDraftsStep.new():run(state, makeCtx())
		return state
	end

	local function hasLog(state: any, needle: string): boolean
		for _, entry in state.eventLog do
			if string.find(entry.text, needle, 1, true) ~= nil then
				return true
			end
		end
		return false
	end

	Lib.test("openSlots for an unknown or foreign line are dropped (9)", function()
		local state = fresh()
		state.drafts.Middle.openSlots["Farm-99"] = 1 -- unknown line
		state.drafts.Middle.openSlots["Factory-1"] = 1 -- Capitalist's line
		lock(state)
		Lib.eq(state.drafts.Middle.openSlots["Farm-99"], nil, "unknown line dropped")
		Lib.eq(state.drafts.Middle.openSlots["Factory-1"], nil, "foreign line dropped")
		Lib.truthy(hasLog(state, "Middle openSlots dropped: unknown line Farm-99"), "log 1")
		Lib.truthy(
			hasLog(state, "Middle openSlots dropped: Factory-1 is not Middle's line"),
			"log 2"
		)
	end)

	Lib.test("an out-of-range openSlots value is dropped (6.2)", function()
		local state = fresh()
		state.drafts.Middle.openSlots["Farm-1"] = 5 -- the line has 2 slots
		lock(state)
		Lib.eq(state.drafts.Middle.openSlots["Farm-1"], nil, "dropped")
		Lib.truthy(hasLog(state, "Middle openSlots dropped: Farm-1 value 5 is out of range"), "log")
	end)

	Lib.test("a valid openSlots value survives and reaches the line (9)", function()
		local state = fresh()
		state.drafts.Middle.openSlots["Farm-1"] = 1
		lock(state)
		Lib.eq(state.drafts.Middle.openSlots["Farm-1"], 1, "kept")
		Lib.eq(state.lines["Farm-1"].openSlots, 1, "the line now accepts one worker")
		Lib.eq(#state.eventLog, 0, "no logs")
	end)

	Lib.test("only Working assigns, and only to lines that exist (9)", function()
		local state = fresh()
		state.drafts.Middle.assign["Farm-1"] = 1 -- not Working's field
		state.drafts.Working.assign["Farm-99"] = 1 -- unknown line
		state.drafts.Working.assign["Farm-1"] = 2 -- valid
		lock(state)
		Lib.eq(state.drafts.Middle.assign["Farm-1"], nil, "Middle's assign dropped")
		Lib.eq(state.drafts.Working.assign["Farm-99"], nil, "unknown line dropped")
		Lib.eq(state.drafts.Working.assign["Farm-1"], 2, "valid assign kept")
		Lib.truthy(hasLog(state, "Middle assign dropped: only Working assigns workers"), "log 1")
		Lib.truthy(hasLog(state, "Working assign dropped: unknown line Farm-99"), "log 2")
	end)

	Lib.test("an assignment above the open slots is kept, not dropped (6.3)", function()
		local state = fresh()
		state.drafts.Working.assign["Farm-1"] = 9 -- ignored at Production, valid here
		lock(state)
		Lib.eq(state.drafts.Working.assign["Farm-1"], 9, "kept for Production to ignore")
		Lib.eq(#state.eventLog, 0, "no logs")
	end)

	Lib.test("only Working strikes, and never itself (6.5, 9)", function()
		local state = fresh()
		state.drafts.Middle.strike = { target = "Capitalist" } -- not Working's field
		state.drafts.Working.strike = { target = "Working" } -- invalid target
		lock(state)
		Lib.eq(state.drafts.Middle.strike, nil, "Middle's strike dropped")
		Lib.eq(state.drafts.Working.strike, nil, "self-strike dropped")
		Lib.truthy(hasLog(state, "Middle strike dropped: only Working strikes"), "log 1")
		Lib.truthy(hasLog(state, "Working strike dropped: Working is not a valid target"), "log 2")
	end)

	Lib.test("a valid strike survives (6.5)", function()
		local state = fresh()
		state.drafts.Working.strike = { target = "Capitalist" }
		lock(state)
		Lib.eq(state.drafts.Working.strike.target, "Capitalist", "kept")
		Lib.eq(#state.eventLog, 0, "no logs")
	end)

	Lib.test("an unknown build line type is dropped (6.2)", function()
		local state = fresh()
		state.drafts.Capitalist.build = { lineType = "Spaceship" }
		lock(state)
		Lib.eq(state.drafts.Capitalist.build, nil, "dropped")
		Lib.truthy(hasLog(state, "Capitalist build dropped: unknown line type Spaceship"), "log")
	end)

	Lib.test("a build the class may not make is left to R4 (6.2)", function()
		local state = fresh()
		state.drafts.Middle.build = { lineType = "Factory" } -- R4 skips it
		lock(state)
		Lib.eq(state.drafts.Middle.build.lineType, "Factory", "kept for R4")
		Lib.eq(#state.eventLog, 0, "no logs")
	end)

	Lib.test("market entries must name a real resource and a whole volume (6.6)", function()
		local state = fresh()
		state.drafts.Middle.market.sell["unobtainium"] = 2 -- unknown resource
		state.drafts.Middle.market.sell["food"] = -1 -- negative volume
		state.drafts.Middle.market.sell["goods"] = 3 -- valid
		lock(state)
		Lib.eq(state.drafts.Middle.market.sell["unobtainium"], nil, "unknown resource dropped")
		Lib.eq(state.drafts.Middle.market.sell["food"], nil, "negative volume dropped")
		Lib.eq(state.drafts.Middle.market.sell["goods"], 3, "valid entry kept")
		Lib.truthy(
			hasLog(state, "Middle market sell dropped: unknown resource unobtainium"),
			"log 1"
		)
		Lib.truthy(
			hasLog(state, "Middle market sell dropped: food volume -1 is not a whole number"),
			"log 2"
		)
	end)

	Lib.test("votes for bills that are not on the table are dropped (7.3)", function()
		local state = fresh()
		state.drafts.Middle.votes["Bill-1"] = { side = "yes", influence = 2 }
		lock(state)
		Lib.eq(state.drafts.Middle.votes["Bill-1"], nil, "dropped")
		Lib.truthy(hasLog(state, "Middle vote dropped: unknown bill Bill-1"), "log")
	end)
end

return M
