--!strict
-- The trade remotes (NETWORKING section 3.1): Trade_Propose, Trade_Respond
-- and Trade_Cancel. The class of an offer comes from the sender's seat,
-- never from the payload, and the amounts are checked against the state
-- again when the offer is accepted (NETWORKING 8, item 3).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Validate = require(ReplicatedStorage.Shared.Net.Validate)
local ConfigNetwork = require(ReplicatedStorage.Shared.Config.Network)
local Trade = require(ReplicatedStorage.Shared.Game.Ops.Trade)
local Support = require(script.Parent.Support)

type ClassId = Types.ClassId
type SupportType = Support.Support

-- How many promises one offer may carry (NETWORKING 3.1: the payload is
-- bounded like every other one).
local MAX_PROMISES = 8

local TradeHandlers = {}

-- A promise spec has to be one of the four known kinds with the right
-- fields (GAME_DESIGN 8.3).
local function isPromiseSpec(spec: any): boolean
	if type(spec) ~= "table" then
		return false
	end
	local kind = spec.kind
	if kind == "Deliver" then
		return Validate.isResourceId(spec.resource)
			and Validate.isNonNegInt(spec.amount, ConfigNetwork.maxResourceAmount)
			and Validate.isClassId(spec.to)
			and Validate.isNonNegInt(spec.byDay, ConfigNetwork.maxSequence)
	end
	if kind == "VoteYes" then
		return Validate.isPolicyId(spec.policyId)
			and Validate.isNonNegInt(spec.level, ConfigNetwork.maxResourceAmount)
			and Validate.isNonNegInt(spec.byDay, ConfigNetwork.maxSequence)
	end
	if kind == "NoStrike" or kind == "NoBreakAlliance" then
		return Validate.isNonNegInt(spec.untilDay, ConfigNetwork.maxSequence)
	end
	return false
end

-- The result both parties hear about (NETWORKING 3.2).
local function announce(support: SupportType, classId: ClassId, payload: any)
	for _, member in Support.membersOf(support, classId) do
		support.remotes.Trade_Result:FireClient(member, payload)
	end
end

function TradeHandlers.connect(support: SupportType)
	support.remotes.Trade_Propose.OnServerEvent:Connect(function(player: any, payload: any)
		if Support.rateLimited(support, "Trade_Propose", player) then
			return
		end
		if
			type(payload) ~= "table"
			or not Support.hasOnlyKeys(payload, { "requestId", "to", "give", "want", "promises" })
		then
			Support.notice(support, player, "InvalidPayload", "Trade_Propose needs an offer.")
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
		if not Validate.isClassId(payload.to) then
			Support.notice(support, player, "InvalidPayload", "the offer needs a class to send to.")
			return
		end
		if not Validate.isResourceBag(payload.give) or not Validate.isResourceBag(payload.want) then
			Support.notice(support, player, "InvalidPayload", "the amounts are not a resource bag.")
			return
		end
		if type(payload.promises) ~= "table" or #payload.promises > MAX_PROMISES then
			Support.notice(support, player, "InvalidPayload", "too many promises.")
			return
		end
		for _, spec in payload.promises do
			if not isPromiseSpec(spec) then
				Support.notice(
					support,
					player,
					"InvalidPayload",
					"a promise is not a known promise."
				)
				return
			end
		end

		local classId: ClassId? = Support.authenticated(support, player) :: any
		if classId == nil then
			return
		end
		if not Support.hasRole(support, player, "Diplomacy") then
			Support.notice(support, player, "Rejected", "you may not make trade offers")
			return
		end
		local to: ClassId = payload.to :: any
		if classId == to then
			Support.notice(
				support,
				player,
				"Rejected",
				"a class cannot trade with itself",
				payload.requestId
			)
			return
		end
		local match = Support.inWindow(support, player)
		if match == nil then
			return
		end

		local state = match:state()
		local offer, reason = Trade.propose(
			state,
			classId,
			to,
			payload.give,
			payload.want,
			payload.promises,
			state.phaseEndsAt
		)
		if offer == nil then
			Support.notice(support, player, "Rejected", reason, payload.requestId)
			return
		end

		-- the recipient hears about the offer (NETWORKING 3.2)
		for _, member in Support.membersOf(support, offer.to) do
			support.remotes.Trade_Incoming:FireClient(member, { offer = offer })
		end
		announce(support, offer.from, {
			requestId = payload.requestId,
			offerId = offer.id,
			status = "accepted",
		})
	end)

	support.remotes.Trade_Respond.OnServerEvent:Connect(function(player: any, payload: any)
		if Support.rateLimited(support, "Trade_Respond", player) then
			return
		end
		if
			type(payload) ~= "table"
			or not Support.hasOnlyKeys(payload, { "offerId", "accept" })
			or not Validate.isShortString(payload.offerId, ConfigNetwork.maxRequestIdLength)
			or type(payload.accept) ~= "boolean"
		then
			Support.notice(
				support,
				player,
				"InvalidPayload",
				"Trade_Respond needs an offer and an answer."
			)
			return
		end

		local classId: ClassId? = Support.authenticated(support, player) :: any
		if classId == nil then
			return
		end
		if not Support.hasRole(support, player, "Diplomacy") then
			Support.notice(support, player, "Rejected", "you may not answer trade offers")
			return
		end
		local match = Support.inWindow(support, player)
		if match == nil then
			return
		end

		local state = match:state()
		local offer = Trade.find(state, payload.offerId)
		if offer == nil then
			Support.notice(support, player, "Rejected", "unknown trade offer")
			return
		end
		if offer.to ~= classId then
			Support.notice(support, player, "Rejected", "that offer is not yours to answer")
			return
		end

		-- The engine checks that both sides can still pay (NETWORKING 8).
		local ok, reason = Trade.respond(state, payload.offerId, payload.accept, support.clock())
		local status = if not payload.accept then "declined" elseif ok then "accepted" else "failed"
		local result = { offerId = payload.offerId, status = status }
		if not ok then
			result.reason = reason
		end
		announce(support, offer.from, result)
		announce(support, offer.to, result)
		if not ok then
			Support.notice(support, player, "Rejected", reason)
		end
	end)

	support.remotes.Trade_Cancel.OnServerEvent:Connect(function(player: any, payload: any)
		if Support.rateLimited(support, "Trade_Cancel", player) then
			return
		end
		if
			type(payload) ~= "table"
			or not Support.hasOnlyKeys(payload, { "offerId" })
			or not Validate.isShortString(payload.offerId, ConfigNetwork.maxRequestIdLength)
		then
			Support.notice(support, player, "InvalidPayload", "Trade_Cancel needs an offer.")
			return
		end

		local classId: ClassId? = Support.authenticated(support, player) :: any
		if classId == nil then
			return
		end
		if not Support.hasRole(support, player, "Diplomacy") then
			Support.notice(support, player, "Rejected", "you may not cancel trade offers")
			return
		end
		local match = Support.inWindow(support, player)
		if match == nil then
			return
		end

		local state = match:state()
		local cancelled, reason = Trade.cancel(state, payload.offerId, classId)
		if not cancelled then
			Support.notice(support, player, "Rejected", reason)
			return
		end
		announce(support, classId, { offerId = payload.offerId, status = "declined" })
	end)
end

return TradeHandlers
