--!nocheck
-- BillsStep tests (M3-T3; GAME_DESIGN 7.3, R3): every live bill is tallied,
-- the committed Influence is spent, a passing bill changes its policy track
-- immediately, and each of the seven policy tracks has an effect that the
-- same Day's resolution shows (Wage in the production, the taxes in the tax
-- step, PublicServices in the distribution, the Tariff in the market, the
-- StrikeRights in the strike penalty). Runs the real step and the real
-- pipeline through tests/loader.luau.

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
	print("bills step")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local Rng = Loader.require(shared.Game.Rng)
	local Match = Loader.require(shared.Game.Match)
	local Bills = Loader.require(shared.Game.Ops.Bills)

	local function newMatch(difficulty: string?): any
		return Match.new(
			StateFactory.create(difficulty or "Normal", SEATS, 41),
			RuleSet.new(difficulty or "Normal"),
			Rng.new(41)
		)
	end

	-- A bill that passes: the State proposes (free), Working votes yes with
	-- its 4 base votes plus 1 Influence = the quorum of 5.
	local function passBill(match: any, policyId: string, level: number): any
		local state = match:state()
		local bill = Bills.propose(state, "State", policyId, level, 60)
		Lib.truthy(bill ~= nil, `the bill on {policyId} was accepted`)
		state.drafts.Working.votes[bill.id] = { side = "yes", influence = 1 }
		return bill
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

	Lib.test("a Wage bill pays the new wage the same Day (7.3, 6.4)", function()
		local match = newMatch()
		match:state().drafts.Working.assign["Farm-1"] = 2
		passBill(match, "Wage", 3)
		local state = resolve(match)
		-- 2 staffed slots at the new wage of 3 instead of 2
		Lib.eq(state.classes.Middle.money, 19, "25 - 2 x 3")
		Lib.eq(state.classes.Working.money, 16, "10 + 6 wages")
		Lib.truthy(hasLog(state, "Middle paid 6 Money in wages for 2 slot(s)"), "wage log")
		Lib.truthy(hasLog(state, "Wage is now level 3"), "bill log")
	end)

	Lib.test("a TaxWorking bill taxes the wages the new rate (7.3, 6.7)", function()
		local match = newMatch()
		local state = match:state()
		state.drafts.Working.assign["Farm-1"] = 2
		state.drafts.Working.assign["Farm-2"] = 1
		-- TaxWorking has 4 levels, so it moves by one step: 1 -> 2 (20%)
		passBill(match, "TaxWorking", 2)
		local after = resolve(match)
		-- 6 wages at 20% -> floor(1.2) = 1
		Lib.eq(after.classes.Working.money, 15, "10 + 6 wages - 1 tax")
		Lib.eq(after.classes.State.money, 31, "State received the tax")
		Lib.truthy(hasLog(after, "TaxWorking is now level 2"), "bill log")
	end)

	Lib.test("a TaxMiddle bill taxes the sales revenue the new rate (7.3, 6.7)", function()
		local match = newMatch()
		local state = match:state()
		state.drafts.Middle.market.sell["food"] = 2 -- 4 Money
		state.drafts.Middle.market.sell["education"] = 1 -- 4 Money
		passBill(match, "TaxMiddle", 2)
		local after = resolve(match)
		-- 8 revenue at 20% -> floor(1.6) = 1
		Lib.eq(after.classes.Middle.money, 32, "25 + 8 - 1 tax")
		Lib.eq(after.classes.State.money, 31, "State received the tax")
	end)

	Lib.test("a TaxCapitalist bill taxes the sales revenue the new rate (7.3, 6.7)", function()
		local match = newMatch()
		local state = match:state()
		state.drafts.Capitalist.market.sell["goods"] = 2 -- 6 Money
		state.drafts.Capitalist.market.sell["education"] = 1 -- 4 Money
		passBill(match, "TaxCapitalist", 2)
		local after = resolve(match)
		-- 10 revenue at 20% -> floor(2) = 2
		Lib.eq(after.classes.Capitalist.money, 58, "50 + 10 - 2 tax")
		Lib.eq(after.classes.State.money, 32, "State received the tax")
	end)

	Lib.test(
		"a PublicServices bill distributes the State's stock the same Day (7.3, 6.8)",
		function()
			local match = newMatch()
			match:state().classes.State.stock.health = 3 -- fixture
			passBill(match, "PublicServices", 1)
			local state = resolve(match)
			-- Universal mode: Working's unmet Health (needs 4, has 1) takes 3
			Lib.eq(state.classes.State.stock.health, 0, "the pool was handed out")
			Lib.truthy(
				hasLog(state, "State gave Working 3 Health (free public services)"),
				"distribution log"
			)
			Lib.truthy(hasLog(state, "PublicServices is now level 1"), "bill log")
		end
	)

	Lib.test("a Tariff bill raises the import price the same Day (7.3, 6.6)", function()
		local match = newMatch()
		match:state().drafts.Middle.market.buy["goods"] = 2
		passBill(match, "Tariff", 2)
		local state = resolve(match)
		-- import price 6 + tariff 2 = 8 per unit, 2 units -> 16
		Lib.eq(state.classes.Middle.money, 9, "25 - 16")
		Lib.eq(state.classes.State.money, 34, "State collected the tariff")
		Lib.truthy(
			hasLog(state, "Middle bought 2 Goods for 16 Money (incl. 4 Money tariff)"),
			"market log"
		)
	end)

	Lib.test("a StrikeRights bill outlaws the strike the same Day (7.3, 6.5)", function()
		local match = newMatch()
		local state = match:state()
		state.drafts.Working.strike = { target = "Capitalist" }
		state.drafts.Working.assign["Factory-1"] = 2
		passBill(match, "StrikeRights", 0)
		local after = resolve(match)
		-- the strike idles the Capitalist's line: no wages, no output (the
		-- 2 starting Goods are eaten by the upkeep either way; without the
		-- strike the line would have produced 4 more)
		Lib.eq(after.classes.Capitalist.money, 50, "no wages for the struck line")
		Lib.eq(after.classes.Capitalist.stock.goods, 0, "no output")
		-- 7 unmet units and the outlawed strike: 60 - 7 - 1
		Lib.eq(after.stability, 52, "the strike costs stability")
		Lib.truthy(hasLog(after, "Working's strike idles Capitalist: 1"), "strike log")
		Lib.truthy(hasLog(after, "StrikeRights is now level 0"), "bill log")
	end)

	Lib.test("the committed Influence is spent even when the bill fails (7.3)", function()
		local match = newMatch()
		local state = match:state()
		local bill = Bills.propose(state, "State", "Tariff", 1, 60)
		state.drafts.Working.votes[bill.id] = { side = "no", influence = 2 }
		local after = resolve(match)
		-- Working: 3 - 2 spent + 3 income = 4
		Lib.eq(after.classes.Working.influence, 4, "the vote cost Influence")
		Lib.truthy(hasLog(after, "Working spent 2 Influence on its vote"), "spend log")
		Lib.truthy(hasLog(after, "The bill on Tariff failed (0 for, 6 against"), "failure log")
		Lib.eq(after.policies.Tariff, 0, "the track did not change")
	end)

	Lib.test("the bills are resolved and cleared after the Day (7.3)", function()
		local match = newMatch()
		passBill(match, "Tariff", 1)
		local state = resolve(match)
		Lib.eq(#state.bills, 0, "no live bills left")
		Lib.eq(state.policies.Tariff, 1, "the track changed")
	end)

	Lib.test("a disabled policy cannot be proposed on Easy (7.2)", function()
		local match = newMatch("Easy")
		local state = match:state()
		local bill, reason = Bills.propose(state, "State", "TaxWorking", 2, 60)
		Lib.eq(bill, nil, "refused")
		Lib.eq(reason, "the TaxWorking track is not active in this match", "reason")
		local after = resolve(match)
		Lib.eq(after.policies.TaxWorking, nil, "the track is still not active")
	end)
end

return M
