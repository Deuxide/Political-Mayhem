--!strict
-- Builds the initial plain MatchState (GAME_DESIGN section 4 state shape,
-- section 5.2 starting values). Deterministic: same
-- (difficulty, seats, seed) -> an identical state.
-- startResourceMultiplier semantics (DECISIONS): scales only each class's
-- starting Money, Influence, and stock amounts, floored to whole units;
-- workers and owned lines are never scaled.

local Types = require(script.Parent.Parent.Types)
local RuleSet = require(script.Parent.Parent.RuleSet)
local assertSerializable = require(script.Parent.assertSerializable)
local ConfigClasses = require(script.Parent.Parent.Parent.Config.Classes)
local ConfigLines = require(script.Parent.Parent.Parent.Config.Lines)
local ConfigPolicies = require(script.Parent.Parent.Parent.Config.Policies)

type ClassId = Types.ClassId
type StockId = Types.StockId
type LineId = Types.LineId
type LineType = Types.LineType
type PolicyId = Types.PolicyId
type SeatId = Types.SeatId
type ClassState = Types.ClassState
type MatchState = Types.MatchState
type ClassEntry = ConfigClasses.ClassEntry

-- GAME_DESIGN section 4 starts stability at 60 for every difficulty (the
-- section 12 matrix leaves no column for it), so this is the one
-- state-initialization constant that lives here instead of Config.
local START_STABILITY = 60

export type SeatMap = { [ClassId]: { SeatId } }

local StateFactory = {}

local function validateSeats(seats: SeatMap)
	local seen: { [SeatId]: ClassId } = {}
	for index = 1, #Types.CLASS_IDS do
		-- luau-lsp 1.70.1: `::` casts never narrow; annotate the local and trip
		-- the value through `any` instead
		local classId: ClassId = Types.CLASS_IDS[index] :: any
		local list = (seats :: any)[classId]
		if list == nil or #list == 0 then
			error(`StateFactory.create: seats missing or empty for class '{classId}'`, 0)
		end
		for _, seatId in list do
			if seen[seatId] ~= nil then
				error(`StateFactory.create: seat '{seatId}' is assigned to more than one class`, 0)
			end
			seen[seatId] = classId
		end
	end
end

local function initialLines(): { [LineId]: Types.Line }
	-- "LineType-N" ids numbered per type across all classes, in CLASS_IDS x
	-- LINE_TYPES order, so ids and numbering are stable (DECISIONS).
	local counters: { [LineType]: number } = {}
	local lines: { [LineId]: Types.Line } = {}
	for ci = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[ci] :: any
		local entry = ConfigClasses.entries[classId] :: ClassEntry
		for li = 1, #Types.LINE_TYPES do
			local lineType: LineType = Types.LINE_TYPES[li] :: any
			local count = (entry.startLines :: { [LineType]: number })[lineType] or 0
			for _ = 1, count do
				counters[lineType] = (counters[lineType] or 0) + 1
				local lineId: LineId = `{lineType}-{counters[lineType]}`
				lines[lineId] = {
					id = lineId,
					type = lineType,
					owner = classId,
					openSlots = ConfigLines[lineType].slotsMax,
					builtOnDay = 0, -- initial lines were never built during a Day
					assigned = 0,
				} :: Types.Line
			end
		end
	end
	return lines
end

local function initialDraft(): Types.ActionDraft
	-- GAME_DESIGN section 9: sticky drafts start empty; live actions (trades,
	-- alliances, bill proposals) have no draft fields at all.
	return {
		sequence = 0,
		openSlots = {},
		assign = {},
		market = { sell = {}, buy = {} },
		votes = {},
	} :: Types.ActionDraft
end

function StateFactory.create(difficulty: Types.Difficulty, seats: SeatMap, seed: number): MatchState
	local rules = RuleSet.new(difficulty) -- the single difficulty-name validation point
	validateSeats(seats)
	local multiplier = rules:startResourceMultiplier()
	local scale = function(amount: number): number
		return math.floor(amount * multiplier)
	end

	local classes: { [ClassId]: ClassState } = {}
	for ci = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[ci] :: any
		local entry = ConfigClasses.entries[classId] :: ClassEntry
		local stock: { [StockId]: number } = {}
		for si = 1, #Types.STOCK_IDS do
			local stockId: StockId = Types.STOCK_IDS[si] :: any
			stock[stockId] = scale((entry.startStock :: { [StockId]: number })[stockId])
		end
		local classSeats: { SeatId } = {}
		for _, seatId in ((seats :: any)[classId]) :: { SeatId } do
			table.insert(classSeats, seatId)
		end
		classes[classId] = {
			id = classId,
			money = scale(entry.startMoney),
			influence = scale(entry.startInfluence),
			stock = stock,
			vp = 0,
			workers = entry.startWorkers, -- workers are never scaled (DECISIONS)
			seats = classSeats,
		} :: ClassState
	end

	-- Policies: only the tracks the difficulty enables, at their default
	-- levels (DECISIONS); disabled tracks are absent from the map.
	local policies: { [PolicyId]: number } = {}
	for pi = 1, #Types.POLICY_IDS do
		local policyId: PolicyId = Types.POLICY_IDS[pi] :: any
		if rules:isPolicyEnabled(policyId) then
			policies[policyId] = ConfigPolicies.tracks[policyId].default
		end
	end

	local drafts: { [ClassId]: Types.ActionDraft } = {}
	local reputation: { [ClassId]: Types.Reputation } = {}
	for di = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[di] :: any
		drafts[classId] = initialDraft()
		reputation[classId] = { kept = 0, broken = 0 } :: Types.Reputation
	end

	local state: MatchState = {
		id = `mayhem-{math.floor(seed)}`,
		seed = seed,
		difficulty = difficulty,
		day = 1,
		phase = "Window",
		-- Timestamps belong to the scheduler (DECISIONS): creation calls no
		-- os.* so it stays deterministic; the phase is unscheduled for now.
		phaseEndsAt = 0,
		stability = START_STABILITY,
		collapseCounter = 0,
		policies = policies,
		classes = classes,
		lines = initialLines(),
		bills = {},
		trades = {},
		promises = {},
		alliances = {},
		allianceProposals = {},
		reputation = reputation,
		drafts = drafts,
		eventLog = {},
		scheduledEvents = {},
	} :: MatchState

	assertSerializable.assert(state :: any)
	return state
end

return table.freeze(StateFactory)
