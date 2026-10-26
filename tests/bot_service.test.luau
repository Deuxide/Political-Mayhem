--!nocheck
-- Bot framework (M9-T1, GAME_DESIGN 15): a bot receives exactly the
-- PlayerView a human in that seat would receive and a per-bot RNG; its draft
-- goes through the same DraftRules clamp as a human's Draft_Update. The test
-- uses the real BotService, PlayerViewBuilder, DraftRules and the four class
-- strategies through tests/loader.luau.

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
	print("bot service")
	local root = Loader.mount("src")
	local Types = Loader.require(root.shared.Game.Types)
	local StateFactory = Loader.require(root.shared.Game.State.StateFactory)
	local RuleSet = Loader.require(root.shared.Game.RuleSet)
	local Rng = Loader.require(root.shared.Game.Rng)
	local Match = Loader.require(root.shared.Game.Match)
	local PlayerViewBuilder = Loader.require(root.shared.Game.Behaviors.InfoModes.PlayerViewBuilder)
	local ConfigLines = Loader.require(root.shared.Config.Lines)
	local ConfigMarket = Loader.require(root.shared.Config.Market)
	local BotStrategy = Loader.require(root.server.Services.Bots.BotStrategy)
	local WorkingBot = Loader.require(root.server.Services.Bots.WorkingBot)
	local MiddleBot = Loader.require(root.server.Services.Bots.MiddleBot)
	local CapitalistBot = Loader.require(root.server.Services.Bots.CapitalistBot)
	local StateBot = Loader.require(root.server.Services.Bots.StateBot)
	local BotService = Loader.require(root.server.Services.BotService)

	-- A test strategy that records the view and RNG draw it was given, then
	-- returns a deliberately unsafe draft. BotService must clamp it exactly
	-- as it clamps a human's.
	local SpyBot = setmetatable({}, { __index = BotStrategy })
	SpyBot.__index = SpyBot

	function SpyBot.new(): any
		return setmetatable(BotStrategy.new(), SpyBot)
	end

	function SpyBot.decide(self: any, view: any, ctx: any): any
		self.view = view
		self.draw = ctx.rng:int(1, 1000000)
		return {
			sequence = 0,
			locked = false,
			openSlots = { ["Farm-1"] = 999, ["Nope"] = 1 },
			assign = {},
			market = { sell = { food = 999 }, buy = {} },
			votes = {},
		}
	end

	local function newMatch(difficulty: string, seed: number): any
		local state = StateFactory.create(difficulty, SEATS, seed)
		local match = Match.new(state, RuleSet.new(difficulty), Rng.new(seed))
		return match, state
	end

	local function keysOf(value: any): string
		local keys = {}
		for key in value do
			table.insert(keys, key)
		end
		table.sort(keys)
		return table.concat(keys, ",")
	end

	local function drawWith(seed: number, classId: string): number
		local spy = SpyBot.new()
		local strategies = {}
		strategies[classId] = spy
		local service = BotService.new(seed, strategies)
		local match = newMatch("Normal", seed)
		service:run(match, classId)
		return spy.draw
	end

	Lib.test("a bot cannot read any field a human couldn't", function()
		local match, state = newMatch("Extreme", 41)
		local spy = SpyBot.new()
		local service = BotService.new(41, { Working = spy })
		local draft, reason = service:run(match, "Working")

		Lib.truthy(draft ~= nil, "the bot acted")
		Lib.eq(reason, "", "no refusal")
		local botView = spy.view
		local humanView = PlayerViewBuilder.build(state, RuleSet.new("Extreme"), "Working")

		Lib.eq(botView.viewer, "Working", "the bot sees its own seat")
		Lib.eq(keysOf(botView), keysOf(humanView), "the same top-level fields as a human")
		Lib.eq(
			keysOf(botView.others.Capitalist),
			keysOf(humanView.others.Capitalist),
			"the same public fields of another class"
		)
		Lib.eq(botView.others.Capitalist.money, nil, "fog hides Money from the bot")
		Lib.eq(botView.others.Capitalist.influence, nil, "fog hides Influence from the bot")
		Lib.eq(next(botView.others.Capitalist.stock), nil, "fog hides the other stocks")
		Lib.truthy(botView.own.money ~= nil, "the bot sees its own Money")
		Lib.eq(botView.classes, nil, "no raw MatchState classes")
		Lib.eq(botView.seed, nil, "no match seed")
		Lib.eq(botView.drafts, nil, "no other drafts")
	end)

	Lib.test("the bot's draft goes through the same clamp as a human's", function()
		local match, state = newMatch("Normal", 41)
		state.drafts.Working.sequence = 5
		state.drafts.Working.locked = true
		local service = BotService.new(41, { Working = SpyBot.new() })
		local draft, reason = service:run(match, "Working")

		Lib.truthy(draft ~= nil, "the bot acted")
		Lib.eq(reason, "", "no refusal")
		Lib.eq(draft.sequence, 6, "the next sequence, not the bot's 0")
		Lib.eq(draft.locked, true, "the existing lock is preserved")
		Lib.eq(draft.openSlots["Farm-1"], ConfigLines.Farm.slotsMax, "the slot count is capped")
		Lib.eq(draft.openSlots["Nope"], nil, "an unknown line is dropped")
		Lib.eq(draft.market.sell.food, ConfigMarket.volumeCap, "the market volume is capped")
		Lib.eq(state.drafts.Working, draft, "the clamped draft is what the state stores")
	end)

	Lib.test("the per-bot RNG is derived from the match seed", function()
		Lib.eq(drawWith(41, "Working"), drawWith(41, "Working"), "same seed, same bot stream")
		Lib.truthy(
			drawWith(41, "Working") ~= drawWith(42, "Working"),
			"a different seed changes it"
		)
		Lib.truthy(
			drawWith(41, "Working") ~= drawWith(41, "Middle"),
			"each class has its own stream"
		)
	end)

	Lib.test("all four class strategies are registered and return a safe empty draft", function()
		local match = newMatch("Normal", 41)
		local service = BotService.new(41)
		local strategies = {
			Working = WorkingBot,
			Middle = MiddleBot,
			Capitalist = CapitalistBot,
			State = StateBot,
		}
		for _, classId in Types.CLASS_IDS do
			Lib.truthy(strategies[classId] ~= nil, `{classId} has a strategy class`)
			local draft, reason = service:run(match, classId)
			Lib.truthy(draft ~= nil, `{classId} acted`)
			Lib.eq(reason, "", `{classId} was accepted`)
			Lib.eq(draft.sequence, 1, `{classId} sequence`)
			Lib.eq(next(draft.openSlots), nil, `{classId} has no slots`)
			Lib.eq(next(draft.assign), nil, `{classId} has no assignment`)
			Lib.eq(next(draft.votes), nil, `{classId} has no votes`)
		end
	end)

	Lib.test("the abstract base refuses to decide", function()
		local match, state = newMatch("Normal", 41)
		local view = PlayerViewBuilder.build(state, RuleSet.new("Normal"), "Working")
		local base = BotStrategy.new()
		local ok, err = pcall(function()
			return base:decide(view, { rng = Rng.new(1) })
		end)
		Lib.eq(ok, false, "the abstract method raised")
		Lib.contains(
			tostring(err),
			"not implemented: BotStrategy:decide",
			"with the standard wording"
		)
		Lib.truthy(match ~= nil, "the match was built")
	end)

	Lib.test("a bot does not act outside the Window", function()
		local match, state = newMatch("Normal", 41)
		state.phase = "Reveal"
		local service = BotService.new(41, { Working = SpyBot.new() })
		local draft, reason = service:run(match, "Working")
		Lib.eq(draft, nil, "no draft")
		Lib.contains(reason, "Window", "the reason names the Window")
	end)
end

return M
