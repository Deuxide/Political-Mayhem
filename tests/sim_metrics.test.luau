--!nocheck
-- Simulator core (M10-T1): CLI parsing, metric aggregation, CSV shape, and a
-- tiny seed range through the real game modules. The full 500-match command is
-- verified separately; this suite keeps the core honest in every check.

local Lib = require("./lib")
local Sim = require("../scripts/sim_lib")

local M = {}

local CLASSES = { "Working", "Middle", "Capitalist", "State" }

local function row(
	victory: string,
	winners: { string },
	days: number,
	stability: number,
	formed: number,
	broken: number,
	kept: number,
	promisesBroken: number
): any
	return {
		seed = 1,
		difficulty = "Normal",
		days = days,
		victory = victory,
		winners = winners,
		stability = stability,
		collapseCounter = 0,
		alliancesFormed = formed,
		alliancesBroken = broken,
		promisesKept = kept,
		promisesBroken = promisesBroken,
		eventCount = 10,
		hash = "abc",
		vp = { Working = 1, Middle = 2, Capitalist = 3, State = 4 },
		money = { Working = 5, Middle = 6, Capitalist = 7, State = 8 },
	}
end

function M.run()
	print("simulator")

	Lib.test("parses the documented command line", function()
		local options = Sim.parseArgs({
			"--n",
			"500",
			"--difficulty",
			"Normal",
			"--seed",
			"10",
			"--out",
			"build/sim-test",
			"--format",
			"json",
		})
		Lib.eq(options.n, 500)
		Lib.eq(options.difficulty, "Normal")
		Lib.eq(options.seed, 10)
		Lib.eq(options.out, "build/sim-test")
		Lib.eq(options.format, "json")
	end)

	Lib.test("rejects a zero count and an unknown difficulty", function()
		Lib.eq(pcall(Sim.parseArgs, { "--n", "0" }), false)
		Lib.eq(pcall(Sim.parseArgs, { "--difficulty", "Impossible" }), false)
		Lib.eq(pcall(Sim.parseArgs, { "--format", "yaml" }), false)
	end)

	Lib.test("summarizes victories, win rates and alliance rates", function()
		local summary = Sim.summarize({
			row("solo", { "Working" }, 10, 50, 1, 0, 1, 0),
			row("shared", { "Middle", "Capitalist" }, 12, 40, 2, 1, 2, 1),
			row("final", { "Capitalist" }, 8, 0, 0, 0, 0, 2),
		}, CLASSES)

		Lib.eq(summary.n, 3)
		Lib.eq(summary.victoryCounts.solo, 1)
		Lib.eq(summary.victoryCounts.shared, 1)
		Lib.eq(summary.victoryCounts.final, 1)
		Lib.eq(summary.wins.Working, 1)
		Lib.eq(summary.wins.Middle, 1)
		Lib.eq(summary.wins.Capitalist, 2)
		Lib.eq(summary.wins.State, 0)
		Lib.eq(string.format("%.1f", summary.winRates.Capitalist), "66.7")
		Lib.eq(summary.avgDays, 10)
		Lib.eq(summary.avgStability, 30)
		Lib.eq(summary.allianceMatches, 2)
		Lib.eq(summary.allianceBreakMatches, 1)
		Lib.eq(summary.alliancesFormed, 3)
		Lib.eq(summary.alliancesBroken, 1)
		Lib.eq(summary.promisesKept, 3)
		Lib.eq(summary.promisesBroken, 3)
	end)

	Lib.test("writes the full metric columns to CSV", function()
		local csv = Sim.toCsv({
			row("shared", { "Capitalist", "State" }, 12, 0, 6, 4, 0, 0),
		}, CLASSES)
		Lib.contains(csv, "vp_Working")
		Lib.contains(csv, "vp_State")
		Lib.contains(csv, "money_Working")
		Lib.contains(csv, "money_State")
		Lib.contains(csv, "Capitalist+State")
		Lib.contains(csv, "6,4")
	end)

	Lib.test("a tiny seed range runs the real modules", function()
		local result = Sim.run({ n = 2, difficulty = "Normal", seed = 1 })
		Lib.eq(#result.rows, 2)
		Lib.eq(result.summary.n, 2)
		Lib.truthy(result.rows[1].hash ~= "", "the match hash is recorded")
		Lib.truthy(result.rows[1].days >= 1, "the match length is recorded")
		Lib.truthy(result.rows[1].alliancesFormed > 0, "the bots formed an alliance")
		Lib.eq(result.rows[1].victory, "final")
	end)
end

return M
