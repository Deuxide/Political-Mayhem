--!strict
-- WorkingBot: the Working class's strategy (GAME_DESIGN 15). It fills every
-- open slot it can, buys the Food and Health its workers need, and votes for
-- wages and public services. The strike is left unused in v1.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local BotStrategy = require(script.Parent.BotStrategy)

type ActionDraft = Types.ActionDraft

local WorkingBot = setmetatable({}, { __index = BotStrategy })
WorkingBot.__index = WorkingBot

export type WorkingBot = typeof(setmetatable({} :: {}, WorkingBot))

function WorkingBot.new(): WorkingBot
	return setmetatable({}, WorkingBot)
end

function WorkingBot.decide(
	_self: WorkingBot,
	view: Types.PlayerView,
	_ctx: BotStrategy.BotContext
): ActionDraft
	local draft = BotStrategy.emptyDraft()
	-- Fill the open slots first, then buy the food/health the workers need.
	-- The expected wages are part of the market budget: R5 pays them before
	-- R6 buys, so the Working can spend them the same Day.
	local assigned = BotStrategy.assignWorkers(view, draft)
	BotStrategy.sellSurplus(view, draft, {})
	BotStrategy.buyNeeds(view, draft, view.own.money, assigned * BotStrategy.wage(view))
	BotStrategy.vote(view, draft)
	return draft
end

return WorkingBot
