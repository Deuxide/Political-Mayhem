--!nocheck
-- Scoring tests (M5-T1; GAME_DESIGN 11.1, R12): one test per VP criterion and
-- the per-class Day cap. Each test starts from a state where no criterion
-- pays, turns exactly one condition on, and asserts the class's VP plus the
-- report line naming the criterion. Runs the real step on factory states via
-- tests/loader.luau.

local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

local SEATS: { [string]: { string } } = {
	Working = { "Seat-Working" },
	Middle = { "Seat-Middle" },
	Capitalist = { "Seat-Capitalist" },
	State = { "Seat-State" },
}

local CLASS_IDS = { "Working", "Middle", "Capitalist", "State" }

function M.run()
	print("scoring step")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local ScoringStep = Loader.require(shared.Game.Steps.Scoring)

	local function fresh(): any
		return StateFactory.create("Normal", SEATS, 41)
	end

	local function makeScratch(): any
		return {
			wagesReceived = {},
			salesRevenue = {},
			unpaidSlots = 0,
			employedWorkers = 0,
			startMoney = {},
			unmetByClass = {},
			passedBills = {},
		}
	end

	-- A state where no criterion of any class pays: Stability below both
	-- State tiers, Wage below Medium, TaxCapitalist above 1. Education 1,
	-- four Middle lines, no income — the factory defaults already leave the
	-- rest below the bar.
	local function quiet(): any
		local state = fresh()
		state.stability = 50
		state.policies.Wage = 1
		state.policies.TaxCapitalist = 2
		return state
	end

	-- The matching scratch: every class has one unmet need and started the
	-- Day one Money above its wallet, so "needs met" and "money not
	-- decreasing" are both false until a test turns them on.
	local function quietScratch(state: any): any
		local scratch = makeScratch()
		for _, classId in CLASS_IDS do
			scratch.unmetByClass[classId] = 1
			scratch.startMoney[classId] = state.classes[classId].money + 1
		end
		return scratch
	end

	local function score(state: any, scratch: any): any
		ScoringStep.new():run(state, {
			rng = Rng.new(41),
			ruleSet = RuleSet.new("Normal"),
			scratch = scratch,
		})
		return state
	end

	local function logOf(state: any, classId: string): string?
		for _, entry in state.eventLog do
			if string.find(entry.text, `{classId} gained `, 1, true) == 1 then
				return entry.text
			end
		end
		return nil
	end

	local function lineIds(text: string): string
		return string.match(text, "%((.+)%)") or ""
	end

	Lib.test("needsMet: every need covered pays 1 VP (11.1)", function()
		local state = quiet()
		local scratch = quietScratch(state)
		scratch.unmetByClass.Working = 0
		scratch.unmetByClass.Middle = 0
		score(state, scratch)
		Lib.eq(state.classes.Working.vp, 1, "Working needsMet")
		Lib.eq(state.classes.Middle.vp, 1, "Middle needsMet")
		Lib.eq(lineIds(logOf(state, "Middle")), "needsMet", "Middle report names the criterion")
	end)

	Lib.test("needsMet: one unmet unit pays nothing (11.1)", function()
		local state = quiet()
		score(state, quietScratch(state))
		Lib.eq(state.classes.Middle.vp, 0, "no VP with an unmet need")
		Lib.eq(logOf(state, "Middle"), nil, "no report line without VP")
	end)

	Lib.test("employmentAtLeast: 75 percent of the workers is the bar (11.1)", function()
		local state = quiet()
		local scratch = quietScratch(state)
		scratch.employedWorkers = 12 -- 12 / 16 workers = 0.75
		score(state, scratch)
		Lib.eq(state.classes.Working.vp, 1, "12 of 16 employed")
		Lib.eq(lineIds(logOf(state, "Working")), "employmentAtLeast", "criterion named")

		local below = quiet()
		local belowScratch = quietScratch(below)
		belowScratch.employedWorkers = 11 -- 0.6875
		score(below, belowScratch)
		Lib.eq(below.classes.Working.vp, 0, "11 of 16 is below the bar")
	end)

	Lib.test("wageAtLeast: Wage level 2 (Medium) is the bar (11.1)", function()
		local state = quiet()
		state.policies.Wage = 2
		score(state, quietScratch(state))
		Lib.eq(state.classes.Working.vp, 1, "Medium wage pays")

		local low = quiet()
		score(low, quietScratch(low))
		Lib.eq(low.classes.Working.vp, 0, "Low wage pays nothing")
	end)

	Lib.test("ownBillPassed: only the proposer scores (11.1)", function()
		local state = quiet()
		local scratch = quietScratch(state)
		scratch.passedBills = {
			{ proposer = "Working", policyId = "Tariff", level = 1 },
			{ proposer = "Capitalist", policyId = "Wage", level = 1 },
		}
		score(state, scratch)
		Lib.eq(state.classes.Working.vp, 1, "Working proposed a passing bill")
		Lib.eq(state.classes.Capitalist.vp, 0, "Capitalist has no such criterion")

		local other = quiet()
		local otherScratch = quietScratch(other)
		otherScratch.passedBills = { { proposer = "Middle", policyId = "Tariff", level = 1 } }
		score(other, otherScratch)
		Lib.eq(other.classes.Working.vp, 0, "someone else's bill does not pay")
	end)

	Lib.test("educationStockAtLeast: 2 after Upkeep is the bar (11.1)", function()
		local state = quiet()
		state.classes.Middle.stock.education = 2
		score(state, quietScratch(state))
		Lib.eq(state.classes.Middle.vp, 1, "stock 2 pays")

		local one = quiet()
		one.classes.Middle.stock.education = 1
		score(one, quietScratch(one))
		Lib.eq(one.classes.Middle.vp, 0, "stock 1 pays nothing")
	end)

	Lib.test("moneyGainAtLeast: 5 gained this Day is the bar (11.1)", function()
		local state = quiet()
		local scratch = quietScratch(state)
		scratch.salesRevenue.Middle = 5
		score(state, scratch)
		Lib.eq(state.classes.Middle.vp, 1, "5 gained pays")

		local four = quiet()
		local fourScratch = quietScratch(four)
		fourScratch.salesRevenue.Middle = 4
		score(four, fourScratch)
		Lib.eq(four.classes.Middle.vp, 0, "4 gained pays nothing")
	end)

	Lib.test("moneyGain works from income, not transfers (11.1)", function()
		-- a transfer changes the wallet but is not "gained this Day"
		local state = quiet()
		local scratch = quietScratch(state)
		scratch.salesRevenue.Middle = 4
		scratch.wagesReceived.Middle = 0
		state.classes.Middle.money += 10 -- a trade/transfer landed
		score(state, scratch)
		Lib.eq(state.classes.Middle.vp, 0, "transfers are not income")
	end)

	Lib.test("ownsLinesAtLeast: 5 lines is the bar (11.1)", function()
		local state = quiet()
		state.lines["Farm-3"] = {
			id = "Farm-3",
			type = "Farm",
			owner = "Middle",
			openSlots = 2,
			builtOnDay = 0,
			assigned = 0,
		}
		score(state, quietScratch(state))
		Lib.eq(state.classes.Middle.vp, 1, "5 lines pay")

		local four = quiet()
		score(four, quietScratch(four))
		Lib.eq(four.classes.Middle.vp, 0, "4 lines pay nothing")
	end)

	Lib.test("moneyGainScaled: floor(gain / 8), capped at 3 (11.1)", function()
		local state = quiet()
		local scratch = quietScratch(state)
		scratch.salesRevenue.Capitalist = 24
		score(state, scratch)
		Lib.eq(state.classes.Capitalist.vp, 3, "24 gained -> 3 VP")

		local huge = quiet()
		local hugeScratch = quietScratch(huge)
		hugeScratch.salesRevenue.Capitalist = 40 -- raw 5, capped at 3
		score(huge, hugeScratch)
		Lib.eq(huge.classes.Capitalist.vp, 3, "the scale caps at 3")

		local seven = quiet()
		local sevenScratch = quietScratch(seven)
		sevenScratch.salesRevenue.Capitalist = 7
		score(seven, sevenScratch)
		Lib.eq(seven.classes.Capitalist.vp, 0, "7 gained is below the divisor")
	end)

	Lib.test("taxCapitalistAtMost: level 1 is the bar (11.1)", function()
		local state = quiet()
		state.policies.TaxCapitalist = 1
		score(state, quietScratch(state))
		Lib.eq(state.classes.Capitalist.vp, 1, "level 1 pays")

		local two = quiet()
		score(two, quietScratch(two))
		Lib.eq(two.classes.Capitalist.vp, 0, "level 2 pays nothing")

		-- a track the difficulty disabled is absent and reads as 0 (D-041)
		local disabled = quiet()
		disabled.policies.TaxCapitalist = nil
		score(disabled, quietScratch(disabled))
		Lib.eq(disabled.classes.Capitalist.vp, 1, "a disabled track reads as 0")
	end)

	Lib.test("moneyNotDecreasing: non-negative and not lower than the Day began (11.1)", function()
		local state = quiet()
		local scratch = quietScratch(state)
		scratch.startMoney.State = state.classes.State.money
		score(state, scratch)
		Lib.eq(state.classes.State.vp, 1, "unchanged Money pays")

		local down = quiet()
		local downScratch = quietScratch(down)
		downScratch.startMoney.State = down.classes.State.money + 1
		score(down, downScratch)
		Lib.eq(down.classes.State.vp, 0, "a falling wallet pays nothing")

		local negative = quiet()
		negative.classes.State.money = -1
		local negativeScratch = quietScratch(negative)
		negativeScratch.startMoney.State = -1
		score(negative, negativeScratch)
		Lib.eq(negative.classes.State.vp, 0, "negative Money pays nothing")
	end)

	Lib.test("stabilityAtLeast: 60 and 80 are separate tiers (11.1)", function()
		local sixty = quiet()
		sixty.stability = 60
		score(sixty, quietScratch(sixty))
		Lib.eq(sixty.classes.State.vp, 1, "60 pays one tier")

		local eighty = quiet()
		eighty.stability = 80
		score(eighty, quietScratch(eighty))
		Lib.eq(eighty.classes.State.vp, 2, "80 pays both tiers")
	end)

	Lib.test("publicStaffingAtLeast: 75 percent of the State's open slots (11.1)", function()
		local state = quiet()
		-- the State's public lines: 2 open slots each (Clinic-2, School-2)
		local publicLines = {}
		for _, line in state.lines do
			if line.owner == "State" then
				table.insert(publicLines, line)
			end
		end
		Lib.eq(#publicLines, 2, "two public lines")
		publicLines[1].assigned = 2
		publicLines[2].assigned = 1 -- 3 / 4 = 0.75
		score(state, quietScratch(state))
		Lib.eq(state.classes.State.vp, 1, "3 of 4 slots staffed")

		local low = quiet()
		for _, line in low.lines do
			if line.owner == "State" then
				line.assigned = 1
			end
		end -- 2 / 4
		score(low, quietScratch(low))
		Lib.eq(low.classes.State.vp, 0, "2 of 4 slots is below the bar")
	end)

	Lib.test("a class never scores more than 4 VP in one Day (11.1)", function()
		local state = quiet()
		state.policies.TaxCapitalist = 1
		local scratch = quietScratch(state)
		scratch.salesRevenue.Capitalist = 64 -- raw 8, cap 3; +1 tax = 4
		score(state, scratch)
		Lib.eq(state.classes.Capitalist.vp, 4, "3 + 1 = 4, not 9")
		Lib.contains(
			logOf(state, "Capitalist") or "",
			"gained 4 VP",
			"report states the capped total"
		)
	end)

	Lib.test("the four criteria of a class can all pay (11.1)", function()
		local state = quiet()
		state.policies.Wage = 2
		local scratch = quietScratch(state)
		scratch.unmetByClass.Working = 0
		scratch.employedWorkers = 16
		scratch.passedBills = { { proposer = "Working", policyId = "Wage", level = 3 } }
		score(state, scratch)
		Lib.eq(state.classes.Working.vp, 4, "needs + employment + wage + bill")
	end)
end

return M
