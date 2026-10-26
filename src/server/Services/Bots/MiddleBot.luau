--!strict
-- MiddleBot: the Middle class's strategy (GAME_DESIGN 15). M9-T1 is the
-- framework only; the heuristic (needs, production, market, VP chase)
-- arrives in M9-T2. The bot returns a valid empty draft meanwhile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local BotStrategy = require(script.Parent.BotStrategy)

type ActionDraft = Types.ActionDraft

local MiddleBot = setmetatable({}, { __index = BotStrategy })
MiddleBot.__index = MiddleBot

export type MiddleBot = typeof(setmetatable({} :: {}, MiddleBot))

function MiddleBot.new(): MiddleBot
	return setmetatable({}, MiddleBot)
end

function MiddleBot.decide(
	_self: MiddleBot,
	_view: Types.PlayerView,
	_ctx: BotStrategy.BotContext
): ActionDraft
	return BotStrategy.emptyDraft()
end

return MiddleBot
