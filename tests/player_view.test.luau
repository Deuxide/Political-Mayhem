--!nocheck
-- PlayerViewBuilder + InfoMode tests (M5-T4; GAME_DESIGN 13): each mode hides
-- or tiers exactly the fields the visibility table names, the viewer's own
-- class is full in every mode, hidden fields are absent keys (not a
-- nil-valued sentinel or a placeholder), an allied class's stocks are
-- revealed even in fog, the public data always travels, and the view is a
-- detached plain table. Runs the real builder and the real modes through
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

function M.run()
	print("player view")
	local shared = Loader.mount("src/shared")
	local Types = Loader.require(shared.Game.Types)
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local assertSerializable = Loader.require(shared.Game.State.assertSerializable)
	local PlayerViewBuilder = Loader.require(shared.Game.Behaviors.InfoModes.PlayerViewBuilder)

	local function fresh(difficulty: string): any
		return StateFactory.create(difficulty, SEATS, 41)
	end

	local function build(state: any, difficulty: string, viewer: string): any
		return PlayerViewBuilder.build(state, RuleSet.new(difficulty), viewer)
	end

	local function keysOf(view: any): string
		local keys = {}
		for key in view do
			table.insert(keys, key)
		end
		table.sort(keys)
		return table.concat(keys, ",")
	end

	Lib.test("open: another class is exact in every field (13)", function()
		local state = fresh("Normal")
		local view = build(state, "Normal", "Working")
		local cap = view.others.Capitalist

		Lib.eq(cap.money, 50, "Money")
		Lib.eq(cap.stock.food, 1, "stock food")
		Lib.eq(cap.stock.goods, 2, "stock goods")
		Lib.eq(cap.stock.education, 3, "stock education")
		Lib.eq(cap.influence, 1, "Influence")
		Lib.eq(cap.vp, 0, "VP")
		Lib.eq(keysOf(cap), "influence,lines,money,stock,vp", "every field present")

		-- lines and slot counts, exact and sorted by id
		Lib.eq(#cap.lines, 4, "the Capitalist's four lines")
		Lib.eq(cap.lines[1].id, "Factory-1", "sorted by id")
		Lib.eq(cap.lines[4].id, "Farm-3", "sorted by id")
		Lib.eq(cap.lines[1].openSlots, 2, "slot count")
		Lib.eq(cap.lines[1].owner, "Capitalist", "owner")

		-- the viewer is not an "other"
		Lib.eq(view.others.Working, nil, "the viewer is not in others")
	end)

	Lib.test("the viewer's own needs travel, scaled by the difficulty (5.3, 12)", function()
		local normal = build(fresh("Normal"), "Normal", "Working")
		Lib.eq(normal.rounds, 12, "Normal: the match is 12 Days")
		Lib.eq(normal.needs.food, 8, "Normal: 16 workers need 8 Food")
		Lib.eq(normal.needs.health, 4, "Normal: 16 workers need 4 Health")
		Lib.eq(normal.needs.goods, 0, "Working needs no Goods")
		Lib.eq(normal.needs.education, 0, "Working needs no Education")

		local easy = build(fresh("Easy"), "Easy", "Working")
		Lib.eq(easy.rounds, 8, "Easy: the match is 8 Days")
		Lib.eq(easy.needs.food, 6, "Easy: 0.75 scales 8 down to 6")
		Lib.eq(easy.needs.health, 3, "Easy: 0.75 scales 4 down to 3")

		local extreme = build(fresh("Extreme"), "Extreme", "Working")
		Lib.eq(extreme.rounds, 18, "Extreme: the match is 18 Days")
		Lib.eq(extreme.needs.food, 10, "Extreme: 1.15 rounds 9.2 up")
		Lib.eq(extreme.needs.health, 5, "Extreme: 1.15 rounds 4.6 up")

		local middle = build(fresh("Normal"), "Normal", "Middle")
		Lib.eq(middle.needs.food, 2, "Middle: flat 2 Food")
		Lib.eq(middle.needs.goods, 1, "Middle: flat 1 Goods")

		-- own data: the same in every info mode
		local fog = build(fresh("Extreme"), "Extreme", "Middle")
		Lib.eq(fog.needs.food, 3, "fog hides others, never the own needs")
		Lib.eq(#fog.ownLines, 4, "fog hides others, never the own lines")
	end)

	Lib.test("the viewer's own lines travel, exact in every mode (13)", function()
		local working = build(fresh("Normal"), "Normal", "Working")
		Lib.eq(#working.ownLines, 0, "Working starts with no lines")

		local middle = build(fresh("Normal"), "Normal", "Middle")
		Lib.eq(#middle.ownLines, 4, "the Middle's four lines")
		Lib.eq(middle.ownLines[1].id, "Clinic-1", "sorted by id")
		Lib.eq(middle.ownLines[1].owner, "Middle", "the owner")
		Lib.eq(middle.ownLines[1].openSlots, 2, "the slot count")
	end)

	Lib.test("partial: Money and stocks are tiers, Influence is hidden (13)", function()
		local state = fresh("Hard")
		local view = build(state, "Hard", "Working")
		local cap = view.others.Capitalist

		Lib.eq(cap.money, "High", "50 is High")
		Lib.eq(view.others.Middle.money, "Mid", "25 is Mid")
		Lib.eq(view.others.State.money, "Mid", "30 is Mid")

		Lib.eq(cap.stock.food, "Low", "1 is Low")
		Lib.eq(cap.stock.goods, "Mid", "2 is Mid")
		Lib.eq(cap.stock.health, "Low", "1 is Low")
		Lib.eq(cap.stock.education, "Mid", "3 is Mid")

		Lib.eq(cap.influence, nil, "Influence hidden")
		Lib.eq(keysOf(cap), "lines,money,stock,vp", "no influence key")
		Lib.eq(cap.vp, 0, "VP stays exact")
		Lib.eq(#cap.lines, 4, "lines stay exact")
	end)

	Lib.test(
		"partial: the Money tier boundaries are Low < 15, Mid 15..39, High >= 40 (13)",
		function()
			local state = fresh("Hard")
			local function tierAt(money: number): any
				state.classes.Capitalist.money = money
				return build(state, "Hard", "Working").others.Capitalist.money
			end
			Lib.eq(tierAt(14), "Low", "14")
			Lib.eq(tierAt(15), "Mid", "15")
			Lib.eq(tierAt(39), "Mid", "39")
			Lib.eq(tierAt(40), "High", "40")
		end
	)

	Lib.test(
		"partial: the stock tier boundaries come from Config/Visibility (13, D-071)",
		function()
			local state = fresh("Hard")
			local function tierAt(food: number): any
				state.classes.Capitalist.stock.food = food
				return build(state, "Hard", "Working").others.Capitalist.stock.food
			end
			Lib.eq(tierAt(1), "Low", "1")
			Lib.eq(tierAt(2), "Mid", "2")
			Lib.eq(tierAt(3), "Mid", "3")
			Lib.eq(tierAt(4), "High", "4")
		end
	)

	Lib.test("fog: another class's Money, stocks and Influence are absent (13)", function()
		local state = fresh("Extreme")
		local view = build(state, "Extreme", "Working")
		local cap = view.others.Capitalist

		Lib.eq(cap.money, nil, "Money hidden")
		Lib.eq(cap.influence, nil, "Influence hidden")
		Lib.eq(keysOf(cap), "lines,stock,vp", "only the public fields are keys")
		Lib.eq(next(cap.stock), nil, "not even the stock keys are told")

		Lib.eq(cap.vp, 0, "VP stays exact")
		Lib.eq(#cap.lines, 4, "lines stay exact")
		Lib.eq(cap.lines[1].openSlots, 2, "slot counts stay exact")

		-- the viewer's own class is full in every mode (Extreme scales the start)
		Lib.eq(view.own.money, 8, "own Money")
		Lib.eq(view.own.stock.food, 3, "own stock")
		Lib.eq(view.own.influence, 2, "own Influence")
	end)

	Lib.test("fog: an allied class's stocks are revealed, its Money is not (8.4, 13)", function()
		local state = fresh("Extreme")
		table.insert(state.alliances, {
			id = "Alliance-1",
			members = { "Working", "Capitalist" },
			formedOnDay = 1,
		})

		local view = build(state, "Extreme", "Working")
		local cap = view.others.Capitalist
		Lib.eq(cap.stock.goods, 1, "allied stock goods")
		Lib.eq(cap.stock.education, 2, "allied stock education")
		Lib.eq(cap.money, nil, "8.4 reveals stocks only")
		Lib.eq(cap.influence, nil, "8.4 reveals stocks only")
		Lib.eq(next(view.others.Middle.stock), nil, "a non-allied class stays hidden")

		-- the benefit is mutual
		local other = build(state, "Extreme", "Capitalist")
		Lib.eq(other.others.Working.stock.food, 3, "the other side sees the stocks too")
	end)

	Lib.test("the public data always travels, and the view is detached (13)", function()
		local state = fresh("Extreme")
		table.insert(state.bills, {
			id = "Bill-1",
			policyId = "Wage",
			level = 3,
			proposer = "Working",
			proposedDay = 1,
		})
		state.classes.Working.vp = 7
		state.victory = { kind = "collapse", winners = {}, day = 3 }

		local view = build(state, "Extreme", "Working")
		Lib.eq(view.viewer, "Working", "viewer")
		Lib.eq(view.day, state.day, "Day")
		Lib.eq(view.phase, state.phase, "phase")
		Lib.eq(view.stability, state.stability, "Stability")
		Lib.eq(view.needs.food, 10, "own needs travel")
		Lib.eq(view.policies.Wage, state.policies.Wage, "policies")
		Lib.eq(#view.bills, 1, "live bills")
		Lib.eq(view.bills[1].level, 3, "bill content")
		Lib.eq(view.victory.kind, "collapse", "the victory result")
		Lib.eq(view.others.Capitalist.vp, state.classes.Capitalist.vp, "VP")

		-- a view never aliases the live state
		view.bills[1].level = 99
		Lib.eq(state.bills[1].level, 3, "bill untouched")
		view.policies.Wage = 0
		Lib.eq(state.policies.Wage, 2, "policy untouched")
		view.own.money = 999
		Lib.eq(state.classes.Working.money, 8, "own Money untouched")
		view.others.Capitalist.lines[1].openSlots = 99
		Lib.eq(state.lines["Factory-1"].openSlots, 2, "line untouched")
		view.victory.kind = "solo"
		Lib.eq(state.victory.kind, "collapse", "victory untouched")
	end)

	Lib.test(
		"alliance proposals travel only to the two classes; alliances are public (8.4)",
		function()
			local state = fresh("Normal")
			table.insert(state.allianceProposals, {
				id = "AllianceProposal-1",
				from = "Middle",
				to = "Capitalist",
				proposedDay = 1,
			})
			local middle = build(state, "Normal", "Middle")
			Lib.eq(#middle.allianceProposals, 1, "the proposer sees the proposal")
			Lib.eq(middle.allianceProposals[1].to, "Capitalist", "the recipient")
			local cap = build(state, "Normal", "Capitalist")
			Lib.eq(#cap.allianceProposals, 1, "the recipient sees it too")
			local working = build(state, "Normal", "Working")
			Lib.eq(#working.allianceProposals, 0, "a third class does not")
			local stateView = build(state, "Normal", "State")
			Lib.eq(#stateView.allianceProposals, 0, "the State does not either")

			table.insert(state.alliances, {
				id = "Alliance-1",
				members = { "Middle", "Capitalist" },
				formedOnDay = 1,
			})
			local outsider = build(state, "Normal", "Working")
			Lib.eq(#outsider.alliances, 1, "the active alliance is public")
			Lib.eq(#outsider.allianceProposals, 0, "the proposal stays private")

			middle.allianceProposals[1].to = "State"
			Lib.eq(state.allianceProposals[1].to, "Capitalist", "the view is detached")
		end
	)

	Lib.test("every viewer gets a plain-serializable view in every mode (13)", function()
		for _, difficulty in Types.DIFFICULTIES do
			for _, viewer in Types.CLASS_IDS do
				local view = build(fresh(difficulty), difficulty, viewer)
				assertSerializable.assert(view)
				Lib.eq(view.viewer, viewer, `{difficulty}: viewer`)
				local count = 0
				for _ in view.others do
					count += 1
				end
				Lib.eq(count, 3, `{difficulty}: three other classes`)
			end
		end
	end)

	Lib.test("an unknown info mode fails loudly instead of leaking (13)", function()
		local fakeRuleSet = {
			infoMode = function()
				return "weird"
			end,
		}
		local ok, err = pcall(function()
			PlayerViewBuilder.build(fresh("Normal"), fakeRuleSet, "Working")
		end)
		Lib.eq(ok, false, "build raises")
		Lib.contains(tostring(err), "no strategy for info mode 'weird'", "with the mode name")
	end)
end

return M
