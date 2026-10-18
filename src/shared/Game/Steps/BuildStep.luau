--!strict
-- R4: Build step - Pay and queue new lines (active next Day).
-- Processes class build decisions from drafts.

local Types = require(script.Parent.Parent.Types)
local Step = require(script.Parent.Step)
local StateOps = require(script.Parent.Parent.State.StateOps)

local BuildStep = setmetatable({}, { __index = Step })
BuildStep.__index = BuildStep

-- Build costs per line type (from Config/Lines.luau)
local BUILD_COSTS: { [Types.LineType]: { [Types.ResourceId]: number } } = {
	Farm = { Money = 12 },
	Factory = { Money = 20 },
	Clinic = { Money = 15 },
	School = { Money = 15 },
}

-- Eligible line types per class (from Config/Lines.luau)
local ELIGIBLE_BY_CLASS: { [Types.ClassId]: { Types.LineType } } = {
	Working = {}, -- Working doesn't build lines directly
	Middle = { "Farm", "Clinic", "School" },
	Capitalist = { "Farm", "Factory" },
	State = { "Clinic", "School" },
}

-- Max lines per class (from Config/Classes.luau)
local MAX_LINES = 5

function BuildStep.new() return setmetatable(Step.new("Build"), BuildStep) end

-- Helper: check if class can afford build cost
local function canAfford(
	stateOps: any,
	classState: Types.ClassState,
	cost: { [Types.ResourceId]: number }
): boolean
	for resource, amount in pairs(cost) do
		if stateOps:getResource(classState, resource) < amount then return false end
	end
	return true
end

-- Helper: pay build cost
local function payCost(
	stateOps: any,
	classState: Types.ClassState,
	cost: { [Types.ResourceId]: number }
): boolean
	for resource, amount in pairs(cost) do
		if not stateOps:subtractResource(classState, resource, amount) then return false end
	end
	return true
end

-- Helper: generate unique line ID
local function generateLineId(
	classId: Types.ClassId,
	lineType: Types.LineType,
	day: number
): string
	return string.format("%s_%s_%d", classId, lineType, day)
end

function BuildStep:run(state: Types.MatchState, ctx: any)
	local stateOps = ctx.stateOps
	local ruleSet = ctx.ruleSet
	local round = state.round

	-- Process classes in fixed order: Working, Middle, Capitalist, State
	for _, classId in ipairs(StateOps.CLASS_ORDER) do
		local classState = state.classes[classId]
		local draft = state.drafts[classId]

		if not draft or not draft.build then continue end

		local lineType = draft.build
		local eligible = ELIGIBLE_BY_CLASS[classId]

		-- Check if class can build this line type
		local allowed = false
		for _, allowedType in ipairs(eligible) do
			if allowedType == lineType then
				allowed = true
				break
			end
		end

		if not allowed then
			table.insert(ctx.trace, {
				round = round,
				step = "Build",
				class = classId,
				message = string.format("Cannot build %s: not allowed for class", lineType),
				data = { lineType = lineType },
			})
			continue
		end

		-- Check max lines
		local lineCount = 0
		for _, line in pairs(state.lines) do
			if line.owner == classId then
				lineCount += 1
			end
		end

		if lineCount >= MAX_LINES then
			table.insert(ctx.trace, {
				round = round,
				step = "Build",
				class = classId,
				message = string.format(
					"Cannot build %s: max lines (%d) reached",
					lineType,
					MAX_LINES
				),
				data = { lineType = lineType, lineCount = lineCount },
			})
			continue
		end

		-- Check affordability
		local cost = BUILD_COSTS[lineType]
		if not cost then
			table.insert(ctx.trace, {
				round = round,
				step = "Build",
				class = classId,
				message = string.format("Unknown line type: %s", lineType),
				data = { lineType = lineType },
			})
			continue
		end

		if not canAfford(stateOps, classState, cost) then
			table.insert(ctx.trace, {
				round = round,
				step = "Build",
				class = classId,
				message = string.format("Cannot afford %s: cost %d Money", lineType, cost.Money),
				data = { lineType = lineType, cost = cost, money = classState.resources.Money },
			})
			continue
		end

		-- Pay cost and create line
		if payCost(stateOps, classState, cost) then
			local lineId = generateLineId(classId, lineType, round)
			local newLine: Types.Line = {
				id = lineId,
				type = lineType,
				owner = classId,
				openSlots = 0,
				builtOnDay = round + 1, -- becomes active next Day
				assigned = 0,
			}
			state.lines[lineId] = newLine

			table.insert(ctx.trace, {
				round = round,
				step = "Build",
				class = classId,
				message = string.format("Queued %s (active Day %d)", lineType, round + 1),
				data = { lineId = lineId, lineType = lineType, activeDay = round + 1 },
			})
		else
			table.insert(ctx.trace, {
				round = round,
				step = "Build",
				class = classId,
				message = string.format("Failed to pay for %s", lineType),
				data = { lineType = lineType },
			})
		end
	end
end

return BuildStep
