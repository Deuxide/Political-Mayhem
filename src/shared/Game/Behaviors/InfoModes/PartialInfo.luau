--!strict
-- PartialInfo: own class fully visible; other classes show resources but hide promises, strikes, reputation details.

local Types = require(script.Parent.Parent.Parent.Types)
local InfoMode = require(script.Parent.InfoMode)
local StateOps = require(script.Parent.Parent.Parent.State.StateOps)

local PartialInfo = setmetatable({}, { __index = InfoMode })
PartialInfo.__index = PartialInfo

function PartialInfo.new() return setmetatable(InfoMode.new("PartialInfo"), PartialInfo) end

function PartialInfo:filterState(
	state: Types.MatchState,
	viewerClass: Types.ClassId
): Types.MatchState
	local ops = StateOps.new()
	local filtered = ops:deepCopy(state)

	for classId, classState in pairs(filtered.classes) do
		if classId ~= viewerClass then
			-- Hide promises
			classState.promises = {}
			-- Hide active strikes
			classState.activeStrikes = {}
			-- Hide reputation details (keep only totals)
			for otherClass, _ in pairs(classState.reputation) do
				classState.reputation[otherClass] = 0
			end
			-- Hide alliance details
			for otherClass, _ in pairs(classState.alliances) do
				classState.alliances[otherClass] = false
			end
		end
	end

	return filtered
end

return PartialInfo
