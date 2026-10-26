--!strict
-- WorkingBot: the Working class's strategy (GAME_DESIGN 15). M9-T1 is the
-- framework only; the heuristic (needs, wages, strike, VP chase) arrives in
-- M9-T2. The bot still returns a valid empty draft so it can run through the
-- same pipeline as a human from day one.

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
	_view: Types.PlayerView,
	_ctx: BotStrategy.BotContext
): ActionDraft
	return BotStrategy.emptyDraft()
end

return WorkingBot
