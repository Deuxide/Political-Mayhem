--!nocheck
-- Headless simulator core (M10-T1): bots-only matches by seed range.
--
-- The simulator loads the real shared/server modules through tests/loader.luau,
-- so a run exercises the same StateFactory, Match, RuleSet and BotService the
-- game uses. It returns plain rows; the CLI wrapper prints a summary and writes
-- CSV/JSON. This module has no Roblox dependency and is also tested directly.

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Loader = require("../tests/loader")

local Sim = {}

local DEFAULT_N = 100
local DEFAULT_DIFFICULTY = "Normal"
local DEFAULT_SEED = 1
local DEFAULT_OUT = "build/sim"
local DEFAULT_FORMAT = "both"
local DIFFICULTIES = { "Easy", "Normal", "Hard", "Extreme" }
local FORMATS = { "csv", "json", "both" }

local function isOneOf(value: string, list: { string }): boolean
	for _, candidate in list do
		if candidate == value then
			return true
		end
	end
	return false
end

local function canonicalDifficulty(value: string): string
	for _, difficulty in DIFFICULTIES do
		if string.lower(difficulty) == string.lower(value) then
			return difficulty
		end
	end
	error(`unknown difficulty '{value}' (expected Easy, Normal, Hard or Extreme)`, 0)
end

local function positiveInteger(name: string, value: string): number
	local number = tonumber(value)
	if number == nil or number < 1 or math.floor(number) ~= number then
		error(`{name} needs a positive whole number, got '{value}'`, 0)
	end
	return number
end

function Sim.help(): string
	return table.concat({
		"Usage: scripts/sim [options]",
		"",
		"  --n <count>          matches to simulate (default 100)",
		"  --difficulty <name>  Easy, Normal, Hard or Extreme (default Normal)",
		"  --seed <number>      first seed (default 1)",
		"  --out <directory>    output directory (default build/sim)",
		"  --format <kind>      csv, json or both (default both)",
		"  --help               show this help",
	}, "\n")
end

function Sim.parseArgs(args: { string }): any
	local options = {
		n = DEFAULT_N,
		difficulty = DEFAULT_DIFFICULTY,
		seed = DEFAULT_SEED,
		out = DEFAULT_OUT,
		format = DEFAULT_FORMAT,
		help = false,
	}
	local index = 1
	while index <= #args do
		local argument = args[index]
		if argument == "--help" or argument == "-h" then
			options.help = true
		elseif argument == "--n" then
			index += 1
			options.n = positiveInteger("--n", args[index] or "")
		elseif argument == "--difficulty" then
			index += 1
			options.difficulty = canonicalDifficulty(args[index] or "")
		elseif argument == "--seed" then
			index += 1
			options.seed = positiveInteger("--seed", args[index] or "")
		elseif argument == "--out" then
			index += 1
			local value = args[index]
			if value == nil or value == "" then
				error("--out needs a directory", 0)
			end
			options.out = value
		elseif argument == "--format" then
			index += 1
			local value = string.lower(args[index] or "")
			if not isOneOf(value, FORMATS) then
				error("--format must be csv, json or both", 0)
			end
			options.format = value
		else
			error(`unknown argument '{argument}'`, 0)
		end
		index += 1
	end
	return options
end

local function percent(count: number, total: number): number
	if total == 0 then
		return 0
	end
	return count / total * 100
end

-- One match row, with everything M10-T2 needs for its metrics report.
function Sim.matchRow(match: any, seed: number, difficulty: string, classIds: { string }): any
	local state = match:state()
	local victory = state.victory
	local winners = {}
	if victory ~= nil then
		for _, classId in victory.winners do
			table.insert(winners, classId)
		end
	end

	local formed = 0
	local broken = 0
	for _, entry in state.eventLog do
		if string.find(entry.text, "formed an alliance", 1, true) then
			formed += 1
		end
		if string.find(entry.text, "broke the alliance with", 1, true) then
			broken += 1
		end
	end

	local vp = {}
	local money = {}
	local promisesKept = 0
	local promisesBroken = 0
	for _, classId in classIds do
		local class = state.classes[classId]
		vp[classId] = class.vp
		money[classId] = class.money
		local reputation = state.reputation[classId]
		if reputation ~= nil then
			promisesKept += reputation.kept
			promisesBroken += reputation.broken
		end
	end

	return {
		seed = seed,
		difficulty = difficulty,
		days = state.day,
		victory = if victory ~= nil then victory.kind else "none",
		winners = winners,
		stability = state.stability,
		collapseCounter = state.collapseCounter,
		alliancesFormed = formed,
		alliancesBroken = broken,
		promisesKept = promisesKept,
		promisesBroken = promisesBroken,
		eventCount = #state.eventLog,
		hash = match:hash(),
		vp = vp,
		money = money,
	}
