--!strict
-- All game state types live here (ARCHITECTURE 3.1). Everything below is
-- plain, serializable data (no metatables, functions, or Instances inside
-- state; State.assertSerializable holds the line). Tunable numbers live in
-- Config/*; these types only fix shapes. Field names and shapes follow
-- docs/GAME_DESIGN.md sections 4, 6 to 9, 11 to 13 (M1-T1).

local Types = {}

-- ===== Enums =====

-- The four social classes (GAME_DESIGN 2). Exactly four per match, always.
export type ClassId = "Working" | "Middle" | "Capitalist" | "State"

-- The six resources (D-008); Money/Influence are class fields, the rest stock.
export type ResourceId = "Money" | "Influence" | "Food" | "Goods" | "Health" | "Education"

-- Stock keys of ClassState (lowercase per GAME_DESIGN 4; ResourceId minus
-- Money and Influence).
export type StockId = "food" | "goods" | "health" | "education"

-- Soft phases of a Day (GAME_DESIGN 3.1). "Market Hours" and friends are
-- player-facing names only (D-021); code compares these values.
export type Phase = "Window" | "Resolve" | "Reveal"

-- Difficulty modes. Behavior comes from Config, never from name checks (M5-T3).
export type Difficulty = "Easy" | "Normal" | "Hard" | "Extreme"

-- Policy tracks (GAME_DESIGN 7.2); state holds the current level per track.
export type PolicyId =
	"Wage"
	| "TaxWorking"
	| "TaxMiddle"
	| "TaxCapitalist"
	| "PublicServices"
	| "Tariff"
	| "StrikeRights"

-- Production line types (GAME_DESIGN 6.1); ids like "Farm-1".
export type LineType = "Farm" | "Factory" | "Clinic" | "School"

-- Promise kinds (GAME_DESIGN 8.3): the four auditable agreement shapes.
export type PromiseKind = "Deliver" | "VoteYes" | "NoStrike" | "NoBreakAlliance"

-- Ballot side (GAME_DESIGN 7.3); abstaining is simply no votes entry.
export type VoteSide = "yes" | "no"

-- Info tier for others' Money/stocks in partial mode (GAME_DESIGN 13;
-- breakpoints are Config data). Hidden info = omitted keys, never sentinels.
export type PowerTier = "Low" | "Mid" | "High"

-- Info-mode selector (GAME_DESIGN 13); Config/Difficulty carries one per
-- difficulty and Wealth picks the strategy class. Never name-compare
-- difficulties: read this selector instead.
export type InfoMode = "open" | "partial" | "fog"

-- How a match ended (GAME_DESIGN 11.2): solo, shared alliance, final-Day
-- comparison, or collapse (no winner).
export type VictoryKind = "solo" | "shared" | "final" | "collapse"

-- Team roles on a class (GAME_DESIGN 14, NETWORKING 6): who may touch which
-- part of the draft or which live action.
export type Role = "Economy" | "Politics" | "Diplomacy" | "Advisor"

-- Chat channels (NETWORKING 3.1). "Class" targets one class, "Team" the
-- sender's own class team.
export type ChatChannel = "Global" | "Team" | "Class"

-- ===== Id aliases =====

-- IDs are strings (GAME_DESIGN 4); aliases below document the intent of each.

-- One seat on a class (human or bot), e.g. "Seat-1".
export type SeatId = string

-- A production line, e.g. "Farm-1".
export type LineId = string

-- A live bill proposal within its Day.
export type BillId = string

-- A live trade offer within its Window.
export type TradeId = string

-- A promise record, unique over the whole match.
export type PromiseId = string

-- An alliance record, unique over the whole match.
export type AllianceId = string

-- A scheduled random event (V2; concrete ids arrive with Config/Events, M12).
export type EventId = string

-- ===== Economy =====

-- Any-resource amount table for Transfers, trades, and promise Deliver specs
-- (key omitted = 0).
export type ResourceBag = { [ResourceId]: number }

-- Stock-resource amount table for market orders (GAME_DESIGN 6.6).
export type MarketBag = { [StockId]: number }

-- A class's market submission for one Day; not sticky, cleared at Closing
-- Bell to avoid accidental repeats (GAME_DESIGN 6.6, section 9).
export type MarketOrder = {
	sell: MarketBag,
	buy: MarketBag,
}

-- A production line (GAME_DESIGN 6.1). openSlots is sticky (owner-set);
-- assigned counts this Day's staffed attempts (Working sets it).
export type Line = {
	id: LineId,
	type: LineType,
	owner: ClassId,
	openSlots: number, -- sticky, 0..slotsMax per Config/Lines
	builtOnDay: number, -- becomes active the Day after being built (0 = initial)
	assigned: number, -- workers assigned this Day
}

-- Per-class resources and progress (GAME_DESIGN 4). workers is meaningful
-- only for Working (0 for the others); seats lists the class's seat ids.
export type ClassState = {
	id: ClassId,
	money: number,
	influence: number,
	stock: { [StockId]: number },
	vp: number,
	workers: number,
	seats: { SeatId },
}

-- ===== politics: bills, votes, promises, alliances =====

-- Ballot committed to one bill: side plus extra Influence (spent regardless of
-- the outcome, GAME_DESIGN 7.3).
export type VoteSpec = {
	side: VoteSide,
	influence: number,
}

-- A proposed single-track level change awaiting its Closing Bell tally; the
-- ballots themselves stay in the drafts and are secret until Closing Bell.
export type Bill = {
	id: BillId,
	policyId: PolicyId,
	level: number, -- proposed target level
	proposer: ClassId,
	proposedDay: number,
}

-- The auditable parameter set per PromiseKind (GAME_DESIGN 8.3).
export type PromiseSpec =
	| { kind: "Deliver", resource: ResourceId, amount: number, to: ClassId, byDay: number }
	| { kind: "VoteYes", policyId: PolicyId, level: number, byDay: number }
	| { kind: "NoStrike", untilDay: number }
	| { kind: "NoBreakAlliance", untilDay: number }

-- A promise record. Not enforced by the game; audited for Reputation (8.3).
-- `progress` holds what the promise has collected so far, so the audit can
-- look at the events that happened instead of the drafts that are gone.
export type PromiseProgress = {
	delivered: number?, -- Deliver: the amount transferred so far
	yesVoted: boolean?, -- VoteYes: a matching yes vote was cast
	struck: boolean?, -- NoStrike: the promisor struck the promisee
	broken: boolean?, -- NoBreakAlliance: the alliance was broken
}

export type Promise = {
	id: PromiseId,
	kind: PromiseKind,
	spec: PromiseSpec,
	from: ClassId, -- promisor
	to: ClassId, -- promisee
	createdDay: number,
	status: "open" | "kept" | "broken",
	progress: PromiseProgress,
}

-- A live trade offer during the Window (GAME_DESIGN 8.2); expires with the
-- Window. Acceptance executes give/want immediately and creates Promise
-- records for attached specs.
export type TradeOffer = {
	id: TradeId,
	from: ClassId,
	to: ClassId,
	give: ResourceBag, -- what `from` sends
	want: ResourceBag, -- what `from` asks back
	promises: { PromiseSpec },
	expiresAt: number,
}

-- One active alliance (GAME_DESIGN 8.4; at most one per class, exactly two
-- members). Age counts in Days from acceptance (formedOnDay).
export type Alliance = {
	id: AllianceId,
	members: { ClassId },
	formedOnDay: number,
}

-- A pending alliance proposal: one class proposes, the other accepts
-- (GAME_DESIGN 8.4). Live during the Window, like the trade offers.
export type AllianceProposal = {
	id: string,
	from: ClassId,
	to: ClassId,
	proposedDay: number,
}

-- Promise-keeping tally for one class: display value and bot trust input (8.3).
export type Reputation = {
	kept: number,
	broken: number,
}

-- ===== Actions (the draft) =====

-- Influence purchase request this Day (GAME_DESIGN 9 "lobby"); allowed
-- classes, per-Influence Money cost, and per-Day caps come from Config.
export type LobbySpec = { amount: number }

-- One new line purchase attempt this Day; the Build step pays the cost and
-- queues it as active next Day (GAME_DESIGN 6.2).
export type BuildSpec = { lineType: LineType }

-- Working's strike attempt against one class (GAME_DESIGN 6.5); sticky until
-- cleared.
export type StrikeSpec = { target: ClassId }

-- The per-class sticky action set edited during the Window (GAME_DESIGN 9).
-- Live actions (trade offers and responses, alliance moves, bill proposals,
-- chat) are separate immediates and have no draft fields here.
export type ActionDraft = {
	sequence: number, -- bumped on each accepted client update
	locked: boolean, -- the class locked its draft in early (NETWORKING 3.1)
	openSlots: { [LineId]: number }, -- line owners
	assign: { [LineId]: number }, -- Working only
	strike: StrikeSpec?, -- Working only
	build: BuildSpec?, -- line owners
	lobby: LobbySpec?, -- Capitalist, Middle
	market: MarketOrder, -- all
	votes: { [BillId]: VoteSpec }, -- all; bills are per Day
}

-- ===== Reporting and victory =====

-- One append-only Evening Report line with its one-line cause; the only
-- collection whose order carries meaning (GAME_DESIGN 4).
export type LogEntry = {
	day: number,
	text: string,
	actor: ClassId?, -- class the entry is about, when there is one
}

-- End-of-match result (GAME_DESIGN 11.2): exactly one winner solo/final,
-- exactly two on shared, none on collapse. Tie-breaks resolve before storing.
export type VictoryResult = {
	kind: VictoryKind,
	winners: { ClassId },
	day: number,
}

-- ===== Information visibility =====

-- Others' Money/stock value as seen by the viewer: exact number (open or
-- allied), tier string (partial), or omitted key (fog).
export type Tiered = number | PowerTier | nil

-- Others' line summary; exact in every info mode (GAME_DESIGN 13).
export type LineView = {
	id: LineId,
	type: LineType,
	owner: ClassId,
	openSlots: number,
}

-- One non-viewer class as the viewer sees it (GAME_DESIGN 13).
export type ClassView = {
	money: Tiered,
	stock: { [StockId]: Tiered },
	influence: number?, -- exact in open, hidden elsewhere
	vp: number, -- exact in every mode
	lines: { LineView }, -- exact in every mode
}

-- The viewer's own daily need per stock resource, already scaled by the
-- difficulty (GAME_DESIGN 5.3, 12). Only the own class needs it: the panel
-- shows what this Day's Upkeep will consume.
export type NeedsTable = { [StockId]: number }

-- What a viewer gets to see of the match (GAME_DESIGN 13). Built by
-- Visibility/PlayerViewBuilder from the info-mode strategy; the server sends
-- only this shape, never raw MatchState.
export type PlayerView = {
	viewer: ClassId,
	day: number,
	phase: Phase,
	stability: number,
	policies: { [PolicyId]: number },
	own: ClassState,
	needs: NeedsTable, -- the viewer's own needs for this Day (5.3, 12)
	draft: ActionDraft, -- the viewer's class draft (NETWORKING 4)
	others: { [ClassId]: ClassView },
	bills: { Bill }, -- live proposals; ballots stay secret in the drafts
	promises: { Promise }, -- public in every mode
	alliances: { Alliance }, -- public in every mode
	reputation: { [ClassId]: Reputation }, -- public in every mode
	victory: VictoryResult?, -- nil until the match ends
}

-- ===== Root =====

-- The entire match state (GAME_DESIGN 4): plain and serializable, held by the
-- Match facade. bills/trades/promises/alliances/eventLog/scheduledEvents are
-- arrays by design, but resolution logic must not rely on their order (sort by
-- id when order matters); everything else is keyed tables.
export type MatchState = {
	id: string, -- match id, deterministic from the seed (e.g. "mayhem-<seed>")
	seed: number,
	difficulty: Difficulty,
	day: number,
	phase: Phase,
	phaseEndsAt: number, -- epoch seconds when the current phase ends; 0 = unscheduled
	stability: number, -- 0..100
	collapseCounter: number, -- consecutive Days at stability 0
	policies: { [PolicyId]: number },
	classes: { [ClassId]: ClassState },
	lines: { [LineId]: Line },
	bills: { Bill }, -- live this Day (at most 2)
	trades: { TradeOffer }, -- live this Window
	promises: { Promise },
	alliances: { Alliance },
	allianceProposals: { AllianceProposal }, -- live this Window
	reputation: { [ClassId]: Reputation },
	drafts: { [ClassId]: ActionDraft },
	eventLog: { LogEntry },
	scheduledEvents: { EventId }, -- V2, empty on Easy/Normal
	victory: VictoryResult?, -- set once when the match ends (11.2, D-070)
}

-- ===== Runtime mirrors =====

-- Runtime mirrors of the unions above, same order, so validation and
-- iteration have a single source to read. Frozen: enums are constants, not
-- data. Canonical iteration order contracts are M1-T5.
local CLASS_IDS: { ClassId } = { "Working", "Middle", "Capitalist", "State" }
local RESOURCE_IDS: { ResourceId } =
	{ "Money", "Influence", "Food", "Goods", "Health", "Education" }
local STOCK_IDS: { StockId } = { "food", "goods", "health", "education" }
local PHASES: { Phase } = { "Window", "Resolve", "Reveal" }
local DIFFICULTIES: { Difficulty } = { "Easy", "Normal", "Hard", "Extreme" }
local POLICY_IDS: { PolicyId } = {
	"Wage",
	"TaxWorking",
	"TaxMiddle",
	"TaxCapitalist",
	"PublicServices",
	"Tariff",
	"StrikeRights",
}
local LINE_TYPES: { LineType } = { "Farm", "Factory", "Clinic", "School" }
local ROLES: { Role } = { "Economy", "Politics", "Diplomacy", "Advisor" }
local CHAT_CHANNELS: { ChatChannel } = { "Global", "Team", "Class" }

Types.CLASS_IDS = table.freeze(CLASS_IDS)
Types.RESOURCE_IDS = table.freeze(RESOURCE_IDS)
Types.STOCK_IDS = table.freeze(STOCK_IDS)
Types.PHASES = table.freeze(PHASES)
Types.DIFFICULTIES = table.freeze(DIFFICULTIES)
Types.POLICY_IDS = table.freeze(POLICY_IDS)
Types.LINE_TYPES = table.freeze(LINE_TYPES)
Types.ROLES = table.freeze(ROLES)
Types.CHAT_CHANNELS = table.freeze(CHAT_CHANNELS)

return table.freeze(Types)
