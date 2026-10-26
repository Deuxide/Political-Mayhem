--!strict
-- CapitalistBot: the Capitalist class's strategy (GAME_DESIGN 15). It builds
-- Farms to the target, then a Factory, reserves the Factory's Education
-- input, sells surplus and votes for low Capitalist tax.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local ConfigBots = require(ReplicatedStorage.Shared.Config.Bots)
local BotStrategy = require(script.Parent.BotStrategy)

type ActionDraft = Types.ActionDraft
type LineType = Types.LineType

local CapitalistBot = setmetatable({}, { __index = BotStrategy })
CapitalistBot.__index = CapitalistBot

export type CapitalistBot = typeof(setmetatable({} :: {}, CapitalistBot))

function CapitalistBot.new(): CapitalistBot
	return setmetatable({}, CapitalistBot)
end

function CapitalistBot.decide(
	_self: CapitalistBot,
	view: Types.PlayerView,
	_ctx: BotStrategy.BotContext
): ActionDraft
	local draft = BotStrategy.emptyDraft()

	-- Farms need no input and sell reliably; keep building them until the
	-- target, then add a Factory. Existing Factories reserve their Education
	-- input so the bot does not sell the stock they need.
	local farms = 0
	local factories = 0
	for _, line in view.ownLines do
		if line.type == "Farm" then
			farms += 1
		elseif line.type == "Factory" then
			factories += 1
		end
	end
	local lineType: LineType = if farms < ConfigBots.capitalistFarmTarget then "Farm" else "Factory"
	local spent = BotStrategy.build(view, draft, lineType)

	BotStrategy.openOwnLines(view, draft, view.own.money - spent)
	BotStrategy.sellSurplus(view, draft, { education = factories })
	BotStrategy.buyNeeds(view, draft, view.own.money - spent)
	BotStrategy.vote(view, draft)
	return draft
end

return CapitalistBot