end

-- Aggregate the rows for the printed summary and the JSON sidecar.
function Sim.summarize(rows: { any }, classIds: { string }, rounds: number?): any
	local summary = {
		n = #rows,
		rounds = rounds,
		classOrder = classIds,
		victoryCounts = { solo = 0, shared = 0, final = 0, collapse = 0, none = 0 },
		wins = {},
		winRates = {},
		avgDays = 0,
		avgStability = 0,
		collapseRate = 0,
		earlyVictoryMatches = 0,
		earlyVictoryRate = 0,
		allianceFormRate = 0,
		allianceBreakRate = 0,
		alliancesFormed = 0,
		alliancesBroken = 0,
		allianceMatches = 0,
		allianceBreakMatches = 0,
		promisesKept = 0,
		promisesBroken = 0,
	}
	for _, classId in classIds do
		summary.wins[classId] = 0
		summary.winRates[classId] = 0
	end

	local days = 0
	local stability = 0
	for _, row in rows do
		summary.victoryCounts[row.victory] = (summary.victoryCounts[row.victory] or 0) + 1
		for _, winner in row.winners do
			summary.wins[winner] = (summary.wins[winner] or 0) + 1
		end
		days += row.days
		stability += row.stability
		if
			rounds ~= nil
			and (row.victory == "solo" or row.victory == "shared")
			and row.days < rounds
		then
			summary.earlyVictoryMatches += 1
		end
		summary.alliancesFormed += row.alliancesFormed
		summary.alliancesBroken += row.alliancesBroken
		summary.promisesKept += row.promisesKept
		summary.promisesBroken += row.promisesBroken
		if row.alliancesFormed > 0 then
			summary.allianceMatches += 1
		end
		if row.alliancesBroken > 0 then
			summary.allianceBreakMatches += 1
		end
	end

	for _, classId in classIds do
		summary.winRates[classId] = percent(summary.wins[classId], summary.n)
	end
	if summary.n > 0 then
		summary.avgDays = days / summary.n
		summary.avgStability = stability / summary.n
	end
	summary.collapseRate = percent(summary.victoryCounts.collapse or 0, summary.n)
	summary.earlyVictoryRate = percent(summary.earlyVictoryMatches, summary.n)
	summary.allianceFormRate = percent(summary.allianceMatches, summary.n)
	summary.allianceBreakRate = percent(summary.allianceBreakMatches, summary.n)
	return summary
end

local function formatPercent(value: number): string
	return string.format("%.1f%%", value)
end

local function formatNumber(value: number): string
	return string.format("%.1f", value)
end

function Sim.formatSummary(summary: any, options: any, paths: any?): string
	local lines = {
		`Simulated {summary.n} {options.difficulty} matches (seeds {options.seed}-{options.seed + summary.n - 1})`,
		`Victories: solo {summary.victoryCounts.solo or 0}, shared {summary.victoryCounts.shared or 0}, final {summary.victoryCounts.final or 0}, collapse {summary.victoryCounts.collapse or 0}, unfinished {summary.victoryCounts.none or 0}`,
	}
	local rates = {}
	for _, classId in summary.classOrder do
		table.insert(rates, `{classId} {formatPercent(summary.winRates[classId] or 0)}`)
	end
	table.insert(lines, `Win rates: {table.concat(rates, ", ")}`)
	table.insert(
		lines,
		`Average length: {formatNumber(summary.avgDays)} Days; average Stability {formatNumber(
			summary.avgStability
		)}`
	)
	table.insert(
		lines,
		`Alliances: formed in {summary.allianceMatches}/{summary.n} ({formatPercent(
			summary.allianceFormRate
		)}), broken in {summary.allianceBreakMatches}/{summary.n} ({formatPercent(
			summary.allianceBreakRate
		)})`
	)
	table.insert(lines, `Promises: {summary.promisesKept} kept, {summary.promisesBroken} broken`)
	if paths ~= nil then
		local written = {}
		if paths.csv ~= nil then
			table.insert(written, paths.csv)
		end
		if paths.json ~= nil then
			table.insert(written, paths.json)
		end
		if #written > 0 then
			table.insert(lines, `Wrote {table.concat(written, " and ")}`)
		end
	end
	return table.concat(lines, "\n")
end

