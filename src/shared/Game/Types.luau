--!strict
-- Complete type definitions for all game state. Plain data only (no metatables, functions, or Instances).
-- Matches GAME_DESIGN.md section 4 and all related sections.

-- Base types
export type ClassId = "Working" | "Middle" | "Capitalist" | "State"
export type ResourceId = "Money" | "Influence" | "Food" | "Goods" | "Health" | "Education"
export type LineType = "Farm" | "Factory" | "Clinic" | "School"
export type PolicyId =
	"Wage"
	| "TaxWorking"
	| "TaxMiddle"
	| "TaxCapitalist"
	| "PublicServices"
	| "Tariff"
	| "StrikeRights"
export type Phase = "Window" | "Resolve" | "Reveal"
export type Difficulty = "Easy" | "Normal" | "Hard" | "Extreme"
export type VoteSide = "Yes" | "No"
export type PromiseKind = "Deliver" | "VoteYes" | "NoStrike" | "NoBreakAlliance"
export type InfoMode = "OpenInfo" | "PartialInfo" | "FogInfo"
export type VictoryKind = "None" | "Solo" | "Shared" | "Collapse"
export type EventKind =
	"HarvestFailure"
	| "ExportBoom"
	| "Pandemic"
	| "Recession"
	| "EducationGrant"
	| "Scandal"

-- Core resource bag for transfers, trades, and production
export type ResourceBag = {
	Money: number?,
	Influence: number?,
	Food: number?,
	Goods: number?,
	Health: number?,
	Education: number?,
}

-- Helper: fixed order for iteration (per ARCHITECTURE 3.1)
local CLASS_ORDER = { "Working", "Middle", "Capitalist", "State" }
local RESOURCE_ORDER = { "Money", "Influence", "Food", "Goods", "Health", "Education" }

-- 4.1 MatchState (top-level state)
export type MatchState = {
	id: string,
	seed: number,
	difficulty: Difficulty,
	day: number,
	phase: Phase,
	phaseEndsAt: number,
	stability: number,
	collapseCounter: number,
	policies: { [PolicyId]: number },
	classes: { [ClassId]: ClassState },
	lines: { [string]: Line },
	bills: { Bill },
	trades: { TradeOffer },
	promises: { Promise },
	alliances: { Alliance },
	reputation: { [ClassId]: ReputationEntry },
	drafts: { [ClassId]: ActionDraft },
	eventLog: { LogEntry },
	scheduledEvents: { EventId },
}

-- 4.2 ClassState (per class)
export type ClassState = {
	id: ClassId,
	money: number,
	influence: number,
	stock: Stock,
	vp: number,
	workers: number,
	seats: { string },
}

export type Stock = {
	food: number,
	goods: number,
	health: number,
	education: number,
}

-- 4.3 Line (production building)
export type Line = {
	id: string,
	type: LineType,
	owner: ClassId,
	openSlots: number,
	builtOnDay: number,
	assigned: number,
}

-- 4.4 Policy levels (stored in MatchState.policies)
-- Levels are 1-based: Wage 1=Low/2=Medium/3=High, Tax 0-3, PublicServices 0=Market/1=Universal, Tariff 0-2, StrikeRights 0=Outlawed/1=Allowed

-- 4.5 Bill (proposed policy change)
export type Bill = {
	id: string,
	policy: PolicyId,
	proposedLevel: number,
	proposer: ClassId,
	proposedDay: number,
	status: "Proposed" | "Voting" | "Passed" | "Failed" | "Withdrawn",
	votes: { [ClassId]: VoteRecord }?,
}

export type VoteRecord = {
	side: VoteSide,
	influenceCommitted: number,
}

-- 4.6 TradeOffer (live during Window)
export type TradeOffer = {
	id: string,
	from: ClassId,
	to: ClassId,
	give: ResourceBag,
	want: ResourceBag,
	promises: { PromiseSpec },
	expiresAt: number,
	status: "Pending" | "Accepted" | "Rejected" | "Cancelled",
}

export type PromiseSpec = {
	kind: PromiseKind,
	spec: DeliverSpec | VoteYesSpec | NoStrikeSpec | NoBreakAllianceSpec,
}

export type DeliverSpec = {
	resource: ResourceId,
	amount: number,
	to: ClassId,
	byDay: number,
}

export type VoteYesSpec = {
	policy: PolicyId,
	level: number,
	byDay: number,
}

export type NoStrikeSpec = {
	untilDay: number,
}

export type NoBreakAllianceSpec = {
	untilDay: number,
}

-- 4.7 Promise (recorded on acceptance)
export type Promise = {
	id: string,
	kind: PromiseKind,
	from: ClassId,
	to: ClassId,
	spec: DeliverSpec | VoteYesSpec | NoStrikeSpec | NoBreakAllianceSpec,
	createdDay: number,
	status: "Active" | "Kept" | "Broken",
}

-- 4.8 Alliance
export type Alliance = {
	id: string,
	a: ClassId,
	b: ClassId,
	createdDay: number,
	active: boolean,
}

-- 4.9 Reputation
export type ReputationEntry = {
	kept: number,
	broken: number,
}

-- 4.10 ActionDraft (sticky action set per class)
export type ActionDraft = {
	openSlots: { [string]: number },
	assign: { [string]: number },
	strike: ClassId?,
	build: LineType?,
	lobby: number?,
	market: {
		sell: ResourceBag,
		buy: ResourceBag,
	},
	votes: { [string]: VoteRecord },
	proposeBill: Bill?,
}

-- 4.11 LogEntry (for Evening Report)
export type LogEntry = {
	day: number,
	step: string,
	class: ClassId?,
	message: string,
	data: { [string]: any }?,
}

-- 4.12 PlayerView (filtered for replication)
export type PlayerView = {
	ownClass: ClassId,
	visibleState: MatchState,
	infoMode: InfoMode,
}

-- 4.13 VictoryResult
export type VictoryResult = {
	kind: VictoryKind,
	winner: ClassId?,
	winners: { ClassId }?,
	collapse: boolean?,
}

-- 4.14 Event (V2)
export type Event = {
	id: string,
	kind: EventKind,
	scheduledDay: number,
	forecast: boolean,
}

-- 4.15 Seat (for team support, V2)
export type Seat = {
	id: string,
	class: ClassId,
	players: { string },
	role: "Economy" | "Politics" | "Diplomacy" | "Advisor",
}

-- 4.16 BotPersona (V2)
export type BotPersona = "Cooperative" | "Opportunist" | "Hardliner"

-- 4.17 DifficultyConfig (data only, no code branches)
export type DifficultyConfig = {
	rounds: number,
	windowSeconds: number,
	revealSeconds: number,
	soloTarget: number,
	policiesEnabled: { PolicyId },
	infoMode: InfoMode,
	eventsEnabled: boolean,
	collapseEnabled: boolean,
	hintsEnabled: boolean,
	startResourceMultiplier: number,
	needsMultiplier: number,
	botSuggestions: boolean,
}

-- Utility: empty ResourceBag constructor
local function emptyResourceBag(): ResourceBag
	return {
		Money = 0,
		Influence = 0,
		Food = 0,
		Goods = 0,
		Health = 0,
		Education = 0,
	}
end

-- Utility: empty Stock constructor
local function emptyStock(): Stock
	return {
		food = 0,
		goods = 0,
		health = 0,
		education = 0,
	}
end

-- Re-export all runtime tables and utility functions
return {
	CLASS_ORDER = CLASS_ORDER,
	RESOURCE_ORDER = RESOURCE_ORDER,
	emptyResourceBag = emptyResourceBag,
	emptyStock = emptyStock,
}
