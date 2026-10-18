--!strict
-- Reputation operations: track kept/broken promises per class pair.

local Types = require(script.Parent.Parent.Types)

export type Reputation = {
	recordKept: (
		state: Types.MatchState,
		from: Types.ClassId,
		to: Types.ClassId,
		amount: number?
	) -> (),
	recordBroken: (
		state: Types.MatchState,
		from: Types.ClassId,
		to: Types.ClassId,
		amount: number?
	) -> (),
	getReputation: (state: Types.MatchState, from: Types.ClassId, to: Types.ClassId) -> number,
	auditPromises: (state: Types.MatchState, currentRound: number) -> (),
}

local Reputation = {}

local DEFAULT_KEPT = 5
local DEFAULT_BROKEN = -15

function Reputation.recordKept(
	state: Types.MatchState,
	from: Types.ClassId,
	to: Types.ClassId,
	amount: number?
)
	local fromState = state.classes[from]
	if not fromState then return end
	fromState.reputation[to] = (fromState.reputation[to] or 0) + (amount or DEFAULT_KEPT)
end

function Reputation.recordBroken(
	state: Types.MatchState,
	from: Types.ClassId,
	to: Types.ClassId,
	amount: number?
)
	local fromState = state.classes[from]
	if not fromState then return end
	fromState.reputation[to] = (fromState.reputation[to] or 0) + (amount or DEFAULT_BROKEN)
end

function Reputation.getReputation(
	state: Types.MatchState,
	from: Types.ClassId,
	to: Types.ClassId
): number
	local fromState = state.classes[from]
	if not fromState then return 0 end
	return fromState.reputation[to] or 0
end

function Reputation.auditPromises(state: Types.MatchState, currentRound: number)
	for _, classState in pairs(state.classes) do
		local keptPromises = {}
		for _, promise in ipairs(classState.promises) do
			if promise.status == "Active" then
				if promise.expiresRound and currentRound > promise.expiresRound then
					promise.status = "Broken"
					Reputation.recordBroken(state, promise.from, promise.to)
				else
					table.insert(keptPromises, promise)
				end
			else
				table.insert(keptPromises, promise)
			end
		end
		classState.promises = keptPromises
	end
end

return Reputation