local function csvCell(value: any): string
	local text = tostring(value)
	if string.find(text, '[,"\n\r]') then
		return `"{string.gsub(text, '"', '""')}"`
	end
	return text
end

function Sim.toCsv(rows: { any }, classIds: { string }): string
	local header = {
		"seed",
		"difficulty",
		"days",
		"victory",
		"winners",
		"stability",
		"collapseCounter",
		"alliancesFormed",
		"alliancesBroken",
		"promisesKept",
		"promisesBroken",
		"eventCount",
		"hash",
	}
	for _, classId in classIds do
		table.insert(header, `vp_{classId}`)
	end
	for _, classId in classIds do
		table.insert(header, `money_{classId}`)
	end

	local lines = { table.concat(header, ",") }
	for _, row in rows do
		local values = {
			row.seed,
			row.difficulty,
			row.days,
			row.victory,
			table.concat(row.winners, "+"),
			row.stability,
			row.collapseCounter,
			row.alliancesFormed,
			row.alliancesBroken,
			row.promisesKept,
			row.promisesBroken,
			row.eventCount,
			row.hash,
		}
		for _, classId in classIds do
			table.insert(values, row.vp[classId] or 0)
		end
		for _, classId in classIds do
			table.insert(values, row.money[classId] or 0)
		end
		local cells = {}
		for _, value in values do
			table.insert(cells, csvCell(value))
		end
		table.insert(lines, table.concat(cells, ","))
	end
	return table.concat(lines, "\n") .. "\n"
end

function Sim.toJson(result: any): string
	return serde.encode("json", {
		meta = {
			n = result.summary.n,
			difficulty = result.options.difficulty,
			seedStart = result.options.seed,
			seedEnd = result.options.seed + result.summary.n - 1,
			elapsedSeconds = result.elapsed,
		},
		summary = result.summary,
		matches = result.rows,
	})
end

function Sim.writeOutputs(result: any, options: any): any
	if not fs.isDir(options.out) then
		fs.writeDir(options.out)
	end
	local base = `{string.lower(options.difficulty)}-{options.n}`
	local paths = {}
	if options.format == "csv" or options.format == "both" then
		local path = `{options.out}/{base}.csv`
		fs.writeFile(path, Sim.toCsv(result.rows, result.classIds))
		paths.csv = path
	end
	if options.format == "json" or options.format == "both" then
		local path = `{options.out}/{base}.json`
		fs.writeFile(path, Sim.toJson(result))
		paths.json = path
	end
	return paths
end

local function loadModules(): any
	local root = Loader.mount("src")
	return {
		Types = Loader.require(root.shared.Game.Types),
		StateFactory = Loader.require(root.shared.Game.State.StateFactory),
		RuleSet = Loader.require(root.shared.Game.RuleSet),
		Rng = Loader.require(root.shared.Game.Rng),
		Match = Loader.require(root.shared.Game.Match),
		BotService = Loader.require(root.server.Services.BotService),
	}
end

local function botSeats(BotService: any, classIds: { string }): any
	local seats = {}
	for _, classId in classIds do
		local seat = BotService.seatFor(classId)
		seats[classId] = { seat.id }
	end
	return seats
end

-- Run the seed range. The caller writes the files; tests can use the rows
-- directly without touching build/.
function Sim.run(options: any): any
	local modules = loadModules()
	local classIds = modules.Types.CLASS_IDS
	local seats = botSeats(modules.BotService, classIds)
	local rules = modules.RuleSet.new(options.difficulty)
	local maxDays = rules:rounds()

	local rows = {}
	local started = os.clock()
	for index = 1, options.n do
		local seed = options.seed + index - 1
		local state = modules.StateFactory.create(options.difficulty, seats, seed)
		local match = modules.Match.new(state, rules, modules.Rng.new(seed))
		local service = modules.BotService.new(seed)
		for _ = 1, maxDays do
			local current = match:state()
			current.phase = "Window"
			service:playWindow(match, classIds)
			match:resolveDay(match:rng())
			if match:state().victory ~= nil then
				break
			end
		end
		table.insert(rows, Sim.matchRow(match, seed, options.difficulty, classIds))
	end
	local elapsed = os.clock() - started
	local summary = Sim.summarize(rows, classIds, maxDays)
	summary.classOrder = classIds
	return {
		rows = rows,
		summary = summary,
		classIds = classIds,
		options = options,
		elapsed = elapsed,
	}
end

