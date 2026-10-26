--!nocheck
-- Bot heuristics (M9-T2, GAME_DESIGN 15): the four class strategies chase
-- their VP criteria, buy their needs, vote by class interest and accept a
-- trade only when its value beats the counterparty's reputation discount.
-- The last test runs a bots-only match through all twelve Days. Everything
-- comes from the real modules through tests/loader.luau.

local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

local SEATS: { [string]: { string } } = {
	Working = { "Bot-Working" },
	Middle = { "Bot-Middle" },
	Capitalist = { "Bot-Capitalist" },
	State = { "Bot-State" },
}

function M.run()
	print("bot heuristics")
	local root = Loader.mount("src")
	local Types = Loader.require(root.shared.Game.Types)
	local StateFactory = Loader.require(root.shared.Game.State.StateFactory)
	local RuleSet = Loader.require(root.shared.Game.RuleSet)
	local Rng = Loader.require(root.shared.Game.Rng)
	local Match = Loader.require(root.shared.Game.Match)
	local PlayerViewBuilder = Loader.require(root.shared.Game.Behaviors.InfoModes.PlayerViewBuilder)
	local BotStrategy = Loader.require(root.server.Services.Bots.BotStrategy)
	local WorkingBot = Loader.require(root.server.Services.Bots.WorkingBot)
	local MiddleBot = Loader.require(root.server.Services.Bots.MiddleBot)
	local CapitalistBot = Loader.require(root.server.Services.Bots.CapitalistBot)
	local StateBot = Loader.require(root.server.Services.Bots.StateBot)
	local BotService = Loader.require(root.server.Services.BotService)

	local function newState(difficulty: string, seed: number): any
		return StateFactory.create(difficulty, SEATS, seed)
	end

	local function viewFor(state: any, difficulty: string, classId: string): any
		return PlayerViewBuilder.build(state, RuleSet.new(difficulty), classId)
	end

	local function decide(
		bot: any,
		state: any,
		difficulty: string,
		classId: string,
		seed: number
	): any
		return bot:decide(viewFor(state, difficulty, classId), { rng = Rng.new(seed) })
	end

	Lib.test("Working fills slots and buys the food and health its workers need", function()
		local state = newState("Normal", 41)
		local draft = decide(WorkingBot.new(), state, "Normal", "Working", 41)

		Lib.truthy(next(draft.assign) ~= nil, "workers are assigned")
		Lib.truthy((draft.market.buy.food or 0) > 0, "the Food gap is bought")
		Lib.truthy((draft.market.buy.health or 0) > 0, "the Health gap is bought")
		Lib.eq(draft.build, nil, "Working cannot build")
	end)

	Lib.test("Middle builds toward five lines and keeps its Education VP stock", function()
		local state = newState("Normal", 41)
		local draft = decide(MiddleBot.new(), state, "Normal", "Middle", 41)

		Lib.truthy(draft.build ~= nil, "Middle builds a line")
		Lib.eq(draft.build.lineType, "School", "Education is below the VP target")
		Lib.truthy(next(draft.openSlots) ~= nil, "Middle opens its lines")
		Lib.eq(draft.market.sell.education, nil, "Education is kept for the VP criterion")
	end)

	Lib.test("Capitalist builds Farms toward the target and opens its lines", function()
		local state = newState("Normal", 41)
		local draft = decide(CapitalistBot.new(), state, "Normal", "Capitalist", 41)

		Lib.truthy(draft.build ~= nil, "Capitalist builds a line")
		Lib.eq(draft.build.lineType, "Farm", "the Farm target is not met")
		Lib.truthy(next(draft.openSlots) ~= nil, "Capitalist opens its lines")
	end)

	Lib.test("State builds a Clinic for public staffing and opens its lines", function()
		local state = newState("Normal", 41)
		local draft = decide(StateBot.new(), state, "Normal", "State", 41)

		Lib.truthy(draft.build ~= nil, "State builds a line")
		Lib.eq(draft.build.lineType, "Clinic", "Health is below the public reserve")
		Lib.truthy(next(draft.openSlots) ~= nil, "State opens its lines")
	end)

	Lib.test("a bill is voted by class interest without committing Influence", function()
		local state = newState("Normal", 41)
		state.bills = {
			{
				id = "Bill-1",
				policyId = "Wage",
				level = 3,
				proposer = "State",
				proposedDay = 1,
			},
		}

		local workingDraft = BotStrategy.emptyDraft()
		BotStrategy.vote(viewFor(state, "Normal", "Working"), workingDraft)
		Lib.eq(workingDraft.votes["Bill-1"].side, "yes", "Working wants a higher Wage")
		Lib.eq(workingDraft.votes["Bill-1"].influence, 0, "v1 spends no Influence")

		local capitalistDraft = BotStrategy.emptyDraft()
		BotStrategy.vote(viewFor(state, "Normal", "Capitalist"), capitalistDraft)
		Lib.eq(capitalistDraft.votes["Bill-1"].side, "no", "Capitalist wants a lower Wage")
		Lib.eq(capitalistDraft.votes["Bill-1"].influence, 0, "v1 spends no Influence")
	end)

	Lib.test("trade acceptance weighs value and the counterparty's Reputation", function()
		local state = newState("Normal", 41)
		local view = viewFor(state, "Normal", "Capitalist")

		local function offer(giveFood: number, wantMoney: number): any
			return {
				id = "Trade-1",
				from = "State",
				to = "Capitalist",
				give = { Food = giveFood },
				want = { Money = wantMoney },
				promises = {},
				expiresAt = 999,
			}
		end

		view.reputation.State = { kept = 0, broken = 0 }
		Lib.eq(
			BotStrategy.acceptTrade(view, offer(4, 16), nil),
			true,
			"a neutral, fair-value trade is accepted"
		)
		Lib.eq(
			BotStrategy.acceptTrade(view, offer(4, 20), nil),
			false,
			"a neutral, value-losing trade is refused"
		)
		Lib.eq(
			BotStrategy.acceptTrade(view, offer(100, 100), nil),
			false,
			"a trade the bot cannot afford is refused"
		)

		view.reputation.State = { kept = 0, broken = 3 }
		Lib.eq(
			BotStrategy.acceptTrade(view, offer(4, 16), nil),
			false,
			"low trust demands a premium"
		)
		Lib.eq(
			BotStrategy.acceptTrade(view, offer(7, 20), nil),
			true,
			"the premium is enough for the low-trust trade"
		)

		view.reputation.State = { kept = 3, broken = 0 }
		Lib.eq(
			BotStrategy.acceptTrade(view, offer(4, 20), nil),
			true,
			"high trust accepts a thinner margin"
		)
	end)

	Lib.test("a bots-only match runs 12 Days without errors", function()
		local seed = 41
		local match = Match.new(
			StateFactory.create("Normal", SEATS, seed),
			RuleSet.new("Normal"),
			Rng.new(seed)
		)
		local service = BotService.new(seed)
		local bots = { "Working", "Middle", "Capitalist", "State" }

		for day = 1, 12 do
			local state = match:state()
			state.phase = "Window"
			local played = service:playWindow(match, bots)
			Lib.eq(#played, 4, `every bot planned on Day {day}`)
			match:resolveDay(match:rng())
			if match:state().victory ~= nil then
				break
			end
		end

		local finalState = match:state()
		Lib.eq(finalState.day, 12, "the match reached the final Day")
		Lib.truthy(finalState.victory ~= nil, "the final-Day comparison decided")
		Lib.eq(finalState.victory.kind, "final", "the match ended by the final-Day comparison")
		Lib.truthy(#finalState.eventLog > 0, "the match produced the Day log")
	end)
end

return M
