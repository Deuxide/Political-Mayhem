--!strict
-- The draft remotes (NETWORKING section 3.1 and 4): Draft_Update and
-- Draft_LockIn. The server owns the draft: the client's copy is shape
-- checked, clamped against the state, and stored with a sequence number
-- that an older packet cannot beat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Validate = require(ReplicatedStorage.Shared.Net.Validate)
local ConfigNetwork = require(ReplicatedStorage.Shared.Config.Network)
local Support = require(script.Parent.Support)

type ClassId = Types.ClassId
type SupportType = Support.Support

-- Which role may edit which draft field (NETWORKING section 3.1).
local ECONOMY_FIELDS = { "openSlots", "assign", "strike", "build", "lobby", "market" }
local POLITICS_FIELDS = { "votes" }

local DraftHandlers = {}

-- The fields the sender may not edit must not change: the whole payload is
-- refused (NETWORKING section 3.1).
local function mayEdit(
	support: SupportType,
	player: any,
	draft: any,
	stored: any
): (boolean, string)
	local economy = false
	local politics = false
	for _, field in ECONOMY_FIELDS do
		if not Support.sameValue(draft[field], stored[field]) then
			economy = true
		end
	end
	for _, field in POLITICS_FIELDS do
		if not Support.sameValue(draft[field], stored[field]) then
			politics = true
		end
	end
	if economy and not Support.hasRole(support, player, "Economy") then
		return false, "you may not edit the economic fields"
	end
	if politics and not Support.hasRole(support, player, "Politics") then
		return false, "you may not edit the votes"
	end
	return true, ""
end

function DraftHandlers.connect(support: SupportType)
	support.remotes.Draft_Update.OnServerEvent:Connect(function(player: any, payload: any)
		if Support.rateLimited(support, "Draft_Update", player) then
			return
		end
		if type(payload) ~= "table" or not Support.hasOnlyKeys(payload, { "seq", "draft" }) then
			Support.notice(
				support,
				player,
				"InvalidPayload",
				"Draft_Update needs a sequence and a draft."
			)
			return
		end
		if not Validate.isNonNegInt(payload.seq, ConfigNetwork.maxSequence) then
			Support.notice(
				support,
				player,
				"InvalidPayload",
				"the sequence must be a whole number."
			)
			return
		end
		if not Validate.isDraftShape(payload.draft) then
			Support.notice(
				support,
				player,
				"InvalidPayload",
				"the draft has an unknown field or a bad value."
			)
			return
		end

		local classId: ClassId? = Support.authenticated(support, player) :: any
		if classId == nil then
			return
		end
		local match = Support.inWindow(support, player)
		if match == nil then
			return
		end

		local state = match:state()
		local stored = state.drafts[classId]
		if payload.seq <= stored.sequence then
			Support.notice(
				support,
				player,
				"StaleDraft",
				"that draft is older than the one the server has."
			)
			return
		end

		local allowed, reason = mayEdit(support, player, payload.draft, stored)
		if not allowed then
			Support.notice(support, player, "Rejected", reason)
			return
		end

		-- The stored draft is the clamped one (NETWORKING 7), so a value
		-- the game does not allow never reaches the resolution.
		local safe = Validate.clampDraft(payload.draft, state)
		safe.sequence = payload.seq
		safe.locked = stored.locked
		state.drafts[classId] = safe

		-- The team sees the accepted draft (NETWORKING 4).
		for _, member in Support.membersOf(support, classId) do
			support.remotes.View_Patch:FireClient(member, {
				ops = { { op = "set", path = "draft", value = safe } },
				serverTime = support.clock(),
			})
		end
	end)

	support.remotes.Draft_LockIn.OnServerEvent:Connect(function(player: any, payload: any)
		if Support.rateLimited(support, "Draft_LockIn", player) then
			return
		end
		if
			type(payload) ~= "table"
			or not Support.hasOnlyKeys(payload, { "locked" })
			or type(payload.locked) ~= "boolean"
		then
			Support.notice(support, player, "InvalidPayload", "Draft_LockIn needs one boolean.")
			return
		end

		local classId: ClassId? = Support.authenticated(support, player) :: any
		if classId == nil then
			return
		end
		if
			not Support.hasRole(support, player, "Economy")
			and not Support.hasRole(support, player, "Politics")
		then
			Support.notice(support, player, "Rejected", "you may not lock the draft")
			return
		end
		local match = Support.inWindow(support, player)
		if match == nil then
			return
		end

		-- The lock only stops the client from editing; the window still ends
		-- on the timer (NETWORKING 3.1).
		local state = match:state()
		state.drafts[classId].locked = payload.locked
		Support.notice(
			support,
			player,
			"DraftLocked",
			if payload.locked then "draft locked" else "draft unlocked"
		)
	end)
end

return DraftHandlers