-- The dominant-strategy probes (M10-T2). The strike is a legal sticky draft
-- action; the zero-tax probe is a counterfactual policy state (all three tax
-- tracks held at 0), because one class alone cannot pass a tax bill against
-- the bots' class-interest votes.
local PROBES = {
	strike = {
		id = "strike",
		classId = "Working",
		label = "permanent strike on Capitalist",
	},
	["zero-tax"] = {
		id = "zero-tax",
		classId = "Capitalist",
		label = "zero-tax counterfactual (TaxWorking, TaxMiddle, TaxCapitalist = 0)",
	},
}

Sim.PROBES = PROBES

-- Run one probe over a seed range. The probe class still uses its normal bot
-- draft; only the probed action is forced each Window.
function Sim.runProbe(options: any): any
	local probe = (PROBES :: any)[options.probe]
	if probe == nil then
		error(`unknown probe '{options.probe}'`, 0)
	end

	local modules = loadModules()
	local classIds = modules.Types.CLASS_IDS
	local seats = botSeats(modules.BotService, classIds)
	local rules = modules.RuleSet.new(options.difficulty)
	local maxDays = rules:rounds()
	local taxPolicyIds = { "TaxWorking", "TaxMiddle", "TaxCapitalist" }

	local rows = {}
	local started = os.clock()
	for index = 1, options.n do
		local seed = options.seed + index - 1
		local state = modules.StateFactory.create(options.difficulty, seats, seed)
		local match = modules.Match.new(state, rules, modules.Rng.new(seed))
		local service = modules.BotService.new(seed)
		local actions = 0

		for _ = 1, maxDays do
			local current = match:state()
			current.phase = "Window"

			if probe.id == "zero-tax" then
				local policies = current.policies :: any
				local changed = false
				for _, policyId in taxPolicyIds do
					if policies[policyId] ~= 0 then
						policies[policyId] = 0
						changed = true
					end
				end
				if changed then
					actions += 1
				end
			end

			service:playWindow(match, classIds)

			if probe.id == "strike" then
				current.drafts.Working.strike = { target = "Capitalist" }
				actions += 1
			end

			match:resolveDay(match:rng())
			if match:state().victory ~= nil then
				break
			end
		end

		local row = Sim.matchRow(match, seed, options.difficulty, classIds)
		row.probe = probe.id
		row.probeClass = probe.classId
		row.probeActions = actions
		table.insert(rows, row)
	end

	local elapsed = os.clock() - started
	local summary = Sim.summarize(rows, classIds, maxDays)
	summary.probe = probe.id
	summary.probeClass = probe.classId
	summary.probeLabel = probe.label
	summary.probeWins = summary.wins[probe.classId] or 0
	summary.probeWinRate = summary.winRates[probe.classId] or 0
	local totalActions = 0
	for _, row in rows do
		totalActions += row.probeActions
	end
	summary.probeActions = totalActions
	return {
		rows = rows,
		summary = summary,
		classIds = classIds,
		options = options,
		elapsed = elapsed,
	}
end

function Sim.helpReport(): string
	return table.concat({
		"Usage: scripts/sim_report [options]",
		"",
		"  --n <count>     matches per block (default 500)",
		"  --seed <number> first seed (default 1)",
		"  --out <dir>     output directory (default build/sim)",
		"  --help          show this help",
	}, "\n")
end

function Sim.parseReportArgs(args: { string }): any
	local options = { n = 500, seed = 1, out = DEFAULT_OUT, help = false }
	local index = 1
	while index <= #args do
		local argument = args[index]
		if argument == "--help" or argument == "-h" then
			options.help = true
		elseif argument == "--n" then
			index += 1
			options.n = positiveInteger("--n", args[index] or "")
		elseif argument == "--seed" then
			index += 1
			options.seed = positiveInteger("--seed", args[index] or "")
		elseif argument == "--out" then
			index += 1
			local value = args[index]
			if value == nil or value == "" then
				error("--out needs a directory", 0)
			end
			options.out = value
		else
			error(`unknown argument '{argument}'`, 0)
		end
		index += 1
	end
	return options
end

-- Run the Normal and Hard baselines plus the two dominant-strategy probes.
function Sim.runReport(options: any): any
	local started = os.clock()
	local normal = Sim.run({ n = options.n, difficulty = "Normal", seed = options.seed })
	local hard = Sim.run({ n = options.n, difficulty = "Hard", seed = options.seed })
	local strike = Sim.runProbe({
		n = options.n,
		difficulty = "Normal",
		seed = options.seed,
		probe = "strike",
	})
	local zeroTax = Sim.runProbe({
		n = options.n,
		difficulty = "Normal",
		seed = options.seed,
		probe = "zero-tax",
	})
	return {
		options = options,
		normal = normal,
		hard = hard,
		probes = { strike = strike, zeroTax = zeroTax },
		elapsed = os.clock() - started,
	}
