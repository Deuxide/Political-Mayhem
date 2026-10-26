--!strict
-- CapitalistBot: the Capitalist class's strategy (GAME_DESIGN 15). M9-T1 is
-- the framework only; the heuristic (lines, lobby, market, VP chase) arrives
-- in M9-T2. The bot returns a valid empty draft meanwhile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local BotStrategy = require(script.Parent.BotStrategy)

type ActionDraft = Types.ActionDraft

local CapitalistBot = setmetatable({}, { __index = BotStrategy })
CapitalistBot.__index = CapitalistBot

export type CapitalistBot = typeof(setmetatable({} :: {}, CapitalistBot))

function CapitalistBot.new(): CapitalistBot
	return setmetatable({}, CapitalistBot)
end

function CapitalistBot.decide(
	_self: CapitalistBot,
	_view: Types.PlayerView,
	_ctx: BotStrategy.BotContext
): ActionDraft
	return BotStrategy.emptyDraft()
end

return CapitalistBot
