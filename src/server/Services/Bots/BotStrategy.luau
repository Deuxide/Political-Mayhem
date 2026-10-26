--!strict
-- BotStrategy: the abstract behavior base for the four class bots
-- (ARCHITECTURE 3.1 "Behavior", GAME_DESIGN 15). One abstract base and one
-- subclass per class, depth 1.
--
-- A bot decides from a PlayerView and a per-bot RNG only. It never receives
-- the MatchState, the match RNG or a client's raw request, so it cannot read
-- a field the human in that seat could not read (GAME_DESIGN 13 and 15).
-- BotService builds the view, applies the returned draft through DraftRules
-- (the same clamp a human gets), and owns the RNG stream.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Rng = require(ReplicatedStorage.Shared.Game.Rng)
local Abstract = require(ReplicatedStorage.Shared.Game.Abstract)

type ActionDraft = Types.ActionDraft
type PlayerView = Types.PlayerView

export type BotContext = {
	rng: Rng.Rng,
}

local BotStrategy = {}
BotStrategy.__index = BotStrategy

export type BotStrategy = typeof(setmetatable({} :: {}, BotStrategy))

function BotStrategy.new(): BotStrategy
	return setmetatable({}, BotStrategy)
end

-- A fresh, safe, empty draft. Every field is present so a subclass can fill
-- only what it chooses; StateFactory's initial draft has the same shape.
function BotStrategy.emptyDraft(): ActionDraft
	return {
		sequence = 0,
		locked = false,
		openSlots = {},
		assign = {},
		strike = nil,
		build = nil,
		lobby = nil,
		market = { sell = {}, buy = {} },
		votes = {},
	}
end

-- The one abstract method: decide this Window's draft from what a human in
-- this seat could see. Subclasses override it.
function BotStrategy.decide(_self: BotStrategy, _view: PlayerView, _ctx: BotContext): ActionDraft
	return Abstract.notImplemented("BotStrategy", "decide")
end

return BotStrategy
