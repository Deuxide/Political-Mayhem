--!strict
-- DraftRules: the one place a draft becomes server state. A human's
-- Draft_Update handler and a bot's BotService both call `apply`, so a bot
-- cannot bypass the clamp a human gets (GAME_DESIGN 15, NETWORKING 7).
--
-- Authentication, role checks and the stale-sequence refusal stay with the
-- caller: a human handler has a player to authenticate, while a bot is
-- already the server and uses the next sequence itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Validate = require(ReplicatedStorage.Shared.Net.Validate)

type ActionDraft = Types.ActionDraft
type ClassId = Types.ClassId
type MatchState = Types.MatchState

local DraftRules = {}

-- Clamps the draft against the live state, preserves the existing lock, and
-- stores it with the caller's sequence. The caller has already refused a
-- stale sequence (a human handler) or chosen the next one (a bot).
function DraftRules.apply(
	state: MatchState,
	classId: ClassId,
	draft: any,
	sequence: number
): ActionDraft
	local stored = state.drafts[classId]
	local safe = Validate.clampDraft(draft, state)
	safe.sequence = sequence
	safe.locked = stored.locked
	state.drafts[classId] = safe
	return safe
end

return DraftRules
