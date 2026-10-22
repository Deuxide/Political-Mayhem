--!strict
-- Reputation (GAME_DESIGN 8.3): the kept/broken counters of a class and
-- the score the game shows and the bots read. A promise is never enforced
-- — the audit decides, and the counters are the consequence.
local Types = require(script.Parent.Parent.Types)

type ClassId = Types.ClassId
type MatchState = Types.MatchState
type Reputation = Types.Reputation

local Reputation = {}

-- The score: (kept + 1) / (kept + broken + 2). Between 0 and 1; the
-- display turns it into 0 to 5 stars.
function Reputation.score(reputation: Reputation): number
	return (reputation.kept + 1) / (reputation.broken + reputation.kept + 2)
end

-- The score as 0 to 5 stars (8.3).
function Reputation.stars(reputation: Reputation): number
	return Reputation.score(reputation) * 5
end

-- Records that a class kept or broke a promise.
function Reputation.record(state: MatchState, classId: ClassId, kept: boolean)
	local reputation = state.reputation[classId]
	if kept then
		reputation.kept += 1
	else
		reputation.broken += 1
	end
end

return Reputation
