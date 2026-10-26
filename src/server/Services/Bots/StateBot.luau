--!strict
-- StateBot: the State class's strategy (GAME_DESIGN 15). It builds Clinics
-- and Schools for public staffing, sells the surplus, and votes for taxes,
-- services and stability.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local ConfigBots = require(ReplicatedStorage.Shared.Config.Bots)
local BotStrategy = require(script.Parent.BotStrategy)

type ActionDraft = Types.ActionDraft
type LineType = Types.LineType

local StateBot = setmetatable({}, { __index = BotStrategy })
StateBot.__index = StateBot

export type StateBot = typeof(setmetatable({} :: {}, StateBot))

function StateBot.new(): StateBot
	return setmetatable({}, StateBot)
end

function StateBot.decide(
	_self: StateBot,
	view: Types.PlayerView,
	_ctx: BotStrategy.BotContext
): ActionDraft
	local draft = BotStrategy.emptyDraft()

	-- Public staffing is a State VP criterion, and Clinics/Schools also keep
	-- the Health/Education the other classes need. Build the one that is
	-- furthest below the reserve first.
	local health = (view.own.stock :: any).health or 0
	local education = (view.own.stock :: any).education or 0
	local needsSchool = health >= ConfigBots.publicServicesReserve
		and education < ConfigBots.publicServicesReserve
	local lineType: LineType = if needsSchool then "School" else "Clinic"
	local spent = BotStrategy.build(view, draft, lineType)

	BotStrategy.openOwnLines(view, draft, view.own.money - spent)

	-- Universal PublicServices gives the stock away; Market lets the State
	-- sell its surplus. Keep a small reserve for the universal mode.
	local keep: any = {}
	if ((view.policies :: any).PublicServices or 0) == 1 then
		keep.health = ConfigBots.publicServicesReserve
		keep.education = ConfigBots.publicServicesReserve
	end
	BotStrategy.sellSurplus(view, draft, keep)
	BotStrategy.buyNeeds(view, draft, view.own.money - spent)
	BotStrategy.vote(view, draft)
	return draft
end

return StateBot
