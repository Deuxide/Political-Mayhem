--!nocheck
-- StateFactory/RuleSet/Match tests (M1-T4): the initial state per difficulty
-- matches GAME_DESIGN 5.2 (with the DECISIONS multiplier semantics) and 12
-- exactly; validation errors behave; the RuleSet answers every flag; the
-- Match facade wires state + RuleSet + Rng.

local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

function M.run()
	print("state factory")
	local shared = Loader.mount("src/shared")
	local Types = Loader.require(shared.Game.Types)
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Match = Loader.require(shared.Game.Match)
	local ConfigClasses = Loader.require(shared.Config.Classes)

	local SEATS: { [string]: { string } } = {
		Working = { "Seat-Working" },
		Middle = { "Seat-Middle" },
		Capitalist = { "Seat-Capitalist" },
		State = { "Seat-State" },
	}

	-- exact starting values (5.2) and the DECISIONS scale application
	local expectedValues = function(
		money: number,
		influence: number,
		food: number,
		goods: number,
		health: number,
		education: number,
		workers: number
	)
		return {
			money = money,
			influence = influence,
			food = food,
			goods = goods,
			health = health,
			education = education,
			workers = workers,
		}
	end

	local CLASS_EXPECTED = {
		Easy = {
			Working = expectedValues(12, 3, 5, 0, 1, 0, 16), -- floor(1.25 x base)
			Middle = expectedValues(31, 2, 2, 1, 1, 1, 0),
			Capitalist = expectedValues(62, 1, 1, 2, 1, 3, 0),
			State = expectedValues(37, 2, 0, 0, 0, 0, 0),
		},
		Normal = {
			Working = expectedValues(10, 3, 4, 0, 1, 0, 16),
			Middle = expectedValues(25, 2, 2, 1, 1, 1, 0),
			Capitalist = expectedValues(50, 1, 1, 2, 1, 3, 0),
			State = expectedValues(30, 2, 0, 0, 0, 0, 0),
		},
		Hard = {
			Working = expectedValues(10, 3, 4, 0, 1, 0, 16),
			Middle = expectedValues(25, 2, 2, 1, 1, 1, 0),
			Capitalist = expectedValues(50, 1, 1, 2, 1, 3, 0),
			State = expectedValues(30, 2, 0, 0, 0, 0, 0),
		},
		Extreme = {
			Working = expectedValues(8, 2, 3, 0, 0, 0, 16), -- floor(0.85 x base)
			Middle = expectedValues(21, 1, 1, 0, 0, 0, 0),
			Capitalist = expectedValues(42, 0, 0, 1, 0, 2, 0),
			State = expectedValues(25, 1, 0, 0, 0, 0, 0),
		},
	}

	local LINE_COUNTS = { Farm = 3, Factory = 3, Clinic = 2, School = 2 }
	local LINE_OWNERS = {
		Farm = { Middle = 2, Capitalist = 1 },
		Factory = { Capitalist = 3 },
		Clinic = { Middle = 1, State = 1 },
		School = { Middle = 1, State = 1 },
	}

	local function create(difficulty: string, seatMap: { [string]: { string } }?)
		return (StateFactory :: any).create(difficulty, seatMap or SEATS, 4242)
	end

	Lib.test("every difficulty's initial state matches 5.2 + 12 exactly", function()
		for _, difficulty in Types.DIFFICULTIES do
			local state = create(difficulty) :: any
			Lib.eq(state.id, `mayhem-4242`, `{difficulty} id is deterministic`)
			Lib.eq(state.seed, 4242, `{difficulty} seed echoed`)
			Lib.eq(state.difficulty, difficulty, `{difficulty} echoed`)
			Lib.eq(state.day, 1, `{difficulty} starts on Day 1`)
			Lib.eq(state.phase, "Window", `{difficulty} starts in the Window`)
			Lib.eq(state.phaseEndsAt, 0, `{difficulty} phase is unscheduled at creation`)
			Lib.eq(state.stability, 60, `{difficulty} starts at stability 60`)
			Lib.eq(state.collapseCounter, 0, `{difficulty} collapse counter 0`)
			Lib.eq(#state.bills, 0, `{difficulty} no live bills`)
			Lib.eq(#state.trades, 0, `{difficulty} no live trades`)
			Lib.eq(#state.promises, 0, `{difficulty} no promises`)
			Lib.eq(#state.alliances, 0, `{difficulty} no alliances`)
			Lib.eq(#state.eventLog, 0, `{difficulty} empty event log`)
			Lib.eq(#state.scheduledEvents, 0, `{difficulty} no scheduled events`)

			for _, classId in Types.CLASS_IDS do
				local classState = state.classes[classId]
				local exp = (CLASS_EXPECTED[difficulty :: any] :: any)[classId]
				Lib.eq(classState.money, exp.money, `{difficulty}.{classId}.money`)
				Lib.eq(classState.influence, exp.influence, `{difficulty}.{classId}.influence`)
				Lib.eq(classState.vp, 0, `{difficulty}.{classId}.vp 0`)
				Lib.eq(classState.workers, exp.workers, `{difficulty}.{classId}.workers unscaled`)
				for _, stockId in Types.STOCK_IDS do
					Lib.eq(
						classState.stock[stockId],
						exp[stockId :: any] :: number,
						`{difficulty}.{classId}.{stockId}`
					)
				end
				Lib.eq(
					classState.seats[1],
					(SEATS :: any)[classId][1],
					`{difficulty}.{classId} holds its seat`
				)
				Lib.eq(#classState.seats, 1, `{difficulty}.{classId} one seat`)
			end

			-- lines: grid owners, deterministic ids, slotsMax openSlots
			local slots = 0
			for lineType, count in LINE_COUNTS do
				local ownerCounts: { [string]: number } = {}
				for n = 1, count :: number do
					local line = state.lines[`{lineType}-{n}`]
					Lib.truthy(line ~= nil, `{difficulty} missing line {lineType}-{n}`)
					local owner = line ~= nil and line.owner or ""
					ownerCounts[owner] = (ownerCounts[owner] or 0) + 1
					Lib.eq(line.openSlots, 2, `{difficulty} {lineType}-{n} opens 2 slots`)
					Lib.eq(line.builtOnDay, 0, `{difficulty} {lineType}-{n} pre-built`)
					Lib.eq(line.assigned, 0, `{difficulty} {lineType}-{n} unassigned`)
					Lib.eq(line.type, lineType, `{difficulty} {lineType}-{n} type`)
					slots += 1
				end
				for owner, expected in (LINE_OWNERS :: any)[lineType] do
					Lib.eq(
						ownerCounts[owner] or 0,
						expected :: number,
						`{difficulty} {lineType} owned by {owner}`
					)
				end
			end
			Lib.eq(slots, 10, `{difficulty} exactly 10 initial lines`)
		end
	end)

	Lib.test("policies hold only enabled tracks, at their defaults", function()
		local easy = create("Easy") :: any
		Lib.eq(easy.policies.Wage, 2, "Easy Wage default Medium")
		Lib.eq(easy.policies.TaxCapitalist, 1, "Easy TaxCapitalist default")
		Lib.eq(easy.policies.PublicServices, 0, "Easy PublicServices default")
		for _, disabled in { "TaxWorking", "TaxMiddle", "Tariff", "StrikeRights" } do
			Lib.truthy(easy.policies[disabled] == nil, `Easy omits disabled track {disabled}`)
		end

		local extreme = create("Extreme") :: any
		for _, policyId in Types.POLICY_IDS do
			Lib.truthy(
				extreme.policies[policyId] ~= nil,
				`Extreme enables every track ({policyId})`
			)
		end
		Lib.eq(extreme.policies.StrikeRights, 1, "Extreme StrikeRights default Allowed")
	end)

	Lib.test("drafts start per section 9 on every difficulty", function()
		for _, difficulty in Types.DIFFICULTIES do
			local state = create(difficulty) :: any
			for _, classId in Types.CLASS_IDS do
				local draft = state.drafts[classId]
				Lib.truthy(draft ~= nil, `{difficulty} has a draft for {classId}`)
				Lib.eq(draft.sequence, 0, `{difficulty}.{classId} draft sequence 0`)
				local openCount, assignCount, voteCount = 0, 0, 0
				for _ in draft.openSlots do
					openCount += 1
				end
				for _ in draft.assign do
					assignCount += 1
				end
				for _ in draft.votes do
					voteCount += 1
				end
				Lib.eq(openCount, 0, `{difficulty}.{classId} openSlots empty`)
				Lib.eq(assignCount, 0, `{difficulty}.{classId} assign empty`)
				Lib.eq(voteCount, 0, `{difficulty}.{classId} votes empty`)
				Lib.truthy(draft.strike == nil, `{difficulty}.{classId} no strike`)
				Lib.truthy(draft.build == nil, `{difficulty}.{classId} no build`)
				Lib.truthy(draft.lobby == nil, `{difficulty}.{classId} no lobby`)
				local sellCount, buyCount = 0, 0
				for _ in draft.market.sell do
					sellCount += 1
				end
				for _ in draft.market.buy do
					buyCount += 1
				end
				Lib.eq(sellCount, 0, `{difficulty}.{classId} market sell empty`)
				Lib.eq(buyCount, 0, `{difficulty}.{classId} market buy empty`)
			end
		end
	end)

	Lib.test("initial states are serializable on every difficulty", function()
		for _, difficulty in Types.DIFFICULTIES do
			local state = create(difficulty) :: any
			local problems = Loader.require(shared.Game.State.assertSerializable).validate(state)
			local count = 0
			for _ in problems do
				count += 1
			end
			Lib.eq(count, 0, `{difficulty} initial state has serialization problems`)
		end
	end)

	Lib.test("unknown difficulty raises at any factory entry", function()
		Lib.truthy(not pcall(function()
			create("Nightmare")
		end), "unknown difficulty must raise")
		Lib.truthy(not pcall(function()
			(RuleSet :: any).new("Nightmare")
		end), "RuleSet with unknown difficulty must raise")
	end)

	Lib.test("seat validation raises on missing, empty, or duplicate seats", function()
		local missing = { Working = { "Seat-1" }, Middle = { "Seat-2" }, Capitalist = { "Seat-3" } }
		Lib.truthy(not pcall(function()
			create("Normal", missing :: any)
		end), "missing State seats must raise")

		local empty =
			{ Working = {}, Middle = { "Seat-2" }, Capitalist = { "Seat-3" }, State = { "Seat-4" } }
		Lib.truthy(not pcall(function()
			create("Normal", empty :: any)
		end), "empty seat list must raise")

		local duplicate = {
			Working = { "Seat-1" },
			Middle = { "Seat-1" },
			Capitalist = { "Seat-3" },
			State = { "Seat-4" },
		}
		Lib.truthy(not pcall(function()
			create("Normal", duplicate :: any)
		end), "seat shared by two classes must raise")
	end)

	Lib.test("RuleSet answers every difficulty flag", function()
		local easy = RuleSet.new("Easy") :: any
		Lib.eq(easy:rounds(), 8, "Easy rounds")
		Lib.eq(easy:windowSeconds(), 90, "Easy window")
		Lib.eq(easy:revealSeconds(), 12, "Easy reveal")
		Lib.eq(easy:soloTarget(), 14, "Easy solo target")
		Lib.eq(easy:infoMode(), "open", "Easy info mode")
		Lib.eq(easy:eventsEnabled(), false, "Easy events off")
		Lib.eq(easy:eventsForecast(), false, "Easy forecast off")
		Lib.eq(easy:collapseEnabled(), false, "Easy collapse off")
		Lib.eq(easy:hints(), "full", "Easy hints")
		Lib.eq(easy:startResourceMultiplier(), 1.25, "Easy multiplier")
		Lib.eq(easy:needsMultiplier(), 0.75, "Easy needs multiplier")
		Lib.eq(easy:botSuggestions(), true, "Easy bot suggestions")
		Lib.truthy(easy:isPolicyEnabled("Wage"), "Easy enables Wage")
		Lib.truthy(easy:isPolicyEnabled("TaxCapitalist"), "Easy enables TaxCapitalist")
		Lib.truthy(easy:isPolicyEnabled("PublicServices"), "Easy enables PublicServices")
		Lib.truthy(not easy:isPolicyEnabled("Tariff"), "Easy disables Tariff")
		Lib.truthy(not easy:isPolicyEnabled("StrikeRights"), "Easy disables StrikeRights")

		local hard = RuleSet.new("Hard") :: any
		Lib.truthy(hard:eventsForecast(), "Hard shows the forecast")
		Lib.truthy(hard:collapseEnabled(), "Hard collapses")
		Lib.eq(hard:infoMode(), "partial", "Hard partial info")
		Lib.truthy(hard:isPolicyEnabled("StrikeRights"), "Hard enables StrikeRights")

		local extreme = RuleSet.new("Extreme") :: any
		Lib.eq(extreme:soloTarget(), 48, "Extreme solo target")
		Lib.eq(extreme:rounds(), 18, "Extreme rounds")
		Lib.truthy(not extreme:eventsForecast(), "Extreme hides the forecast")
		Lib.eq(extreme:startResourceMultiplier(), 0.85, "Extreme multiplier")
		Lib.eq(extreme:needsMultiplier(), 1.15, "Extreme needs multiplier")
		Lib.eq(extreme:infoMode(), "fog", "Extreme fog")
	end)

	Lib.test("Match facade wires state, RuleSet and Rng", function()
		local state = create("Normal") :: any
		local rng = Loader.require(shared.Game.Rng) :: any
		local match = Match.new(state, (RuleSet :: any).new("Normal"), rng.new(4242)) :: any
		Lib.truthy(match:state() == state, "facade holds the state reference")
		Lib.eq(match:ruleSet():rounds(), 12, "facade exposes the RuleSet")
		Lib.truthy(match:rng() ~= nil, "facade exposes the Rng")
		Lib.eq(match:state().difficulty, "Normal", "state reachable through the facade")
	end)

	Lib.test("startStock data integrity: §5.2 numbers are the base for scale", function()
		-- Guards against accidental edits to Config/Classes during scale work:
		-- a Normal match (multiplier 1) must reproduce section 5.2 literally.
		for _, classId in Types.CLASS_IDS do
			local entry = (ConfigClasses.entries :: any)[classId] :: any
			Lib.eq(
				entry.startMoney,
				(CLASS_EXPECTED.Normal)[classId :: any].money,
				`5.2 {classId} money base`
			)
			Lib.eq(
				entry.startInfluence,
				(CLASS_EXPECTED.Normal)[classId :: any].influence,
				`5.2 {classId} influence base`
			)
		end
	end)
end

return M
