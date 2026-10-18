--!strict
-- Core type definitions for all game state. Plain data only (no metatables, functions, or Instances).

export type ClassId = "Working" | "Middle" | "Capitalist" | "State"
export type ResourceId = "Money" | "Influence" | "Food" | "Goods" | "Health" | "Education"
export type Phase = "ActionWindow" | "Resolve" | "Reveal" | "VictoryCheck"
export type Difficulty = "Easy" | "Normal" | "Hard" | "Extreme"
export type LineType = "Farm" | "Factory" | "Clinic" | "School"

-- Placeholder for the full MatchState (expanded in M1-T1)
export type MatchState = {
	difficulty: Difficulty,
	round: number,
	phase: Phase,
	classes: { [ClassId]: ClassState },
	policyState: PolicyState,
	eventLog: { LogEntry },
	rngSeed: number,
}

export type ClassState = {
	id: ClassId,
	resources: { [ResourceId]: number },
	lines: { [string]: LineState },
	stability: number,
	victoryPoints: number,
	influence: number,
	reputation: { [ClassId]: number },
	alliances: { [ClassId]: boolean },
	promises: { Promise },
	activeStrikes: { [string]: boolean },
}

export type LineState = {
	id: string,
	type: LineType,
	owner: ClassId,
	slots: number,
	staffed: number,
	active: boolean,
	underConstruction: boolean,
}

export type PolicyState = {
	tracks: { [string]: PolicyTrackState },
}

export type PolicyTrackState = {
	level: number,
	maxLevel: number,
}

export type Promise = {
	id: string,
	from: ClassId,
	to: ClassId,
	kind: "Deliver" | "VoteYes" | "NoStrike" | "NoBreakAlliance",
	terms: { [string]: any },
	createdRound: number,
	expiresRound: number?,
	status: "Active" | "Fulfilled" | "Broken",
}

export type LogEntry = {
	round: number,
	step: string,
	class: ClassId?,
	message: string,
	data: { [string]: any }?,
}

export type ActionDraft = {
	class: ClassId,
	buildQueue: { LineType },
	strikeLines: { string },
	tradeOffers: { TradeOffer },
	policyVotes: { [string]: boolean },
	allianceActions: { AllianceAction },
	promiseProposals: { Promise },
	lobbying: { [string]: number },
}

export type TradeOffer = {
	id: string,
	from: ClassId,
	to: ClassId,
	give: { [ResourceId]: number },
	take: { [ResourceId]: number },
	expiresRound: number,
	status: "Pending" | "Accepted" | "Rejected" | "Cancelled",
}

export type AllianceAction = {
	type: "Propose" | "Accept" | "Break",
	target: ClassId,
}

export type Bill = {
	id: string,
	policyTrack: string,
	proposedLevel: number,
	proposer: ClassId,
	coSponsors: { ClassId },
	createdRound: number,
	votes: { [ClassId]: VoteRecord }?,
	status: "Proposed" | "Voting" | "Passed" | "Failed" | "Withdrawn",
}

export type VoteRecord = {
	inFavor: boolean,
	influenceSpent: number,
}

export type PlayerView = {
	ownClass: ClassId,
	visibleState: MatchState, -- filtered per info mode
	infoMode: "OpenInfo" | "PartialInfo" | "FogInfo",
}

export type VictoryResult = {
	kind: "None" | "Solo" | "Shared",
	classes: { ClassId }?,
}

export type GameEvent = {
	id: string,
	kind: string,
	round: number,
	affectedClasses: { ClassId },
	payload: { [string]: any },
}
