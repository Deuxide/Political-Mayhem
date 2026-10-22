--!strict
-- The validation toolkit of NETWORKING section 7. Every server handler runs
-- these before it touches the state (NETWORKING 1.2: authenticate ->
-- shape-validate -> state-validate -> apply -> acknowledge).
--
-- Reject, never coerce: NaN, infinity, negative numbers, non-integers where
-- integers are required, unknown keys and oversized tables are refused. The
-- one exception is `clampDraft`, which exists to turn an untrusted draft into
-- a safe one without mutating what the client sent.

local Types = require(script.Parent.Parent.Game.Types)
local ConfigNetwork = require(script.Parent.Parent.Config.Network)
local ConfigClasses = require(script.Parent.Parent.Config.Classes)
local ConfigLines = require(script.Parent.Parent.Config.Lines)
local ConfigMarket = require(script.Parent.Parent.Config.Market)

type ActionDraft = Types.ActionDraft
type BillId = Types.BillId
type ClassId = Types.ClassId
type LineId = Types.LineId
type LineType = Types.LineType
type MatchState = Types.MatchState
type StockId = Types.StockId
type VoteSide = Types.VoteSide

-- The Working owns the worker pool, so its assignment cap is the pool size.
local workingId: ClassId = "Working"

local Validate = {}

-- Membership sets over the frozen mirrors, built once.
local CLASS_IDS: { [string]: boolean } = {}
for i = 1, #Types.CLASS_IDS do
	CLASS_IDS[Types.CLASS_IDS[i]] = true
end

local ROLES: { [string]: boolean } = {}
for i = 1, #Types.ROLES do
	ROLES[Types.ROLES[i]] = true
end

local POLICY_IDS: { [string]: boolean } = {}
for i = 1, #Types.POLICY_IDS do
	POLICY_IDS[Types.POLICY_IDS[i]] = true
end

local DIFFICULTIES: { [string]: boolean } = {}
for i = 1, #Types.DIFFICULTIES do
	DIFFICULTIES[Types.DIFFICULTIES[i]] = true
end

local RESOURCE_IDS: { [string]: boolean } = {}
for i = 1, #Types.RESOURCE_IDS do
	RESOURCE_IDS[Types.RESOURCE_IDS[i]] = true
end

local STOCK_IDS: { [string]: boolean } = {}
for i = 1, #Types.STOCK_IDS do
	STOCK_IDS[Types.STOCK_IDS[i]] = true
end

local LINE_TYPES: { [string]: boolean } = {}
for i = 1, #Types.LINE_TYPES do
	LINE_TYPES[Types.LINE_TYPES[i]] = true
end

-- A payload table with at most `maxEntries` entries and at most `maxDepth`
-- levels of nesting (NETWORKING 7). Only plain values may travel: strings,
-- numbers, booleans, and nested tables of the same.
function Validate.isBoundedTable(value: any, maxEntries: number, maxDepth: number): boolean
	if type(value) ~= "table" then
		return false
	end
	local entries = 0

	local function walk(node: any, depth: number): boolean
		if depth > maxDepth then
			return false
		end
		for key, child in node do
			entries += 1
			if entries > maxEntries then
				return false
			end
			if type(key) ~= "string" and type(key) ~= "number" then
				return false
			end
			if type(child) == "table" then
				if not walk(child, depth + 1) then
					return false
				end
			elseif
				type(child) ~= "string"
				and type(child) ~= "number"
				and type(child) ~= "boolean"
			then
				return false
			end
		end
		return true
	end

	return walk(value, 1)
end

function Validate.isClassId(value: any): boolean
	return type(value) == "string" and CLASS_IDS[value] == true
end

function Validate.isRole(value: any): boolean
	return type(value) == "string" and ROLES[value] == true
end

function Validate.isPolicyId(value: any): boolean
	return type(value) == "string" and POLICY_IDS[value] == true
end

function Validate.isDifficulty(value: any): boolean
	return type(value) == "string" and DIFFICULTIES[value] == true
end

function Validate.isResourceId(value: any): boolean
	return type(value) == "string" and RESOURCE_IDS[value] == true
end

-- A line that exists in this match (ids are per match, so the state decides).
function Validate.isLineId(state: MatchState, id: any): boolean
	return type(id) == "string" and state.lines[id] ~= nil
end

-- A whole number in [0, max]. NaN and infinity are not numbers we accept.
function Validate.isNonNegInt(value: any, max: number): boolean
	if type(value) ~= "number" then
		return false
	end
	if value ~= value then
		return false -- NaN
	end
	if value == math.huge or value == -math.huge then
		return false
	end
	if value < 0 then
		return false
	end
	if value % 1 ~= 0 then
		return false
	end
	return value <= max
end

