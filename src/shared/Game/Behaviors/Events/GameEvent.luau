--!strict
-- Abstract base for random events (V2).

local Types = require(script.Parent.Parent.Parent.Types)

export type GameEvent = {
	_id: string,
	_config: any,
	new: (id: string, config: any) -> GameEvent,
	trigger: (self: GameEvent, state: Types.MatchState, rng: any) -> Types.GameEvent?,
	apply: (self: GameEvent, state: Types.MatchState, event: Types.GameEvent) -> (),
}

local GameEvent = {}
GameEvent.__index = GameEvent

function GameEvent.new(id: string, config: any)
	return setmetatable({ _id = id, _config = config }, GameEvent)
end

function GameEvent:trigger(state: Types.MatchState, rng: any): Types.GameEvent?
	error("not implemented: GameEvent:trigger")
end

function GameEvent:apply(state: Types.MatchState, event: Types.GameEvent): ()
	error("not implemented: GameEvent:apply")
end

return GameEvent
