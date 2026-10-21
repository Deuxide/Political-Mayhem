--!nocheck
-- BuildStep tests (M2-T1; GAME_DESIGN 6.2, section 10 R4): an affordable
-- build pays and queues a line with slotsMax slots and builtOnDay = today
-- (active the next Day), unaffordable or forbidden builds are skipped with a
-- log entry, ids continue the per-type counter, and a no-build draft changes
-- nothing. Runs the real step on real factory states via tests/loader.luau.

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
	print("build step")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateOps = Loader.require(shared.Game.State.StateOps)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local assertSerializable = Loader.require(shared.Game.State.assertSerializable)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local BuildStep = Loader.require(shared.Game.Steps.BuildStep)

	-- fresh Normal state on day 1; ctx carries real rng + ruleSet even though
	-- the Build step itself needs neither (part of the Step contract)
	local function fresh(): any
		return StateFactory.create("Normal", SEATS, 77)
	end

	local function makeCtx(): any
		return { rng = Rng.new(77), ruleSet = RuleSet.new("Normal") }
	end

	local function runStep(state: any, classId: string, lineType: string?): any
		if lineType ~= nil then
			state.drafts[classId].build = { lineType = lineType }
		end
		BuildStep.new():run(state, makeCtx())
		return state
	end

	local function lineCount(state: any): number
		local n = 0
		for _ in state.lines do
			n += 1
		end
		return n
	end

	local function lastLog(state: any): any
		return state.eventLog[#state.eventLog]
	end

	Lib.test("affordable build queues the line, pays, and logs (6.2/R4)", function()
		local state = runStep(fresh(), "Middle", "Farm")
		-- 25 - 12 (Config/Lines Farm buildCost)
		Lib.eq(state.classes.Middle.money, 13, "Middle money after build")
		Lib.eq(lineCount(state), 11, "one line added")
		-- initial farms are Farm-1/Farm-2 (Middle) and Farm-3 (Capitalist):
		-- the per-type counter continues, D-040
		local farm = state.lines["Farm-4"]
		Lib.truthy(farm ~= nil, "Farm-4 exists")
		Lib.eq(farm.owner, "Middle", "farm owner")
		Lib.eq(farm.type, "Farm", "farm type")
		-- new lines open at slotsMax (2, Config/Lines) — see BuildStep comment
		Lib.eq(farm.openSlots, 2, "farm openSlots")
		Lib.eq(farm.assigned, 0, "farm assigned")
		Lib.eq(farm.builtOnDay, state.day, "builtOnDay is recorded today")
		local log = lastLog(state)
		Lib.contains(log.text, "Middle built Farm-4 for 12 Money", "build log")
		Lib.eq(log.day, 1, "log day")
		Lib.eq(log.actor, "Middle", "log actor")
	end)

	Lib.test("unaffordable build is skipped with a log and no state change", function()
		local state = fresh()
		state.classes.Capitalist.money = 5 -- below the 20 Factory cost (fixture)
		-- set the unaffordable draft BEFORE hashing, so only the step's
		-- outcome (the event-log entry) can differ afterwards
		state.drafts.Capitalist.build = { lineType = "Factory" }
		local before = StateHash.compute(state)

		BuildStep.new():run(state, makeCtx())

		Lib.eq(state.classes.Capitalist.money, 5, "money untouched")
		Lib.eq(lineCount(state), 10, "no line added")
		local log = lastLog(state)
		Lib.contains(log.text, "Capitalist build skipped", "skip log present")
		Lib.contains(log.text, "cannot afford Factory", "afford reason")
		Lib.eq(log.actor, "Capitalist", "skip log actor")
		Lib.eq(log.day, 1, "skip log day")
		-- prove ONLY the event log changed: pop the entry, clear the log, and
		-- the rest must hash identical to before
		local skipLog = lastLog(state)
		state.eventLog = {}
		Lib.eq(StateHash.compute(state), before, "everything but eventLog unchanged")
		table.insert(state.eventLog, skipLog)
		Lib.eq(#state.eventLog, 1, "exactly one log entry")
	end)

	Lib.test("forbidden line type is skipped with a log (6.2 canBuild)", function()
		local state = runStep(fresh(), "Middle", "Factory") -- Middle may not
		Lib.eq(state.classes.Middle.money, 25, "money untouched")
		Lib.eq(lineCount(state), 10, "no line added")
		local log = lastLog(state)
		Lib.contains(log.text, "Middle cannot build Factory", "permission reason")
		Lib.eq(#state.eventLog, 1, "one log entry")
	end)

	Lib.test("Working cannot build anything (6.2)", function()
		local state = runStep(fresh(), "Working", "Farm")
		Lib.eq(state.classes.Working.money, 10, "money untouched")
		Lib.eq(lineCount(state), 10, "no line added")
		Lib.contains(lastLog(state).text, "Working cannot build Farm", "reason")
	end)

	Lib.test("exact-to-zero payment is allowed (never below zero)", function()
		local state = fresh()
		state.classes.Middle.money = 12 -- exactly the Farm cost
		runStep(state, "Middle", "Farm")
		Lib.eq(state.classes.Middle.money, 0, "money spent to zero")
		Lib.truthy(state.lines["Farm-4"] ~= nil, "Farm-4 queued")
	end)

	Lib.test("builtOnDay = today means active the next Day (section 4)", function()
		local state = runStep(fresh(), "Capitalist", "Factory")
		local factory = state.lines["Factory-4"]
		Lib.truthy(factory ~= nil, "Factory-4 exists")
		-- queued today (1): excluded from today's Production (T2 filters
		-- builtOnDay < day) and operating from day 2
		Lib.eq(factory.builtOnDay, 1, "builtOnDay is today")
		state.day = 2 -- advance the fixture day; the rule now holds
		Lib.truthy(factory.builtOnDay < state.day, "line is active next Day")
	end)

	Lib.test("no build in the draft changes nothing (not even the hash)", function()
		local state = fresh()
		local before = StateHash.compute(state)
		runStep(state, "Working", nil)
		Lib.eq(StateHash.compute(state), before, "state untouched")
		Lib.eq(#state.eventLog, 0, "no log entry for a no-op")
	end)

	Lib.test("id numbering continues numerically past two digits (D-040)", function()
		local state = fresh()
		-- fixture: pre-existing two-digit farm ids
		state.lines["Farm-10"] = {
			id = "Farm-10",
			type = "Farm",
			owner = "Middle",
			openSlots = 2,
			builtOnDay = 0,
			assigned = 0,
		}
		state.lines["Farm-11"] = {
			id = "Farm-11",
			type = "Farm",
			owner = "Capitalist",
			openSlots = 2,
			builtOnDay = 0,
			assigned = 0,
		}
		runStep(state, "Middle", "Farm")
		Lib.truthy(state.lines["Farm-12"] ~= nil, "next id is Farm-12, not Farm-9/Farm-1")
	end)

	Lib.test("built states stay serializable and deterministic (no RNG used)", function()
		local a = runStep(fresh(), "State", "School")
		local b = runStep(fresh(), "State", "School")
		Lib.eq(#assertSerializable.validate(a), 0, "state a serializable")
		Lib.eq(#assertSerializable.validate(b), 0, "state b serializable")
		Lib.eq(StateHash.compute(a), StateHash.compute(b), "same input -> same result")
		-- 30 - 15 (School build cost)
		Lib.eq(a.classes.State.money, 15, "State paid for its School")
		local school = a.lines["School-3"]
		Lib.truthy(school ~= nil, "School-3 queued")
		Lib.eq(school.owner, "State", "School owner")
	end)

	Lib.test("addLine (the mutation point) rejects duplicate line ids", function()
		local state = fresh()
		local ok = pcall(function()
			StateOps.addLine(state, state.lines["Farm-1"])
		end)
		Lib.truthy(not ok, "duplicate line id rejected by StateOps.addLine")
	end)
end

return M