-- A resource bag: only real resource keys, only whole non-negative amounts.
function Validate.isResourceBag(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	local entries = 0
	for key, amount in value do
		entries += 1
		if entries > ConfigNetwork.maxTableEntries then
			return false
		end
		if not RESOURCE_IDS[key] then
			return false
		end
		if not Validate.isNonNegInt(amount, ConfigNetwork.maxResourceAmount) then
			return false
		end
	end
	return true
end

function Validate.isShortString(value: any, max: number): boolean
	return type(value) == "string" and #value <= max
end

-- The draft's shape: exactly the whitelisted keys, each with the right value
-- type (NETWORKING 7: unknown keys are rejected, not ignored).
function Validate.isDraftShape(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	if
		not Validate.isBoundedTable(
			value,
			ConfigNetwork.maxTableEntries,
			ConfigNetwork.maxTableDepth
		)
	then
		return false
	end
	for key in value do
		if
			key ~= "sequence"
			and key ~= "openSlots"
			and key ~= "assign"
			and key ~= "strike"
			and key ~= "build"
			and key ~= "lobby"
			and key ~= "market"
			and key ~= "votes"
		then
			return false
		end
	end

	if not Validate.isNonNegInt(value.sequence, ConfigNetwork.maxSequence) then
		return false
	end

	for _, map in { value.openSlots, value.assign } do
		if type(map) ~= "table" then
			return false
		end
		for lineId, count in map do
			if type(lineId) ~= "string" then
				return false
			end
			if not Validate.isNonNegInt(count, ConfigNetwork.maxSlotCount) then
				return false
			end
		end
	end

	local strike = value.strike
	if strike ~= nil then
		if type(strike) ~= "table" then
			return false
		end
		if not Validate.isClassId(strike.target) then
			return false
		end
	end

	local build = value.build
	if build ~= nil then
		if type(build) ~= "table" then
			return false
		end
		if not LINE_TYPES[build.lineType] then
			return false
		end
	end

	local lobby = value.lobby
	if lobby ~= nil then
		if type(lobby) ~= "table" then
			return false
		end
		if not Validate.isNonNegInt(lobby.amount, ConfigNetwork.maxResourceAmount) then
			return false
		end
	end

	local market = value.market
	if type(market) ~= "table" then
		return false
	end
	for _, bag in { market.sell, market.buy } do
		if type(bag) ~= "table" then
			return false
		end
		for stockId, volume in bag do
			if not STOCK_IDS[stockId] then
				return false
			end
			if not Validate.isNonNegInt(volume, ConfigNetwork.maxResourceAmount) then
				return false
			end
		end
	end

	local votes = value.votes
	if type(votes) ~= "table" then
		return false
	end
	for billId, vote in votes do
		if type(billId) ~= "string" then
			return false
		end
		if type(vote) ~= "table" then
			return false
		end
		if vote.side ~= "yes" and vote.side ~= "no" then
			return false
		end
		if not Validate.isNonNegInt(vote.influence, ConfigNetwork.maxResourceAmount) then
			return false
		end
	end

	return true
end

-- Turns an untrusted draft into a safe one: unknown lines, unknown ids, and
-- out-of-range values are dropped or clamped, and the input is never
-- mutated (NETWORKING 7).
function Validate.clampDraft(draft: any, state: MatchState): ActionDraft
	local safe: ActionDraft = {
		sequence = 0,
		locked = false,
		openSlots = {},
		assign = {},
		strike = nil,
		build = nil,
		lobby = nil,
		market = { sell = {}, buy = {} },
		votes = {},
	}
	if type(draft) ~= "table" then
		return safe
	end

	if Validate.isNonNegInt(draft.sequence, ConfigNetwork.maxSequence) then
		safe.sequence = draft.sequence
	end

	local openSlots = draft.openSlots
	if type(openSlots) == "table" then
		for lineId, count in openSlots do
			if
				type(lineId) == "string" and Validate.isNonNegInt(count, ConfigNetwork.maxSlotCount)
			then
				local line = state.lines[lineId]
				if line ~= nil then
					local max = (ConfigLines[line.type] :: any).slotsMax
					safe.openSlots[lineId :: any] = math.min(count, max)
				end
			end
		end
	end

	local assign = draft.assign
	if type(assign) == "table" then
		for lineId, count in assign do
			if
				type(lineId) == "string" and Validate.isNonNegInt(count, ConfigNetwork.maxSlotCount)
			then
				if state.lines[lineId] ~= nil then
					safe.assign[lineId :: any] = math.min(count, state.classes[workingId].workers)
				end
			end
		end
	end

	local strike = draft.strike
	if type(strike) == "table" and Validate.isClassId(strike.target) then
		safe.strike = { target = strike.target :: any }
	end

	local build = draft.build
	if type(build) == "table" and LINE_TYPES[build.lineType] then
		safe.build = { lineType = build.lineType :: any }
	end

	local lobby = draft.lobby
	if
		type(lobby) == "table"
		and Validate.isNonNegInt(lobby.amount, ConfigNetwork.maxResourceAmount)
	then
		safe.lobby = { amount = lobby.amount }
	end

	local market = draft.market
	if type(market) == "table" then
		local sell = market.sell
		if type(sell) == "table" then
			for stockId, volume in sell do
				if
					STOCK_IDS[stockId]
					and Validate.isNonNegInt(volume, ConfigNetwork.maxResourceAmount)
				then
					safe.market.sell[stockId :: any] = math.min(volume, ConfigMarket.volumeCap)
				end
			end
		end
		local buy = market.buy
		if type(buy) == "table" then
			for stockId, volume in buy do
				if
					STOCK_IDS[stockId]
					and Validate.isNonNegInt(volume, ConfigNetwork.maxResourceAmount)
				then
					safe.market.buy[stockId :: any] = math.min(volume, ConfigMarket.volumeCap)
				end
			end
		end
	end

	local votes = draft.votes
	if type(votes) == "table" then
		for billId, vote in votes do
			if type(billId) == "string" and type(vote) == "table" then
				local known = false
				for _, bill in state.bills do
					if bill.id == billId then
						known = true
						break
					end
				end
				if
					known
					and (vote.side == "yes" or vote.side == "no")
					and Validate.isNonNegInt(vote.influence, ConfigNetwork.maxResourceAmount)
				then
					safe.votes[billId :: any] = {
						side = (vote.side :: any) :: VoteSide,
						influence = math.min(vote.influence, ConfigClasses.influenceCap),
					}
				end
			end
		end
	end

	return safe
end

return Validate
