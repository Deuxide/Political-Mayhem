--!strict
-- Bills (GAME_DESIGN 7.3): the live-bill rules the server's Bill_Propose
-- handler and the R3 Bills step share. A module of functions over state —
-- no class, no state of its own.
--
-- Proposing (7.3): a class may propose one bill per Day, changing one
-- track to a new level (by at most 1 step for tracks with 4+ levels, any
-- level otherwise). It costs 1 Influence (the State proposes for free).
-- Proposals close 20 s before the Window ends, and at most 2 bills may be
-- live at once. The caller passes the seconds left in the Window — this
-- module never reads a clock.
--
-- Voting (7.3): every class has base votes (Working 4, Middle 3,
-- Capitalist 2, State 3) and may commit Influence to a side, each Influence
-- adding 1 vote weight. A class that does not vote abstains and adds
-- nothing. A bill passes when yesWeight > noWeight and yesWeight reaches
-- the quorum (5); ties fail. The committed Influence is spent whether or
-- not the bill passes. Ballots are secret until the Closing Bell, so the
-- tally returns the aggregate weights only — never who voted what.

local Types = require(script.Parent.Parent.Types)
local StateOps = require(script.Parent.Parent.State.StateOps)
local ConfigClasses = require(script.Parent.Parent.Parent.Config.Classes)
local ConfigPolicies = require(script.Parent.Parent.Parent.Config.Policies)

type Bill = Types.Bill
type BillId = Types.BillId
type ClassId = Types.ClassId
type MatchState = Types.MatchState
type PolicyId = Types.PolicyId
type VoteSide = Types.VoteSide

-- The outcome of a tally. Aggregate only: the ballots stay secret.
export type Tally = {
	yesWeight: number,
	noWeight: number,
	passed: boolean,
	reason: string,
}

local Bills = {}

-- The track of a policy, or nil when that track is not active in this
-- match (Easy enables only three of the seven, 7.2).
local function trackOf(state: MatchState, policyId: PolicyId): ConfigPolicies.PolicyTrack?
	local level = (state.policies :: any)[policyId]
	if level == nil then
		return nil
	end
	return ConfigPolicies.tracks[policyId]
end

-- Whether a class may propose this bill right now, and why not (7.3).
-- `secondsLeft` is the time left in the Window; the proposal cutoff is
-- `cutoffSeconds` before the Window ends.
function Bills.canPropose(
	state: MatchState,
	classId: ClassId,
	policyId: PolicyId,
	level: number,
	secondsLeft: number
): (boolean, string)
	local track = trackOf(state, policyId)
	if track == nil then
		return false, `the {policyId} track is not active in this match`
	end
	if level < track.minLevel or level > track.maxLevel then
		return false, `level {level} is out of range for {policyId}`
	end

	-- A track with 4+ levels moves by at most one step; the shorter tracks
	-- may jump to any level.
	local levelCount = track.maxLevel - track.minLevel + 1
	if levelCount >= 4 then
		local current = (state.policies :: any)[policyId]
		if math.abs(level - current) > 1 then
			return false, `{policyId} changes by at most 1 step`
		end
	end

	if secondsLeft <= ConfigPolicies.bills.cutoffSeconds then
		return false, "the proposal window has closed"
	end

	-- One bill per class per Day (7.3).
	for _, bill in state.bills do
		if bill.proposer == classId then
			return false, `{classId} already proposed a bill today`
		end
	end

	if #state.bills >= ConfigPolicies.bills.maxLive then
		return false, `at most {ConfigPolicies.bills.maxLive} bills can be live at once`
	end

	-- The cost: 1 Influence, the State proposes for free.
	if classId ~= "State" then
		local cost = ConfigPolicies.bills.proposeCost
		if state.classes[classId].influence < cost then
			return false, `{classId} has not enough Influence to propose`
		end
	end

	return true, ""
end

-- Proposes a bill: validates, pays the cost, and adds it to the live bills.
-- Returns the new bill, or nil and the reason it was refused.
function Bills.propose(
	state: MatchState,
	classId: ClassId,
	policyId: PolicyId,
	level: number,
	secondsLeft: number
): (Bill?, string)
	local ok, reason = Bills.canPropose(state, classId, policyId, level, secondsLeft)
	if not ok then
		return nil, reason
	end

	if classId ~= "State" then
		local cost = ConfigPolicies.bills.proposeCost
		StateOps.subtractResource(state, classId, "Influence", cost)
	end

	local bill: Bill = {
		id = `Bill-{#state.bills + 1}`,
		policyId = policyId,
		level = level,
		proposer = classId,
		proposedDay = state.day,
	}
	table.insert(state.bills, bill)
	return bill, ""
end

-- The Influence a class committed to a vote, clamped to what it still has
-- (it may have spent Influence on a lobby earlier the same Day, 7.1).
function Bills.committedBy(state: MatchState, classId: ClassId, billId: BillId): number
	local vote = state.drafts[classId].votes[billId]
	if vote == nil then
		return 0
	end
	return math.min(vote.influence, state.classes[classId].influence)
end

-- The vote tally of a bill (7.3). The result holds the aggregate weights
-- only — the ballots stay secret.
function Bills.tally(state: MatchState, billId: BillId): Tally
	local yesWeight = 0
	local noWeight = 0

	for ci = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[ci] :: any
		local vote = state.drafts[classId].votes[billId]
		if vote ~= nil then
			local entry = ConfigClasses.entries[classId] :: ConfigClasses.ClassEntry
			local weight = entry.baseVotes + Bills.committedBy(state, classId, billId)
			if vote.side == "yes" then
				yesWeight += weight
			else
				noWeight += weight
			end
		end
	end

	local quorum = ConfigPolicies.bills.quorum
	local passed = yesWeight > noWeight and yesWeight >= quorum

	local reason = "passed"
	if yesWeight == noWeight then
		reason = "tie"
	elseif yesWeight < noWeight then
		reason = "more against than for"
	elseif yesWeight < quorum then
		reason = "not enough support"
	end

	return {
		yesWeight = yesWeight,
		noWeight = noWeight,
		passed = passed,
		reason = reason,
	}
end

-- Spends the Influence committed to a vote, whether or not the bill passes
-- (7.3). Returns what was spent per class.
function Bills.spendCommitted(state: MatchState, billId: BillId): { [ClassId]: number }
	local spent: { [ClassId]: number } = {}
	for ci = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[ci] :: any
		local amount = Bills.committedBy(state, classId, billId)
		if amount > 0 then
			StateOps.subtractResource(state, classId, "Influence", amount)
			spent[classId] = amount
		end
	end
	return spent
end

-- The side a class voted, or nil when it abstained. Kept beside the tally
-- so the R3 step can log the outcome without exposing the ballots.
function Bills.sideOf(state: MatchState, classId: ClassId, billId: BillId): VoteSide?
	local vote = state.drafts[classId].votes[billId]
	if vote == nil then
		return nil
	end
	return vote.side
end

return Bills
