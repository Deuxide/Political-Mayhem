--!nocheck
-- Config validator (M1-T2): every class has start values, every difficulty
-- has all keys, prices exist for every resource — with the exact numbers and
-- shapes of docs/GAME_DESIGN.md sections 5, 6, 7, 11, 12, 16. The REAL config
-- modules load through the loader (D-014); nothing is pasted (D-034).

local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

-- [string] -> number map with key-set exactness (both directions).
local function expectExactMap(actual: any, expected: { [string]: number }, label: string)
	for key in actual do
		Lib.truthy(expected[key] ~= nil, label .. ": unexpected key " .. tostring(key))
	end
	for key, exp in expected do
		Lib.truthy(actual[key] ~= nil, label .. ": missing key " .. key)
		Lib.eq(actual[key], exp, label .. "." .. key)
	end
end

local function expectList(actual: any, expected: { string }, label: string)
	Lib.eq(#actual, #expected, label .. " length")
	for i = 1, #expected do
		Lib.eq(actual[i], expected[i], label .. "[" .. i .. "]")
	end
end

local function expectRate(actual: any, perWorker: number?, flat: number?, label: string)
	Lib.eq(actual.perWorker, perWorker, label .. ".perWorker")
	Lib.eq(actual.flat, flat, label .. ".flat")
end

-- Criteria lists are tables; extract their `id` field for expectList.
local function idsOf(criteria: { any }): { string }
	local ids: { string } = {}
	for i, criterion in criteria do
		ids[i] = criterion.id
	end
	return ids
end

function M.run()
	print("config")
	local shared = Loader.mount("src/shared")
	local Types = Loader.require(shared.Game.Types)
	local Config = shared.Config
	local Resources = Loader.require(Config.Resources)
	local Classes = Loader.require(Config.Classes)
	local Needs = Loader.require(Config.Needs)
	local Lines = Loader.require(Config.Lines)
	local Policies = Loader.require(Config.Policies)
	local Market = Loader.require(Config.Market)
	local Objectives = Loader.require(Config.Objectives)
	local Difficulty = Loader.require(Config.Difficulty)
	local Events = Loader.require(Config.Events)

	Lib.test("Resources covers all six ids with the right stock keys (D-008, 5.2)", function()
		local STOCK_KEYS =
			{ Food = "food", Goods = "goods", Health = "health", Education = "education" }
		for _, id in Types.RESOURCE_IDS do
			local info = Resources[id :: any] :: any
			Lib.truthy(info ~= nil, `Resources must have {id}`)
			Lib.eq(info.name, id, `Resources.{id}.name`)
			Lib.eq(info.stockKey, STOCK_KEYS[id :: any], `Resources.{id}.stockKey`)
		end
	end)

	Lib.test("Classes: exact starting values per 5.2", function()
		local EXPECTED = {
			Working = {
				money = 10,
				influence = 3,
				workers = 16,
				food = 4,
				goods = 0,
				health = 1,
				education = 0,
			},
			Middle = {
				money = 25,
				influence = 2,
				workers = 0,
				food = 2,
				goods = 1,
				health = 1,
				education = 1,
			},
			Capitalist = {
				money = 50,
				influence = 1,
				workers = 0,
				food = 1,
				goods = 2,
				health = 1,
				education = 3,
			},
			State = {
				money = 30,
				influence = 2,
				workers = 0,
				food = 0,
				goods = 0,
				health = 0,
				education = 0,
			},
		}
		for _, id in Types.CLASS_IDS do
			local entry = (Classes.entries :: any)[id :: any] :: any
			local exp = EXPECTED[id :: any] :: any
			Lib.truthy(entry ~= nil, `Classes must have {id}`)
			Lib.eq(entry.startMoney, exp.money, `Classes.{id}.startMoney`)
			Lib.eq(entry.startInfluence, exp.influence, `Classes.{id}.startInfluence`)
			Lib.eq(entry.startWorkers, exp.workers, `Classes.{id}.startWorkers`)
			for _, stockId in Types.STOCK_IDS do
				Lib.eq(
					entry.startStock[stockId :: any],
					exp[stockId :: any] :: number,
					`Classes.{id}.{stockId}`
				)
			end
		end
		Lib.eq(Classes.influenceCap, 20, "Classes.influenceCap (7.1)")
	end)

	Lib.test("Classes: base votes 4/3/2/3 and income 3/2/1/2 (7.1, 7.3)", function()
		local EXPECTED = {
			Working = { votes = 4, income = 3 },
			Middle = { votes = 3, income = 2 },
			Capitalist = { votes = 2, income = 1 },
			State = { votes = 3, income = 2 },
		}
		local totalVotes = 0
		for id, exp in EXPECTED do
			local entry = (Classes.entries :: any)[id] :: any
			Lib.eq(entry.baseVotes, exp.votes, `Classes.{id}.baseVotes`)
			Lib.eq(entry.influenceIncome, exp.income, `Classes.{id}.influenceIncome`)
			totalVotes += exp.votes
		end
		Lib.eq(totalVotes, 12, "base votes total 12 (7.3)")
	end)

	Lib.test("Classes: build permissions exactly per 6.2", function()
		expectList(Classes.entries.Working.canBuild, {}, "Working.canBuild")
		expectList(
			Classes.entries.Middle.canBuild,
			{ "Farm", "Clinic", "School" },
			"Middle.canBuild"
		)
		expectList(
			Classes.entries.Capitalist.canBuild,
			{ "Farm", "Factory" },
			"Capitalist.canBuild"
		)
		expectList(Classes.entries.State.canBuild, { "Clinic", "School" }, "State.canBuild")
		for _, id in Types.CLASS_IDS do
			for _, lineType in (Classes.entries :: any)[id :: any].canBuild do
				Lib.truthy(
					table.find(Types.LINE_TYPES, lineType) ~= nil,
					`canBuild entry must be a LineType ({id})`
				)
			end
		end
	end)

	Lib.test("Classes: lobby only Middle and Capitalist, exact rates (7.1)", function()
		Lib.eq((Classes.entries.Working :: any).lobby, nil, "Working must not lobby")
		Lib.eq((Classes.entries.State :: any).lobby, nil, "State must not lobby")
		Lib.eq(Classes.entries.Middle.lobby.moneyPerInfluence, 3, "Middle lobby cost")
		Lib.eq(Classes.entries.Middle.lobby.maxInfluence, 2, "Middle lobby cap")
		Lib.eq(Classes.entries.Capitalist.lobby.moneyPerInfluence, 2, "Capitalist lobby cost")
		Lib.eq(Classes.entries.Capitalist.lobby.maxInfluence, 4, "Capitalist lobby cap")
	end)

	Lib.test("Classes: initial line grid per 5.2 sums to 3/3/2/2 (20 slots)", function()
		local GRID = {
			Working = { Farm = 0, Factory = 0, Clinic = 0, School = 0 },
			Middle = { Farm = 2, Factory = 0, Clinic = 1, School = 1 },
			Capitalist = { Farm = 1, Factory = 3, Clinic = 0, School = 0 },
			State = { Farm = 0, Factory = 0, Clinic = 1, School = 1 },
		}
		local TOTAL = { Farm = 3, Factory = 3, Clinic = 2, School = 2 }
		local slots = 0
		local totals: { [string]: number } = {}
		for _, id in Types.CLASS_IDS do
			local lines = (Classes.entries :: any)[id :: any].startLines
			for _, lineType in Types.LINE_TYPES do
				Lib.eq(
					lines[lineType :: any],
					(GRID[id :: any] :: any)[lineType :: any],
					`Classes.{id}.startLines.{lineType}`
				)
				totals[lineType] = (totals[lineType] or 0) + (lines[lineType :: any] :: number)
				slots += (lines[lineType :: any] :: number) * (
					(Lines :: any)[lineType :: any] :: any
				).slotsMax
			end
		end
		for _, lineType in Types.LINE_TYPES do
			Lib.eq(totals[lineType], (TOTAL :: any)[lineType :: any], `{lineType} total lines`)
		end
		Lib.eq(slots, 20, "20 slots for 16 workers")
	end)

	Lib.test("Needs: exact rates per 5.3", function()
		expectRate(Needs.Working.food, 0.5, nil, "Working.food")
		expectRate(Needs.Working.goods, nil, 0, "Working.goods")
		expectRate(Needs.Working.health, 0.25, nil, "Working.health")
		expectRate(Needs.Working.education, nil, 0, "Working.education")
		expectRate(Needs.Middle.food, nil, 2, "Middle.food")
		expectRate(Needs.Middle.goods, nil, 1, "Middle.goods")
		expectRate(Needs.Middle.health, nil, 1, "Middle.health")
		expectRate(Needs.Middle.education, nil, 1, "Middle.education")
		expectRate(Needs.Capitalist.food, nil, 1, "Capitalist.food")
		expectRate(Needs.Capitalist.goods, nil, 2, "Capitalist.goods")
		expectRate(Needs.Capitalist.health, nil, 1, "Capitalist.health")
		expectRate(Needs.Capitalist.education, nil, 0, "Capitalist.education")
		for _, stockId in Types.STOCK_IDS do
			expectRate((Needs.State :: any)[stockId :: any], nil, 0, `State.{stockId}`)
		end
	end)

	Lib.test("Needs: Day-one demand totals 11/3/6/1 per 5.3", function()
		local workers = 16 -- 5.2 starting workers, asserted above
		local total = {
			food = math.ceil(workers * Needs.Working.food.perWorker),
			goods = Needs.Working.goods.flat,
			health = math.ceil(workers * Needs.Working.health.perWorker),
			education = Needs.Working.education.flat,
		}
		for _, stockId in Types.STOCK_IDS do
			total[stockId :: any] += Needs.Middle[stockId :: any].flat + Needs.Capitalist[stockId :: any].flat + Needs.State[stockId :: any].flat
		end
		expectExactMap(total, { food = 11, goods = 3, health = 6, education = 1 }, "Day-one demand")
	end)

	Lib.test("Lines: exact outputs, slots, inputs, costs (6.1)", function()
		local EXPECTED = {
			Farm = { output = { food = 2 }, input = nil, slotsMax = 2, buildCost = 12 },
			Factory = {
				output = { goods = 2 },
				input = { education = 1 },
				slotsMax = 2,
				buildCost = 20,
			},
			Clinic = { output = { health = 1 }, input = nil, slotsMax = 2, buildCost = 15 },
			School = { output = { education = 1 }, input = nil, slotsMax = 2, buildCost = 15 },
		}
		for lineType, exp in EXPECTED do
			local cfg = (Lines :: any)[lineType] :: any
			Lib.eq(cfg.slotsMax, exp.slotsMax, `Lines.{lineType}.slotsMax`)
			Lib.eq(cfg.buildCost, exp.buildCost, `Lines.{lineType}.buildCost`)
			Lib.truthy(cfg ~= nil, `Lines must have {lineType}`)
		end
		for _, lineType in Types.LINE_TYPES do
			local cfg = (Lines :: any)[lineType] :: any
			local exp = EXPECTED[lineType :: any] :: any
			expectExactMap(cfg.output, exp.output, `Lines.{lineType}.output`)
			if exp.input then
				Lib.truthy(cfg.input ~= nil, `Lines.{lineType}.input`)
			else
				Lib.truthy(cfg.input == nil, `Lines.{lineType}.input must be absent`)
			end
		end
	end)

	Lib.test("Policies: seven tracks with exact bounds, defaults, values (7.2)", function()
		for _, id in Types.POLICY_IDS do
			Lib.truthy(Policies.tracks[id :: any] ~= nil, `Policies must have track {id}`)
		end
		local expectTrack = function(
			id: string,
			minLevel: number,
			maxLevel: number,
			def: number,
			values: { [number]: number }?,
			label: string
		)
			local track = (Policies.tracks :: any)[id] :: any
			Lib.eq(track.minLevel, minLevel, label .. ".minLevel")
			Lib.eq(track.maxLevel, maxLevel, label .. ".maxLevel")
			Lib.eq(track.default, def, label .. ".default")
			if values then
				for level, value in values do
					Lib.eq(
						track.levelValues[level],
						value,
						label .. ".levelValues[" .. level .. "]"
					)
				end
			else
				Lib.truthy(track.levelValues == nil, label .. " is a mode-only track")
			end
		end
		expectTrack("Wage", 1, 3, 2, { [1] = 1, [2] = 2, [3] = 3 }, "Wage")
		expectTrack(
			"TaxWorking",
			0,
			3,
			1,
			{ [0] = 0, [1] = 0.1, [2] = 0.2, [3] = 0.3 },
			"TaxWorking"
		)
		expectTrack("TaxMiddle", 0, 3, 1, { [0] = 0, [1] = 0.1, [2] = 0.2, [3] = 0.3 }, "TaxMiddle")
		expectTrack(
			"TaxCapitalist",
			0,
			3,
			1,
			{ [0] = 0, [1] = 0.1, [2] = 0.2, [3] = 0.3 },
			"TaxCapitalist"
		)
		expectTrack("PublicServices", 0, 1, 0, nil, "PublicServices")
		expectTrack("Tariff", 0, 2, 0, { [0] = 0, [1] = 1, [2] = 2 }, "Tariff")
		expectTrack("StrikeRights", 0, 1, 1, nil, "StrikeRights")
		for _, id in Types.POLICY_IDS do
			local track = (Policies.tracks :: any)[id] :: any
			Lib.truthy(
				track.default >= track.minLevel and track.default <= track.maxLevel,
				`default within bounds ({id})`
			)
		end
	end)

	Lib.test("Policies: bill numbers and unpaid wage penalty (6.4, 7.3)", function()
		local bills = Policies.bills :: any
		Lib.eq(bills.maxLive, 2, "at most 2 live bills")
		Lib.eq(bills.proposeCost, 1, "propose cost 1 Influence")
		Lib.eq(bills.cutoffSeconds, 20, "bill cutoff seconds")
		Lib.eq(bills.quorum, 5, "confirm quorum of 5")
		Lib.eq(Policies.unpaidWagePenalty, 1, "unpaid wage penalty")
	end)

	Lib.test("Market: prices for every stock resource, exact values, cap (6.6)", function()
		local EXPECTED = {
			food = { sell = 2, buy = 4 },
			goods = { sell = 3, buy = 6 },
			health = { sell = 5, buy = 10 },
			education = { sell = 4, buy = 8 },
		}
		for _, stockId in Types.STOCK_IDS do
			local price = (Market.prices :: any)[stockId :: any] :: any
			Lib.truthy(price ~= nil, `Market must price {stockId}`)
			Lib.eq(price.sell, EXPECTED[stockId :: any].sell, `Market.{stockId}.sell`)
			Lib.eq(price.buy, EXPECTED[stockId :: any].buy, `Market.{stockId}.buy`)
		end
		Lib.eq(Market.volumeCap, 6, "marketVolumeCap")
	end)

	Lib.test("Objectives: exact criteria per class (11.1)", function()
		expectList(
			idsOf(Objectives.Working),
			{ "needsMet", "employmentAtLeast", "wageAtLeast", "ownBillPassed" },
			"Working criteria"
		)
		Lib.eq(Objectives.Working[1].vp, nil, "needsMet worth 1")
		Lib.eq(Objectives.Working[2].params.fraction, 0.75, "employment 75 percent")
		Lib.eq(Objectives.Working[3].params.level, 2, "Wage at least Medium (level 2)")
		expectList(
			idsOf(Objectives.Middle),
			{ "educationStockAtLeast", "moneyGainAtLeast", "ownsLinesAtLeast", "needsMet" },
			"Middle criteria"
		)
		Lib.eq(Objectives.Middle[1].params.amount, 2, "Education >= 2")
		Lib.eq(Objectives.Middle[2].params.amount, 5, "Money gain >= 5")
		Lib.eq(Objectives.Middle[3].params.count, 5, "owns >= 5 lines")
		Lib.eq(Objectives.Middle[1].vp, nil)
		expectList(
			idsOf(Objectives.Capitalist),
			{ "moneyGainScaled", "taxCapitalistAtMost" },
			"Capitalist criteria"
		)
		Lib.eq(Objectives.Capitalist[1].vp, 3, "money gain criterion caps at 3 VP")
		Lib.eq(Objectives.Capitalist[1].params.divisor, 8, "floor(gain / 8)")
		Lib.eq(Objectives.Capitalist[2].params.level, 1, "taxCapitalistAtMost level 1")
		expectList(idsOf(Objectives.State), {
			"moneyNotDecreasing",
			"stabilityAtLeast",
			"stabilityAtLeast",
			"publicStaffingAtLeast",
		}, "State criteria")
		Lib.eq(Objectives.State[2].params.level, 60, "Stability >= 60")
		Lib.eq(Objectives.State[3].params.level, 80, "Stability >= 80")
		Lib.eq(Objectives.State[4].params.fraction, 0.75, "public staffing >= 75 percent")
	end)

	Lib.test("Difficulty: all 12+ keys every difficulty, exact matrix (12)", function()
		local EXPECTED = {
			Easy = {
				rounds = 8,
				windowSeconds = 90,
				revealSeconds = 12,
				soloTarget = 14,
				policiesEnabled = { "Wage", "TaxCapitalist", "PublicServices" },
				infoMode = "open",
				eventsEnabled = false,
				eventsForecast = false,
				collapseEnabled = false,
				hints = "full",
				startResourceMultiplier = 1.25,
				needsMultiplier = 0.75,
				botSuggestions = true,
			},
			Normal = {
				rounds = 12,
				windowSeconds = 120,
				revealSeconds = 8,
				soloTarget = 24,
				policiesEnabled = {
					"Wage",
					"TaxWorking",
					"TaxMiddle",
					"TaxCapitalist",
					"PublicServices",
					"Tariff",
					"StrikeRights",
				},
				infoMode = "open",
				eventsEnabled = false,
				eventsForecast = false,
				collapseEnabled = false,
				hints = "light",
				startResourceMultiplier = 1,
				needsMultiplier = 1,
				botSuggestions = false,
			},
			Hard = {
				rounds = 14,
				windowSeconds = 150,
				revealSeconds = 8,
				soloTarget = 34,
				policiesEnabled = {
					"Wage",
					"TaxWorking",
					"TaxMiddle",
					"TaxCapitalist",
					"PublicServices",
					"Tariff",
					"StrikeRights",
				},
				infoMode = "partial",
				eventsEnabled = true,
				eventsForecast = true,
				collapseEnabled = true,
				hints = "none",
				startResourceMultiplier = 1,
				needsMultiplier = 1,
				botSuggestions = false,
			},
			Extreme = {
				rounds = 18,
				windowSeconds = 180,
				revealSeconds = 8,
				soloTarget = 48,
				policiesEnabled = {
					"Wage",
					"TaxWorking",
					"TaxMiddle",
					"TaxCapitalist",
					"PublicServices",
					"Tariff",
					"StrikeRights",
				},
				infoMode = "fog",
				eventsEnabled = true,
				eventsForecast = false,
				collapseEnabled = true,
				hints = "none",
				startResourceMultiplier = 0.85,
				needsMultiplier = 1.15,
				botSuggestions = false,
			},
		}
		for _, name in Types.DIFFICULTIES do
			local entry = (Difficulty :: any)[name] :: any
			local exp = EXPECTED[name :: any] :: any
			for field in exp do
				if field ~= "policiesEnabled" then
					Lib.eq(entry[field], exp[field], `Difficulty.{name}.{field}`)
				end
			end
			expectList(
				entry.policiesEnabled,
				exp.policiesEnabled,
				`Difficulty.{name}.policiesEnabled`
			)
			for _, policyId in entry.policiesEnabled do
				Lib.truthy(
					table.find(Types.POLICY_IDS, policyId) ~= nil,
					`policiesEnabled entry must be a PolicyId ({name})`
				)
			end
		end
	end)

	Lib.test("Events: schedule 3/3 and the six specs of section 16", function()
		Lib.eq(Events.schedule.everyDays, 3, "one event every 3 Days")
		Lib.eq(Events.schedule.startDay, 3, "starting Day 3")
		local SPEC_IDS =
			{ "HarvestFailure", "ExportBoom", "Pandemic", "Recession", "EducationGrant", "Scandal" }
		local count = 0
		for _ in Events.specs do
			count += 1
		end
		Lib.eq(count, #SPEC_IDS, "exactly six V2 events")
		for _, id in SPEC_IDS do
			local spec = (Events.specs :: any)[id] :: any
			Lib.truthy(spec ~= nil, `Events.specs must have {id}`)
			Lib.truthy(spec.name ~= nil and spec.effect ~= nil, `{id} carries name and effect text`)
		end
		Lib.eq(Events.specs.HarvestFailure.name, "Harvest Failure")
		Lib.eq(Events.specs.EducationGrant.name, "Education Grant")
		Lib.eq(Events.specs.Scandal.name, "Scandal")
	end)

	Lib.test("config roots are frozen like the Types mirrors", function()
		-- The guarantee is table-level: the returned root rejects new keys;
		-- nested records are constants by convention (StateFactory copies them,
		-- nothing in M1 writes config data at runtime).
		Lib.eq(
			pcall(function()
				Classes.bogus = {}
			end),
			false,
			"Classes must be read-only at the root"
		)
		Lib.eq(
			pcall(function()
				Difficulty.bogus = Difficulty.Easy
			end),
			false,
			"Difficulty must be read-only at the root"
		)
	end)
end

return M
