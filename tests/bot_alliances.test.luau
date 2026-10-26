--!nocheck
-- Bot diplomacy (M9-T3, GAME_DESIGN 8.3/8.4): the bots propose, accept and
-- break alliances through the same Alliances Ops as the human handlers, and
-- they honour open VoteYes/NoBreakAlliance promises. The last test runs 20
-- seeded bots-only matches and requires both formations and breaks.

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
	print("bot alliances")
	local root = Loader.mount("src")
	local StateFactory = Loader.require(root.shared.Game.State.StateFactory)
	local RuleSet = Loader.require(root.shared.Game.RuleSet)
	local Rng = Loader.require(root.shared.Game.Rng)
	local Match = Loader.require(root.shared.Game.Match)
	local PlayerViewBuilder = Loader.require(root.shared.Game.Behaviors.InfoModes.PlayerViewBuilder)
	local Alliances = Loader.require(root.shared.Game.Ops.Alliances)
	local Promises = Loader.require(root.shared.Game.Ops.Promises)
	local BotStrategy = Loader.require(root.server.Services.Bots.BotStrategy)
	local BotService = Loader.require(root.server.Services.BotService)

	local function newMatch(seed: number): any
		return Match.new(
			StateFactory.create("Normal", SEATS, seed),
			RuleSet.new("Normal"),
			Rng.new(seed)
		)
	end

	local function viewFor(state: any, classId: string): any
		return PlayerViewBuilder.build(state, RuleSet.new("Normal"), classId)
	end

	Lib.test("the four bots form two alliances in the first Window", function()
		local seed = 7
		local match = newMatch(seed)
		local service = BotService.new(seed)
		local state = match:state()
		state.phase = "Window"

		local played = service:playWindow(match, { "Working", "Middle", "Capitalist", "State" })
		Lib.eq(#played, 4, "every bot acted")
		Lib.eq(#state.alliances, 2, "two alliances formed")

		local members = {}
		for _, alliance in state.alliances do
			members[table.concat(alliance.members, "+")] = true
		end
		Lib.truthy(members["Working+Middle"], "Working and Middle allied")
		Lib.truthy(members["Capitalist+State"], "Capitalist and State allied")
	end)

	Lib.test("a NoBreakAlliance promise delays a bot's break", function()
		local seed = 11
		local match = newMatch(seed)
		local state = match:state()
		local proposal = Alliances.propose(state, "Working", "Middle")
		Lib.truthy(proposal ~= nil, "the alliance was proposed")
		Alliances.respond(state, proposal.id, true)
		Promises.create(state, "Working", "Middle", {
			kind = "NoBreakAlliance",
			untilDay = 12,
		})

		local bot = BotStrategy.new()
		state.day = 6
		local before = bot:decideLive(viewFor(state, "Working"), { rng = Rng.new(seed) })
		Lib.eq(before.breakAlliance, false, "the open promise holds the alliance")

		state.day = 13
		local after = bot:decideLive(viewFor(state, "Working"), { rng = Rng.new(seed) })
		Lib.eq(after.breakAlliance, true, "the promise has run out, so the break is allowed")
	end)

	Lib.test("a VoteYes promise overrides the bot's class interest", function()
		local seed = 13
		local match = newMatch(seed)
		local state = match:state()
		state.bills = {
			{
				id = "Bill-1",
				policyId = "Wage",
				level = 3,
				proposer = "State",
				proposedDay = 1,
			},
		}
		Promises.create(state, "Capitalist", "Working", {
			kind = "VoteYes",
			policyId = "Wage",
			level = 3,
			byDay = 1,
		})

		local draft = BotStrategy.emptyDraft()
		BotStrategy.vote(viewFor(state, "Capitalist"), draft)
		Lib.eq(draft.votes["Bill-1"].side, "yes", "the promise wins over the tax preference")
		Lib.eq(draft.votes["Bill-1"].influence, 0, "v1 still commits no Influence")
	end)

	Lib.test("20 seeded bot matches form and break alliances", function()
		local bots = { "Working", "Middle", "Capitalist", "State" }
		local formed = 0
		local broken = 0

		for seed = 1, 20 do
			local match = newMatch(seed)
			local service = BotService.new(seed)
			for _ = 1, 12 do
				local state = match:state()
				state.phase = "Window"
				local played = service:playWindow(match, bots)
				Lib.eq(#played, 4, `every bot acted in seed {seed}`)
				match:resolveDay(match:rng())
				if match:state().victory ~= nil then
					break
				end
			end

			for _, entry in match:state().eventLog do
				if string.find(entry.text, "formed an alliance", 1, true) then
					formed += 1
				end
				if string.find(entry.text, "broke the alliance with", 1, true) then
					broken += 1
				end
			end
		end

		Lib.truthy(formed > 0, "at least some alliances formed")
		Lib.truthy(broken > 0, "at least some alliances broke")
		Lib.eq(formed, 120, "two pairs formed six times in each of 20 matches")
		Lib.eq(broken, 80, "the age rule broke two pairs four times in each match")
	end)
end

return M
