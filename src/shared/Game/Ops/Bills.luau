--!strict
-- Bill operations: propose validation, vote tally, apply effects.

local Types = require(script.Parent.Parent.Types)

export type Bills = {
	validatePropose: (
		state: Types.MatchState,
		bill: Types.Bill,
		ruleSet: any
	) -> (boolean, string?),
	tallyVotes: (
		state: Types.MatchState,
		bill: Types.Bill
	) -> (boolean, { [Types.ClassId]: number }),
	applyEffect: (state: Types.MatchState, bill: Types.Bill, config: any) -> (),
}

local Bills = {}

function Bills.validatePropose(
	state: Types.MatchState,
	bill: Types.Bill,
	ruleSet: any
): (boolean, string?)
	-- Check policy exists and is enabled
	if not ruleSet:isPolicyEnabled(bill.policyTrack) then
		return false, "Policy track is disabled for this difficulty"
	end

	-- Check proposer has enough influence
	local proposerState = state.classes[bill.proposer]
	if not proposerState then return false, "Invalid proposer" end

	-- Check influence cost (placeholder)
	local cost = 10 -- TODO: from config
	if proposerState.influence < cost then return false, "Insufficient influence" end

	-- Check co-sponsors are valid
	for _, sponsor in ipairs(bill.coSponsors) do
		if not state.classes[sponsor] then return false, "Invalid co-sponsor: " .. sponsor end
	end

	return true, nil
end

function Bills.tallyVotes(
	state: Types.MatchState,
	bill: Types.Bill
): (boolean, { [Types.ClassId]: number })
	local votes = bill.votes or {}
	local forVotes = 0
	local againstVotes = 0
	local totalInfluence = 0

	for classId, voteRecord in pairs(votes) do
		if voteRecord.inFavor then
			forVotes += voteRecord.influenceSpent
		else
			againstVotes += voteRecord.influenceSpent
		end
		totalInfluence += voteRecord.influenceSpent
	end

	-- Quorum: at least 2 classes voted (placeholder)
	local votingClasses = 0
	for _ in pairs(votes) do
		votingClasses += 1
	end

	if votingClasses < 2 then
		return false, { Working = 0, Middle = 0, Capitalist = 0, State = 0 }
	end

	-- Tie goes to status quo (against)
	local passed = forVotes > againstVotes

	local result: { [Types.ClassId]: number } = {
		Working = 0,
		Middle = 0,
		Capitalist = 0,
		State = 0,
	}
	for classId, voteRecord in pairs(votes) do
		result[classId] = voteRecord.influenceSpent
	end

	return passed, result
end

function Bills.applyEffect(state: Types.MatchState, bill: Types.Bill, config: any)
	-- TODO: Apply policy effects via PolicyRegistry (M3-T3)
	local track = state.policyState.tracks[bill.policyTrack]
	if track then track.level = bill.proposedLevel end
end

return Bills