end

local function mark(ok: boolean): string
	return if ok then "PASS" else "FAIL"
end

local function classRates(summary: any): string
	local parts = {}
	for _, classId in summary.classOrder do
		local rate = summary.winRates[classId] or 0
		table.insert(parts, `{classId} {formatPercent(rate)} [{mark(rate >= 15 and rate <= 40)}]`)
	end
	return table.concat(parts, ", ")
end

function Sim.formatReport(report: any, paths: any?): string
	local normal = report.normal.summary
	local hard = report.hard.summary
	local strike = report.probes.strike.summary
	local zeroTax = report.probes.zeroTax.summary
	local checks = 0
	local passed = 0
	local function check(ok: boolean): boolean
		checks += 1
		if ok then
			passed += 1
		end
		return ok
	end
	for _, classId in normal.classOrder do
		local rate = normal.winRates[classId] or 0
		check(rate >= 15 and rate <= 40)
	end

	local lines = {
		`M10-T2 balance report (GAME_DESIGN section 19)`,
		`Seeds {report.options.seed}-{report.options.seed + normal.n - 1}; {normal.n} matches per block.`,
		"",
		"Normal bots-only",
		`  Victory types: solo {normal.victoryCounts.solo or 0}, shared {normal.victoryCounts.shared or 0}, final {normal.victoryCounts.final or 0}, collapse {normal.victoryCounts.collapse or 0}, unfinished {normal.victoryCounts.none or 0}`,
		`  Class win rates (shared counts each): {classRates(normal)}`,
		`  Average length: {formatNumber(normal.avgDays)} Days`,
		`  Early solo/shared before the last Day: {formatPercent(normal.earlyVictoryRate)} (target 30-60) [{mark(
			check(normal.earlyVictoryRate >= 30 and normal.earlyVictoryRate <= 60)
		)}]`,
		`  Alliances formed: {formatPercent(normal.allianceFormRate)} (target >=50) [{mark(
			check(normal.allianceFormRate >= 50)
		)}]`,
		`  Alliances broken: {formatPercent(normal.allianceBreakRate)} (target >=15) [{mark(
			check(normal.allianceBreakRate >= 15)
		)}]`,
		"",
		"Hard bots-only",
		`  Collapse: {formatPercent(hard.collapseRate)} (target <=20) [{mark(
			check(hard.collapseRate <= 20)
		)}]`,
		`  Victory types: solo {hard.victoryCounts.solo or 0}, shared {hard.victoryCounts.shared or 0}, final {hard.victoryCounts.final or 0}, collapse {hard.victoryCounts.collapse or 0}, unfinished {hard.victoryCounts.none or 0}`,
		"",
		"Dominant-strategy probes (Normal)",
		`  {strike.probeLabel}: {strike.probeClass} wins {formatPercent(strike.probeWinRate)} (target <=50) [{mark(
			check(strike.probeWinRate <= 50)
		)}]`,
		`  {zeroTax.probeLabel}: {zeroTax.probeClass} wins {formatPercent(zeroTax.probeWinRate)} (target <=50) [{mark(
			check(zeroTax.probeWinRate <= 50)
		)}]`,
		"",
		`Section 19 checks: {passed}/{checks} pass`,
	}
	if paths ~= nil then
		local written = {}
		if paths.txt ~= nil then
			table.insert(written, paths.txt)
		end
		if paths.json ~= nil then
			table.insert(written, paths.json)
		end
		if #written > 0 then
			table.insert(lines, `Wrote {table.concat(written, " and ")}`)
		end
	end
	return table.concat(lines, "\n")
end

function Sim.writeReport(report: any, options: any): any
	if not fs.isDir(options.out) then
		fs.writeDir(options.out)
	end
	local paths = {
		txt = `{options.out}/m10-t2-report.txt`,
		json = `{options.out}/m10-t2-report.json`,
	}
	fs.writeFile(paths.txt, Sim.formatReport(report, paths))
	fs.writeFile(
		paths.json,
		serde.encode("json", {
			meta = {
				n = report.normal.summary.n,
				seedStart = options.seed,
				seedEnd = options.seed + report.normal.summary.n - 1,
				elapsedSeconds = report.elapsed,
			},
			normal = report.normal.summary,
			hard = report.hard.summary,
			probes = {
				strike = report.probes.strike.summary,
				zeroTax = report.probes.zeroTax.summary,
			},
		})
	)
	return paths
end

return Sim
