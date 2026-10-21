--!strict
-- R5 Production (GAME_DESIGN 6.1 to 6.5, section 10). One pass over the
-- Working class's assignments, then one pass over owners:
--   1. Assign (6.3): per line in natural order, staffed = min(draft assign,
--      openSlots, remaining worker pool); over-assignments are ignored, and
--      excess workers stay unemployed (D-047). Not-yet-built lines (T1)
--      accept no assignment.
--   2. Per owner line ( CLASS_ORDER, then natural order):
--      strike target's lines produce nothing and pay no wage (6.5); an idle
--      line (zero staffed slots) does nothing; otherwise affordable wages
--      pay first, ascending line id (6.4: unpaid slots produce nothing and
--      are counted in scratch for R9's Stability penalty).
--      Operating lines consume the Factory Education input from the owner
--      (6.1; missing input halves output, floored) and emit output to the
--      owner's stock. Wages received, unpaid slots, and employed workers go
--      to scratch (D-046) for Taxes/Upkeep/Scoring.
-- Every change lands in the event log with its cause; nothing throws.

local Types = require(script.Parent.Parent.Types)
local Step = require(script.Parent.Step)
local StateOps = require(script.Parent.Parent.State.StateOps)
local ConfigLines = require(script.Parent.Parent.Parent.Config.Lines)
local ConfigPolicies = require(script.Parent.Parent.Parent.Config.Policies)
local ConfigResources = require(script.Parent.Parent.Parent.Config.Resources)

type ClassId = Types.ClassId
type Line = Types.Line
type LineId = Types.LineId
type LineType = Types.LineType
type LogEntry = Types.LogEntry
type MatchState = Types.MatchState
type PolicyId = Types.PolicyId
type ResourceId = Types.ResourceId
type StockId = Types.StockId
type StepContext = Step.StepContext

-- Reverse of Config/Resources stockKey (D-008 keys live there, not here).
-- Reads go through `any` + annotation: luau-lsp 1.70.1 degrades map reads
-- against cross-module mirrors (see luau-conventions).
local STOCK_TO_RESOURCE: { [StockId]: ResourceId } = {}
for i = 1, #Types.RESOURCE_IDS do
	local resourceId: ResourceId = Types.RESOURCE_IDS[i] :: any
	local stockKey = (ConfigResources :: any)[resourceId].stockKey
	if stockKey ~= nil then
		STOCK_TO_RESOURCE[stockKey] = resourceId
	end
end

-- "Lines in ascending id order" (GAME_DESIGN 10) must stay true for
-- double-digit ids: "Farm-10" was built after "Farm-4" but sorts before it
-- lexically. Natural order = line type alphabetically, then the numeric
-- suffix, then the id as a tiebreak (ids are unique; D-047).
local function suffixNumber(line: Line): number
	local found = tonumber(string.match(line.id, "%-(%d+)$"))
	return if found == nil then math.huge else found
end

local function lineLess(a: Line, b: Line): boolean
	if a.type ~= b.type then
		return a.type < b.type
	end
	local na = suffixNumber(a)
	local nb = suffixNumber(b)
	if na ~= nb then
		return na < nb
	end
	return a.id < b.id
end

-- All lines in natural order (one sorted array for the assignment pass).
local function sortedLines(state: MatchState): { Line }
	local lines: { Line } = {}
	for _, line in state.lines do
		table.insert(lines, line)
	end
	table.sort(lines, lineLess)
	return lines
end

-- Each owner's lines in natural order (owner pass reads these directly).
local function linesOwnedBy(state: MatchState): { [ClassId]: { Line } }
	local groups: { [ClassId]: { Line } } = {}
	for ci = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[ci] :: any
		groups[classId] = {}
	end
	for _, line in state.lines do
		table.insert((groups :: any)[line.owner], line)
	end
	for ci = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[ci] :: any
		table.sort(groups[classId] :: { Line }, lineLess)
	end
	return groups
end

local function log(state: MatchState, entry: LogEntry)
	table.insert(state.eventLog, entry)
end

local ProductionStep = setmetatable({}, { __index = Step })
ProductionStep.__index = ProductionStep

function ProductionStep.new(): ProductionStep
	return setmetatable({}, ProductionStep)
end

export type ProductionStep = typeof(setmetatable({} :: {}, ProductionStep))

function ProductionStep.run(_self: ProductionStep, state: MatchState, ctx: StepContext)
	local scratch = ctx.scratch
	-- luau-lsp 1.70.1: literal keys on union-keyed maps are rejected ("Key
	-- 'Wage' not found"); read through annotated locals + dynamic keys.
	local wageId: PolicyId = "Wage"
	local wage = (ConfigPolicies.tracks[wageId].levelValues :: { [any]: any })[(
		state.policies :: any
	)[wageId]]
	local workingId: ClassId = "Working"

	-- Strike (6.5): Working's sticky strike spec; the target's lines idle this
	-- Day. The StrikeRights penalties (influence, stability) belong to R3 in
	-- M3-T4, not here.
	local strikeTarget: ClassId? = nil
	local strikeSpec = state.drafts[workingId].strike
	if strikeSpec ~= nil then
		strikeTarget = strikeSpec.target
	end

	-- Pass 1 - assignment (6.3): the Working class allocates its worker pool
	-- over all lines in natural order. Not-yet-built lines accept nothing.
	local remainingWorkers = state.classes[workingId].workers
	for _, line in sortedLines(state) do
		if line.builtOnDay >= state.day then
			line.assigned = 0 -- built today: active next Day (T1/R4)
			continue
		end
		local requested = state.drafts[workingId].assign[line.id] or 0
		local granted = math.min(requested, line.openSlots, remainingWorkers)
		line.assigned = granted
		remainingWorkers -= granted
	end

	-- Per-owner pass: pay wages, consume Factory input, emit output.
	local owned = linesOwnedBy(state)
	local unpaidTotal = 0
	local employedTotal = 0
	local wagesTotal = 0
	local strikeIdleLines = 0

	for ci = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[ci] :: any
		local anyStaffed = false
		local paidSlots = 0
		local paidMoney = 0
		local unpaidUnderOwner = 0

		for _, line in owned[classId] :: { Line } do
			local lineType: LineType = line.type
			local config = ConfigLines[lineType]
			local staffed = line.assigned

			if staffed <= 0 then
				continue
			end
			if strikeTarget ~= nil and classId == strikeTarget then
				-- 6.5: the line produces nothing and its workers go unpaid —
				-- but strike slots are not 6.4-unpaid (R9 counts only those)
				strikeIdleLines += 1
				continue
			end

			anyStaffed = true

			-- 6.4: pay as many slots as affordable, ascending line id order
			-- (this loop); every unpaid slot (whole or remainder) produces
			-- nothing and is counted against R9's Stability penalty.
			local affordable = math.min(
				staffed,
				math.floor(StateOps.resourceValue(state, classId, "Money") / wage)
			)

			if affordable > 0 then
				local cost = affordable * wage
				if StateOps.subtractResource(state, classId, "Money", cost) then
					StateOps.addResource(state, "Working", "Money", cost)
					paidSlots += affordable
					paidMoney += cost
					wagesTotal += cost
					employedTotal += affordable
				else
					affordable = 0 -- defensive only: floor() above is a guard
				end
			end

			local unpaid = staffed - affordable
			if unpaid > 0 then
				unpaidUnderOwner += unpaid
				unpaidTotal += unpaid
			end
			if affordable <= 0 then
				continue -- nothing paid, nothing produced
			end

			-- 6.1: Factory input from the owner's stock at this step; missing
			-- input halves the line's output (floored). Generic over the
			-- config's input map (v1: one Education for a Factory).
			local halved = false
			local inputs = config.input
			if inputs ~= nil then
				for si = 1, #Types.STOCK_IDS do
					local stockId: StockId = Types.STOCK_IDS[si] :: any
					local need = (inputs :: { [any]: any })[stockId]
					if need ~= nil and need > 0 then
						local resourceId: ResourceId = (STOCK_TO_RESOURCE :: any)[stockId]
						local have = StateOps.resourceValue(state, classId, resourceId)
						if have >= need then
							StateOps.subtractResource(state, classId, resourceId, need)
						else
							halved = true
						end
					end
				end
			end

			-- 6.1: output per staffed (and PAID) slot to the owner's stock.
			local outputs = config.output :: { [any]: any }
			local parts: { string } = {}
			for si = 1, #Types.STOCK_IDS do
				local stockId: StockId = Types.STOCK_IDS[si] :: any
				local perSlot = outputs[stockId]
				if perSlot ~= nil and perSlot > 0 then
					local resourceId: ResourceId = (STOCK_TO_RESOURCE :: any)[stockId]
					local perLine = perSlot * affordable
					if halved then
						perLine = perLine // 2
					end
					if perLine > 0 then
						StateOps.addResource(state, classId, resourceId, perLine)
						local name = (ConfigResources :: any)[resourceId].name
						table.insert(parts, `{perLine} {name}`)
					end
				end
			end
			if #parts > 0 then
				local note = if halved then " (no input: output halved)" else ""
				log(state, {
					day = state.day,
					text = `{classId} {line.id} produced {table.concat(parts, ", ")}{note}`,
					actor = classId,
				})
			end
		end

		if anyStaffed then
			if unpaidUnderOwner > 0 then
				log(state, {
					day = state.day,
					text = `{classId} paid {paidMoney} Money in wages for {paidSlots} slot(s); {unpaidUnderOwner} wage slot(s) left unpaid`,
					actor = classId,
				})
			elseif paidSlots > 0 then
				log(state, {
					day = state.day,
					text = `{classId} paid {paidMoney} Money in wages for {paidSlots} slot(s)`,
					actor = classId,
				})
			end
		end
	end

	if wagesTotal > 0 then
		log(state, {
			day = state.day,
			text = `Working received {wagesTotal} Money in wages (Wage level {(
				state.policies :: any
			).Wage})`,
			actor = "Working",
		})
	end

	if strikeTarget ~= nil and strikeIdleLines > 0 then
		log(state, {
			day = state.day,
			text = `Working's strike idles {strikeTarget}: {strikeIdleLines} staffed line(s) produce nothing today`,
			actor = "Working",
		})
	end

	scratch.wagesReceived[workingId] = wagesTotal
	scratch.unpaidSlots = unpaidTotal
	scratch.employedWorkers = employedTotal
end

return ProductionStep
