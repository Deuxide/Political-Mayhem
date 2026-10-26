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
local Replication = require(script.Parent.Parent.Replication)

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
		-- both classes hear about the proposal; the active alliance list is
		-- untouched, and the other classes do not see the private proposal
		Replication.patch(support, classId, "allianceProposals", proposal, "append")
		Replication.patch(support, to, "allianceProposals", proposal, "append")
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
			-- The answer consumed the proposal (a decline, or an acceptance
			-- that lost the race for an alliance): both classes drop it.
			Replication.patch(support, proposal.from, "allianceProposals", proposal, "remove")
			Replication.patch(support, proposal.to, "allianceProposals", proposal, "remove")
			return
		end
		Replication.patch(support, proposal.from, "allianceProposals", proposal, "remove")
		Replication.patch(support, proposal.to, "allianceProposals", proposal, "remove")
		-- An active alliance is public (8.4): every client's cards get the
		-- badge, not only the two members.
		Replication.patchAll(support, "alliances", alliance, "append")
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

		local state = match:state()
		local alliance = Alliances.allianceOf(state, classId)
		local broken, reason = Alliances.breakAlliance(state, classId)
		if not broken then
			Support.notice(support, player, "Rejected", reason)
			return
		end
		if alliance ~= nil then
			-- The break is public (8.4): every client drops the badge.
			Replication.patchAll(support, "alliances", alliance, "remove")
		end
	end)
end

return AllianceHandlers
