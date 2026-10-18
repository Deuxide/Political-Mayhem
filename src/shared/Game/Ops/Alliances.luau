--!strict
-- Alliance operations: propose, accept, break, age; one per class pair.

local Types = require(script.Parent.Parent.Types)

export type Alliances = {
	propose: (
		state: Types.MatchState,
		from: Types.ClassId,
		to: Types.ClassId
	) -> (boolean, string?),
	accept: (state: Types.MatchState, from: Types.ClassId, to: Types.ClassId) -> (boolean, string?),
	breakAlliance: (
		state: Types.MatchState,
		from: Types.ClassId,
		to: Types.ClassId
	) -> (boolean, string?),
	areAllied: (state: Types.MatchState, a: Types.ClassId, b: Types.ClassId) -> boolean,
}

local Alliances = {}

function Alliances.propose(
	state: Types.MatchState,
	from: Types.ClassId,
	to: Types.ClassId
): (boolean, string?)
	if from == to then return false, "Cannot ally with self" end

	local fromState = state.classes[from]
	local toState = state.classes[to]

	if not fromState or not toState then return false, "Invalid class" end

	if fromState.alliances[to] then return false, "Already allied" end

	-- Check if either already has an alliance (one per class)
	for classId, allied in pairs(fromState.alliances) do
		if allied and classId ~= to then return false, "Already allied with " .. classId end
	end

	for classId, allied in pairs(toState.alliances) do
		if allied and classId ~= from then
			return false, "Target already allied with " .. classId
		end
	end

	-- Proposal is recorded; acceptance happens separately
	return true, nil
end

function Alliances.accept(
	state: Types.MatchState,
	from: Types.ClassId,
	to: Types.ClassId
): (boolean, string?)
	local fromState = state.classes[from]
	local toState = state.classes[to]

	if not fromState or not toState then return false, "Invalid class" end

	if fromState.alliances[to] then return false, "Already allied" end

	-- Form alliance (mutual)
	fromState.alliances[to] = true
	toState.alliances[from] = true

	return true, nil
end

function Alliances.breakAlliance(
	state: Types.MatchState,
	from: Types.ClassId,
	to: Types.ClassId
): (boolean, string?)
	local fromState = state.classes[from]
	local toState = state.classes[to]

	if not fromState or not toState then return false, "Invalid class" end

	if not fromState.alliances[to] then return false, "Not allied" end

	fromState.alliances[to] = false
	toState.alliances[from] = false

	return true, nil
end

function Alliances.areAllied(state: Types.MatchState, a: Types.ClassId, b: Types.ClassId): boolean
	local aState = state.classes[a]
	if not aState then return false end
	return aState.alliances[b] == true
end

return Alliances
