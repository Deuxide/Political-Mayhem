--!strict
-- FogInfo: own class fully visible; other classes show only stability, VP, and public policy levels.

local Types = require(script.Parent.Parent.Parent.Types)
local InfoMode = require(script.Parent.InfoMode)
local StateOps = require(script.Parent.Parent.Parent.State.StateOps)

local FogInfo = setmetatable({}, { __index = InfoMode })
FogInfo.__index = FogInfo

function FogInfo.new() return setmetatable(InfoMode.new("FogInfo"), FogInfo) end

function FogInfo:filterState(state: Types.MatchState, viewerClass: Types.ClassId): Types.MatchState
	local ops = StateOps.new()
	local filtered = ops:deepCopy(state)

	for classId, classState in pairs(filtered.classes) do
		if classId ~= viewerClass then
			-- Keep only stability, victoryPoints, and policyState
			classState.resources = {
				Money = 0,
				Influence = 0,
				Food = 0,
				Goods = 0,
				Health = 0,
				Education = 0,
			}
			classState.lines = {}
			classState.promises = {}
			classState.activeStrikes = {}
			classState.reputation = {
				Working = 0,
				Middle = 0,
				Capitalist = 0,
				State = 0,
			}
			classState.alliances = {
				Working = false,
				Middle = false,
				Capitalist = false,
				State = false,
			}
			classState.influence = 0
		end
	end

	return filtered
end

return FogInfo
