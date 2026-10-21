--!strict
-- R1 LockDrafts (GAME_DESIGN section 10, section 9): the drafts are frozen
-- at Closing Bell and their invalid fields are dropped with a log entry, so
-- every step that follows only sees well-formed actions.
--
-- Invalid means "cannot be acted on at all": an entry for a line that does
-- not exist, a value that is not a whole number in range, a line type or
-- resource that does not exist, a strike against an impossible target, a
-- vote for a bill that is not on the table, a field set by a class that
-- does not own it. Deliberately NOT dropped: an assignment above a line's
-- open slots or above the worker pool (6.3 says those are ignored, not
-- invalid) and a build the class may not make or cannot afford (R4 skips
-- those with their own log).
--
-- The freeze itself is the server's job (M6 stops accepting draft edits
-- while the resolution runs); the shared side is this validation.

local Types = require(script.Parent.Parent.Types)
local Step = require(script.Parent.Step)
local ConfigLines = require(script.Parent.Parent.Parent.Config.Lines)

type ClassId = Types.ClassId
type LineId = Types.LineId
type LineType = Types.LineType
type LogEntry = Types.LogEntry
type MatchState = Types.MatchState
type StockId = Types.StockId

-- Membership sets over the frozen mirrors (built once, deterministically).
local LINE_TYPES: { [string]: boolean } = {}
for i = 1, #Types.LINE_TYPES do
	local lineType: LineType = Types.LINE_TYPES[i] :: any
	LINE_TYPES[lineType] = true
end

local STOCK_IDS: { [string]: boolean } = {}
for i = 1, #Types.STOCK_IDS do
	local stockId: StockId = Types.STOCK_IDS[i] :: any
	STOCK_IDS[stockId] = true
end

local CLASS_IDS: { [string]: boolean } = {}
for i = 1, #Types.CLASS_IDS do
	local classId: ClassId = Types.CLASS_IDS[i] :: any
	CLASS_IDS[classId] = true
end

local function log(state: MatchState, entry: LogEntry)
	table.insert(state.eventLog, entry)
end

-- A whole number that is not negative.
local function isWholeNumber(value: number): boolean
	return value >= 0 and value == math.floor(value)
end

local function isKnownBill(state: MatchState, billId: string): boolean
	for _, bill in state.bills do
		if bill.id == billId then
			return true
		end
	end
	return false
end

local LockDraftsStep = setmetatable({}, { __index = Step })
LockDraftsStep.__index = LockDraftsStep

function LockDraftsStep.new(): LockDraftsStep
	return setmetatable({}, LockDraftsStep)
end

export type LockDraftsStep = typeof(setmetatable({} :: {}, LockDraftsStep))

function LockDraftsStep.run(_self: LockDraftsStep, state: MatchState, _ctx: Step.StepContext)
	local workingId: ClassId = "Working"

	for ci = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[ci] :: any
		local draft = state.drafts[classId]

		-- openSlots: only the owner of the line may set them, and only
		-- within the line's slots.
		local droppedSlots: { string } = {}
		for lineId, value in draft.openSlots do
			local line = state.lines[lineId]
			if line == nil then
				table.insert(droppedSlots, lineId)
				log(state, {
					day = state.day,
					text = `{classId} openSlots dropped: unknown line {lineId}`,
					actor = classId,
				})
			elseif line.owner ~= classId then
				table.insert(droppedSlots, lineId)
				log(state, {
					day = state.day,
					text = `{classId} openSlots dropped: {lineId} is not {classId}'s line`,
					actor = classId,
				})
			elseif not isWholeNumber(value) or value > (ConfigLines[line.type] :: any).slotsMax then
				table.insert(droppedSlots, lineId)
				log(state, {
					day = state.day,
					text = `{classId} openSlots dropped: {lineId} value {value} is out of range`,
					actor = classId,
				})
			end
		end
		for _, lineId in droppedSlots do
			local key: LineId = lineId :: any
			draft.openSlots[key] = nil
		end

		-- assign: Working's field alone.
		local droppedAssign: { string } = {}
		for lineId, value in draft.assign do
			if classId ~= workingId then
				table.insert(droppedAssign, lineId)
				log(state, {
					day = state.day,
					text = `{classId} assign dropped: only Working assigns workers`,
					actor = classId,
				})
			elseif state.lines[lineId] == nil then
				table.insert(droppedAssign, lineId)
				log(state, {
					day = state.day,
					text = `{classId} assign dropped: unknown line {lineId}`,
					actor = classId,
				})
			elseif not isWholeNumber(value) then
				table.insert(droppedAssign, lineId)
				log(state, {
					day = state.day,
					text = `{classId} assign dropped: {lineId} count {value} is not a whole number`,
					actor = classId,
				})
			end
		end
		for _, lineId in droppedAssign do
			local key: LineId = lineId :: any
			draft.assign[key] = nil
		end

		-- strike: Working's field alone, and never against itself.
		if draft.strike ~= nil then
			local target = draft.strike.target
			if classId ~= workingId then
				draft.strike = nil
				log(state, {
					day = state.day,
					text = `{classId} strike dropped: only Working strikes`,
					actor = classId,
				})
			elseif not CLASS_IDS[target] or target == workingId then
				draft.strike = nil
				log(state, {
					day = state.day,
					text = `{classId} strike dropped: {target} is not a valid target`,
					actor = classId,
				})
			end
		end

		-- build: the line type must exist (R4 checks what the class may do).
		if draft.build ~= nil then
			local lineType = draft.build.lineType
			if not LINE_TYPES[lineType] then
				draft.build = nil
				log(state, {
					day = state.day,
					text = `{classId} build dropped: unknown line type {lineType}`,
					actor = classId,
				})
			end
		end

		-- lobby: the amount must be a whole number of Influence (R2 converts it).
		if draft.lobby ~= nil then
			local amount = draft.lobby.amount
			if not isWholeNumber(amount) then
				draft.lobby = nil
				log(state, {
					day = state.day,
					text = `{classId} lobby dropped: {amount} is not a whole number`,
					actor = classId,
				})
			end
		end

		-- market: every entry must name a real resource and a whole volume.
		for _, side in { "sell", "buy" } do
			local bag = if side == "sell" then draft.market.sell else draft.market.buy
			local dropped: { string } = {}
			for stockId, volume in bag do
				if not STOCK_IDS[stockId] then
					table.insert(dropped, stockId)
					log(state, {
						day = state.day,
						text = `{classId} market {side} dropped: unknown resource {stockId}`,
						actor = classId,
					})
				elseif not isWholeNumber(volume) then
					table.insert(dropped, stockId)
					log(state, {
						day = state.day,
						text = `{classId} market {side} dropped: {stockId} volume {volume} is not a whole number`,
						actor = classId,
					})
				end
			end
			for _, stockId in dropped do
				local key: StockId = stockId :: any
				bag[key] = nil
			end
		end

		-- votes: only for bills that are on the table.
		local droppedVotes: { string } = {}
		for billId, vote in draft.votes do
			if not isKnownBill(state, billId) then
				table.insert(droppedVotes, billId)
				log(state, {
					day = state.day,
					text = `{classId} vote dropped: unknown bill {billId}`,
					actor = classId,
				})
			elseif not isWholeNumber(vote.influence) then
				table.insert(droppedVotes, billId)
				log(state, {
					day = state.day,
					text = `{classId} vote dropped: {billId} influence {vote.influence} is not a whole number`,
					actor = classId,
				})
			end
		end
		for _, billId in droppedVotes do
			local key: string = billId :: any
			draft.votes[key] = nil
		end
	end
end

return LockDraftsStep
