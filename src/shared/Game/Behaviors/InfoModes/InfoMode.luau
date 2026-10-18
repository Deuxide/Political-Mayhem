--!strict
-- Info mode strategies for player views.

local Types = require(script.Parent.Parent.Parent.Types)

export type InfoMode = {
	_id: string,
	new: () -> InfoMode,
	filterState: (
		self: InfoMode,
		state: Types.MatchState,
		viewerClass: Types.ClassId
	) -> Types.MatchState,
}

local InfoMode = {}
InfoMode.__index = InfoMode

function InfoMode.new(id: string) return setmetatable({ _id = id }, InfoMode) end

function InfoMode:filterState(
	state: Types.MatchState,
	viewerClass: Types.ClassId
): Types.MatchState
	error("not implemented: InfoMode:filterState")
end

return InfoMode
