--!strict
-- StateBot: the State class's strategy (GAME_DESIGN 15). M9-T1 is the
-- framework only; the heuristic (taxes, services, stability, VP chase)
-- arrives in M9-T2. The bot returns a valid empty draft meanwhile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local BotStrategy = require(script.Parent.BotStrategy)

type ActionDraft = Types.ActionDraft

local StateBot = setmetatable({}, { __index = BotStrategy })
StateBot.__index = StateBot

export type StateBot = typeof(setmetatable({} :: {}, StateBot))

function StateBot.new(): StateBot
	return setmetatable({}, StateBot)
end

function StateBot.decide(
	_self: StateBot,
	_view: Types.PlayerView,
	_ctx: BotStrategy.BotContext
): ActionDraft
	return BotStrategy.emptyDraft()
end

return StateBot
