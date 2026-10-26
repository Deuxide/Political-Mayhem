--!strict
-- MiddleBot: the Middle class's strategy (GAME_DESIGN 15). It builds toward
-- five lines, keeps two Education for the VP criterion, sells surplus, buys
-- its needs and votes for education and public services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local ConfigBots = require(ReplicatedStorage.Shared.Config.Bots)
local BotStrategy = require(script.Parent.BotStrategy)

type ActionDraft = Types.ActionDraft
type LineType = Types.LineType

local MiddleBot = setmetatable({}, { __index = BotStrategy })
MiddleBot.__index = MiddleBot

export type MiddleBot = typeof(setmetatable({} :: {}, MiddleBot))

function MiddleBot.new(): MiddleBot
	return setmetatable({}, MiddleBot)
end

function MiddleBot.decide(
	_self: MiddleBot,
	view: Types.PlayerView,
	_ctx: BotStrategy.BotContext
): ActionDraft
	local draft = BotStrategy.emptyDraft()

	-- OwnsLinesAtLeast(5) is a VP criterion; a School also pushes Education
	-- toward the other Middle VP criterion.
	local spent = 0
	if #view.ownLines < ConfigBots.middleLineTarget then
		local education = (view.own.stock :: any).education or 0
		local lineType: LineType = if education < ConfigBots.middleEducationTarget
			then "School"
			else "Farm"
		spent = BotStrategy.build(view, draft, lineType)
	end

	BotStrategy.openOwnLines(view, draft, view.own.money - spent)
	BotStrategy.sellSurplus(view, draft, {
		education = ConfigBots.middleEducationTarget,
	})
	BotStrategy.buyNeeds(view, draft, view.own.money - spent)
	BotStrategy.vote(view, draft)
	return draft
end

return MiddleBot
