--!strict
-- OpenInfo: all classes fully visible.

local Types = require(script.Parent.Parent.Parent.Types)
local InfoMode = require(script.Parent.InfoMode)
local StateOps = require(script.Parent.Parent.Parent.State.StateOps)

local OpenInfo = setmetatable({}, { __index = InfoMode })
OpenInfo.__index = OpenInfo

function OpenInfo.new() return setmetatable(InfoMode.new("OpenInfo"), OpenInfo) end

function OpenInfo:filterState(state: Types.MatchState, viewerClass: Types.ClassId): Types.MatchState
	-- Return full state (deep copied)
	local ops = StateOps.new()
	return ops:deepCopy(state)
end

return OpenInfo
