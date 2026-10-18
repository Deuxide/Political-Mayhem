--!strict
-- Abstract base for policy effects.

local Types = require(script.Parent.Parent.Parent.Types)

export type Policy = {
	_trackId: string,
	_config: any,
	new: (trackId: string, config: any) -> Policy,
	apply: (self: Policy, state: Types.MatchState, level: number, ruleSet: any) -> (),
	getVoteThreshold: (self: Policy) -> number,
	isEnabledForDifficulty: (self: Policy, difficulty: Types.Difficulty) -> boolean,
}

local Policy = {}
Policy.__index = Policy

function Policy.new(trackId: string, config: any)
	return setmetatable({ _trackId = trackId, _config = config }, Policy)
end

function Policy:apply(state: Types.MatchState, level: number, ruleSet: any): ()
	error("not implemented: Policy:apply")
end

function Policy:getVoteThreshold(): number return self._config.voteThreshold or 0.5 end

function Policy:isEnabledForDifficulty(difficulty: Types.Difficulty): boolean
	if self._config.disabledOnDifficulties then
		for _, d in ipairs(self._config.disabledOnDifficulties) do
			if d == difficulty then return false end
		end
	end
	return true
end

return Policy
