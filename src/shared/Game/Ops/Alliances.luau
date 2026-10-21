--!strict
-- Alliances (GAME_DESIGN 8.4): any two classes may form an alliance — one
-- proposes, the other accepts. A class has at most one alliance, either
-- side may break it at any time, and the break is public. The age of an
-- alliance counts the Days from its acceptance.
--
-- A pending proposal lives in the state, like the trade offers: it has to
-- survive between the two live actions (NETWORKING: `Alliance_Propose` then
-- `Alliance_Respond`).
local Types = require(script.Parent.Parent.Types)
local Promises = require(script.Parent.Parent.Ops.Promises)

type Alliance = Types.Alliance
type AllianceProposal = Types.AllianceProposal
type ClassId = Types.ClassId
type LogEntry = Types.LogEntry
type MatchState = Types.MatchState

local Alliances = {}

local function log(state: MatchState, entry: LogEntry)
	table.insert(state.eventLog, entry)
end

-- The alliance a class is in, or nil.
function Alliances.allianceOf(state: MatchState, classId: ClassId): Alliance?
	for _, alliance in state.alliances do
		for _, member in alliance.members do
			if member == classId then
				return alliance
			end
		end
	end
	return nil
end

-- The age of an alliance in Days, counted from its acceptance (8.4).
function Alliances.age(state: MatchState, alliance: Alliance): number
	return state.day - alliance.formedOnDay
end

-- Proposes an alliance. Both classes must be free: a class has at most one
-- alliance (8.4).
function Alliances.propose(
	state: MatchState,
	from: ClassId,
	to: ClassId
): (AllianceProposal?, string)
	if from == to then
		return nil, "a class cannot ally with itself"
	end
	if Alliances.allianceOf(state, from) ~= nil then
		return nil, `{from} already has an alliance`
	end
	if Alliances.allianceOf(state, to) ~= nil then
		return nil, `{to} already has an alliance`
	end

	local proposal: AllianceProposal = {
		id = `AllianceProposal-{#state.allianceProposals + 1}`,
		from = from,
		to = to,
		proposedDay = state.day,
	}
	table.insert(state.allianceProposals, proposal)
	return proposal, ""
end

local function removeProposal(state: MatchState, proposal: AllianceProposal)
	for i = 1, #state.allianceProposals do
		if state.allianceProposals[i].id == proposal.id then
			table.remove(state.allianceProposals, i)
			return
		end
	end
end

-- Answers a proposal: accepting forms the alliance, declining only drops
-- the proposal. The "at most one alliance" rule is checked again here.
function Alliances.respond(
	state: MatchState,
	proposalId: string,
	accept: boolean
): (Alliance?, string)
	local proposal: AllianceProposal? = nil
	for _, candidate in state.allianceProposals do
		if candidate.id == proposalId then
			proposal = candidate
			break
		end
	end
	if proposal == nil then
		return nil, "unknown alliance proposal"
	end

	if not accept then
		removeProposal(state, proposal)
		return nil, ""
	end

	if Alliances.allianceOf(state, proposal.from) ~= nil then
		removeProposal(state, proposal)
		return nil, `{proposal.from} already has an alliance`
	end
	if Alliances.allianceOf(state, proposal.to) ~= nil then
		removeProposal(state, proposal)
		return nil, `{proposal.to} already has an alliance`
	end

	local alliance: Alliance = {
		id = `Alliance-{#state.alliances + 1}`,
		members = { proposal.from, proposal.to },
		formedOnDay = state.day,
	}
	table.insert(state.alliances, alliance)
	removeProposal(state, proposal)

	log(state, {
		day = state.day,
		text = `{proposal.from} and {proposal.to} formed an alliance`,
	})
	return alliance, ""
end

-- Breaks the alliance of a class. The break is public (8.4) and it breaks
-- the open NoBreakAlliance promises between the two classes (8.3).
function Alliances.breakAlliance(state: MatchState, classId: ClassId): (boolean, string)
	local alliance = Alliances.allianceOf(state, classId)
	if alliance == nil then
		return false, `{classId} has no alliance to break`
	end

	local other: ClassId? = nil
	for _, member in alliance.members do
		-- for-in elements degrade to `string` in luau-lsp 1.70.1
		local memberId: ClassId = member :: any
		if memberId ~= classId then
			other = memberId
		end
	end

	for i = 1, #state.alliances do
		if state.alliances[i].id == alliance.id then
			table.remove(state.alliances, i)
			break
		end
	end

	if other ~= nil then
		Promises.deliver(state, { kind = "BreakAlliance", from = classId, to = other })
		log(state, {
			day = state.day,
			text = `{classId} broke the alliance with {other}`,
			actor = classId,
		})
	end
	return true, ""
end

return Alliances
