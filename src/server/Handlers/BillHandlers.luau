--!strict
-- The bill remote (NETWORKING section 3.1): Bill_Propose. The cost, the
-- cutoff and the live-bill limit are checked by the engine against the
-- state (GAME_DESIGN 7.3); the handler only decides *who* is asking and
-- whether the payload is a bill at all.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Validate = require(ReplicatedStorage.Shared.Net.Validate)
local ConfigNetwork = require(ReplicatedStorage.Shared.Config.Network)
local Bills = require(ReplicatedStorage.Shared.Game.Ops.Bills)
local Support = require(script.Parent.Support)
local Replication = require(script.Parent.Parent.Replication)

type ClassId = Types.ClassId
type SupportType = Support.Support

local BillHandlers = {}

function BillHandlers.connect(support: SupportType)
	support.remotes.Bill_Propose.OnServerEvent:Connect(function(player: any, payload: any)
		if Support.rateLimited(support, "Bill_Propose", player) then
			return
		end
		if
			type(payload) ~= "table"
			or not Support.hasOnlyKeys(payload, { "requestId", "policyId", "level" })
		then
			Support.notice(
				support,
				player,
				"InvalidPayload",
				"Bill_Propose needs a policy and a level."
			)
			return
		end
		if not Validate.isShortString(payload.requestId, ConfigNetwork.maxRequestIdLength) then
			Support.notice(
				support,
				player,
				"InvalidPayload",
				"the request id is missing or too long."
			)
			return
		end
		if not Validate.isPolicyId(payload.policyId) then
			Support.notice(support, player, "InvalidPayload", "there is no such policy track.")
			return
		end
		if not Validate.isNonNegInt(payload.level, 100) then
			Support.notice(support, player, "InvalidPayload", "the level must be a whole number.")
			return
		end

		local classId: ClassId? = Support.authenticated(support, player) :: any
		if classId == nil then
			return
		end
		if not Support.hasRole(support, player, "Politics") then
			Support.notice(
				support,
				player,
				"Rejected",
				"you may not propose bills",
				payload.requestId
			)
			return
		end
		local match = Support.inWindow(support, player)
		if match == nil then
			return
		end

		local state = match:state()
		local secondsLeft = state.phaseEndsAt - support.clock()
		local bill, reason =
			Bills.propose(state, classId, payload.policyId, payload.level, secondsLeft)
		if bill == nil then
			Support.notice(support, player, "Rejected", reason, payload.requestId)
			return
		end

		-- everybody hears about the bill (it is public, GAME_DESIGN 7.2)
		Replication.patchAll(support, "bills", bill)
	end)
end

return BillHandlers
