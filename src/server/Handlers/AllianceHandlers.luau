--!strict
-- The alliance remotes (NETWORKING section 3.1): Alliance_Propose,
-- Alliance_Respond and Alliance_Break. The class of a proposal comes from
-- the sender's seat; the server checks that both sides are free before an
-- alliance is formed (GAME_DESIGN 8.4).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Validate = require(ReplicatedStorage.Shared.Net.Validate)
local Alliances = require(ReplicatedStorage.Shared.Game.Ops.Alliances)
local Support = require(script.Parent.Support)

type ClassId = Types.ClassId
type SupportType = Support.Support

local AllianceHandlers = {}

-- The pending proposal the sender may answer: it has to come from the
-- class the payload names and to the sender's own class.
local function proposalFor(state: any, from: ClassId, to: ClassId): any
	for _, proposal in state.allianceProposals do
		if proposal.from == from and proposal.to == to then
			return proposal
		end
	end
	return nil
end

function AllianceHandlers.connect(support: SupportType)
	support.remotes.Alliance_Propose.OnServerEvent:Connect(function(player: any, payload: any)
		if Support.rateLimited(support, "Alliance_Propose", player) then
			return
		end
		if
			type(payload) ~= "table"
			or not Support.hasOnlyKeys(payload, { "to" })
			or not Validate.isClassId(payload.to)
		then
			Support.notice(support, player, "InvalidPayload", "Alliance_Propose needs a class.")
			return
		end

		local classId: ClassId? = Support.authenticated(support, player) :: any
		if classId == nil then
			return
		end
		if not Support.hasRole(support, player, "Politics") then
			Support.notice(support, player, "Rejected", "you may not propose alliances")
			return
		end
		local to: ClassId = payload.to :: any
		if classId == to then
			Support.notice(support, player, "Rejected", "a class cannot ally with itself")
			return
		end
		local match = Support.inWindow(support, player)
		if match == nil then
			return
		end

		local state = match:state()
		local proposal, reason = Alliances.propose(state, classId, to)
		if proposal == nil then
			Support.notice(support, player, "Rejected", reason)
			return
		end
		-- both classes hear about the proposal
		Support.patch(support, classId, "alliances", proposal)
		Support.patch(support, to, "alliances", proposal)
	end)

	support.remotes.Alliance_Respond.OnServerEvent:Connect(function(player: any, payload: any)
		if Support.rateLimited(support, "Alliance_Respond", player) then
			return
		end
		if
			type(payload) ~= "table"
			or not Support.hasOnlyKeys(payload, { "from", "accept" })
			or not Validate.isClassId(payload.from)
			or type(payload.accept) ~= "boolean"
		then
			Support.notice(
				support,
				player,
				"InvalidPayload",
				"Alliance_Respond needs a class and an answer."
			)
			return
		end

		local classId: ClassId? = Support.authenticated(support, player) :: any
		if classId == nil then
			return
		end
		if not Support.hasRole(support, player, "Politics") then
			Support.notice(support, player, "Rejected", "you may not answer alliances")
			return
		end
		local match = Support.inWindow(support, player)
		if match == nil then
			return
		end

		local state = match:state()
		local from: ClassId = payload.from :: any
		local proposal = proposalFor(state, from, classId)
		if proposal == nil then
			Support.notice(support, player, "Rejected", "there is no such alliance proposal")
			return
		end

		local alliance, reason = Alliances.respond(state, proposal.id, payload.accept)
		if alliance == nil then
			if reason ~= "" then
				Support.notice(support, player, "Rejected", reason)
			end
			return
		end
		Support.patch(support, alliance.members[1] :: any, "alliances", alliance)
		Support.patch(support, alliance.members[2] :: any, "alliances", alliance)
	end)

	support.remotes.Alliance_Break.OnServerEvent:Connect(function(player: any, payload: any)
		if Support.rateLimited(support, "Alliance_Break", player) then
			return
		end
		if type(payload) ~= "table" or not Support.hasOnlyKeys(payload, {}) then
			Support.notice(support, player, "InvalidPayload", "Alliance_Break takes no arguments.")
			return
		end

		local classId: ClassId? = Support.authenticated(support, player) :: any
		if classId == nil then
			return
		end
		if not Support.hasRole(support, player, "Politics") then
			Support.notice(support, player, "Rejected", "you may not break alliances")
			return
		end
		local match = Support.inWindow(support, player)
		if match == nil then
			return
		end

		local broken, reason = Alliances.breakAlliance(match:state(), classId)
		if not broken then
			Support.notice(support, player, "Rejected", reason)
		end
	end)
end

return AllianceHandlers
