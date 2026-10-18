--!nocheck
-- Tests that run the REAL modules from src/ (loaded through tests/loader.luau).
-- Unlike tests/harness.luau, nothing here is a pasted copy of game code.

local Loader = require("./loader")

local shared = Loader.mount("src/shared")
local Rng = Loader.require(shared.Game.Rng)
local StateOps = Loader.require(shared.Game.State.StateOps)
local StateFactory = Loader.require(shared.Game.State.StateFactory)
local StateHash = Loader.require(shared.Game.State.StateHash)
local RuleSet = Loader.require(shared.Game.RuleSet)
local Match = Loader.require(shared.Game.Match)
local BuildStep = Loader.require(shared.Game.Steps.BuildStep)

local config = {
	Classes = Loader.require(shared.Config.Classes),
	Policies = Loader.require(shared.Config.Policies),
	Difficulty = Loader.require(shared.Config.Difficulty),
	Lines = Loader.require(shared.Config.Lines),
}

local M = {}
local passed, failed = 0, 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		print("✓ [real] " .. name)
		passed += 1
	else
		print("✗ [real] " .. name .. ": " .. tostring(err))
		failed += 1
	end
end

local function eq(actual, expected, msg: string?)
	if actual ~= expected then
		error(`{msg or "not equal"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

-- A minimal, hand-built state in the shape GAME_DESIGN section 4 / Types.luau describe.
local function makeState(round: number)
	local function cls(id, money)
		return {
			id = id,
			resources = {
				Money = money,
				Influence = 0,
				Food = 0,
				Goods = 0,
				Health = 0,
				Education = 0,
			},
		}
	end
	return {
		round = round,
		classes = {
			Working = cls("Working", 10),
			Middle = cls("Middle", 25),
			Capitalist = cls("Capitalist", 50),
			State = cls("State", 30),
		},
		lines = {},
		drafts = {},
	}
end

local function runBuild(state)
	local ctx = { rng = Rng.new(1), ruleSet = nil, stateOps = StateOps.new(), trace = {} }
	BuildStep.new():run(state, ctx)
	return ctx.trace
end

local function countLines(state)
	local n = 0
	for _ in pairs(state.lines) do
		n += 1
	end
	return n
end

function M.run()
	-- ===== M2-T1 "Done when" (docs/ROADMAP.md) =====
	test("BuildStep: affordable build queues a line and charges the cost", function()
		local state = makeState(3)
		state.drafts.Capitalist = { build = "Factory" }
		runBuild(state)
		eq(countLines(state), 1)
		eq(state.classes.Capitalist.resources.Money, 30, "Factory costs 20")
	end)

	test("BuildStep: new line becomes active the NEXT day", function()
		local state = makeState(3)
		state.drafts.Capitalist = { build = "Factory" }
		runBuild(state)
		for _, line in pairs(state.lines) do
			eq(line.builtOnDay, 4)
		end
	end)

	test("BuildStep: unaffordable build is skipped, logged, and free", function()
		local state = makeState(3)
		state.classes.Capitalist.resources.Money = 5
		state.drafts.Capitalist = { build = "Factory" }
		local trace = runBuild(state)
		eq(countLines(state), 0)
		eq(state.classes.Capitalist.resources.Money, 5)
		eq(#trace > 0, true, "expected a log entry explaining the skip")
	end)

	test(
		"BuildStep: class not allowed to build that type is skipped (State cannot build Farm)",
		function()
			local state = makeState(3)
			state.drafts.State = { build = "Farm" }
			runBuild(state)
			eq(countLines(state), 0)
		end
	)

	test("BuildStep: Config/Lines agrees with GAME_DESIGN 6.2 on who may build Farms", function()
		local owners = {}
		for _, o in ipairs(config.Lines.Farm.eligibleOwners) do
			owners[o] = true
		end
		eq(owners.Middle, true)
		eq(owners.Capitalist, true)
		eq(owners.State, nil, "State builds Clinics/Schools only")
	end)

	-- ===== Does the real engine run at all? =====
	test("StateFactory output has the fields BuildStep needs (lines, drafts)", function()
		local state = StateFactory.create("Normal", {}, 42, config)
		eq(type(state.lines), "table", "state.lines")
		eq(type(state.drafts), "table", "state.drafts")
	end)

	test("Match:snapshot returns a real copy", function()
		local state = makeState(1)
		local match = Match.new(state, RuleSet.new("Normal", config), Rng.new(1))
		local snap = match:snapshot()
		eq(type(snap), "table", "snapshot")
		snap.round = 99
		eq(match:getState().round, 1)
	end)

	test("Match:resolveDay succeeds on a StateFactory state", function()
		local state = StateFactory.create("Normal", {}, 42, config)
		local match = Match.new(state, RuleSet.new("Normal", config), Rng.new(42))
		local ok = match:resolveDay()
		eq(ok, true, "resolveDay")
	end)

	test("Match:resolveDay is deterministic for the same seed", function()
		local function run()
			local state = StateFactory.create("Normal", {}, 42, config)
			local match = Match.new(state, RuleSet.new("Normal", config), Rng.new(42))
			for day = 1, 3 do
				eq(match:resolveDay(), true, `resolveDay on day {day}`)
			end
			return StateHash.compute(match:getState())
		end
		eq(run(), run())
	end)

	print(`\n[real] Results: {passed} passed, {failed} failed`)
	return failed
end

return M
