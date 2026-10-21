--!strict
-- R4 Build (GAME_DESIGN 6.2 and section 10): pay for and queue at most one
-- new line per class this Day. The queued line carries builtOnDay = today,
-- which makes it absent from today's Production and operating from the next
-- Day ("becomes active the Day after being built"), per GAME_DESIGN section 4.
-- Build permissions come from Config/Classes.canBuild (6.2: State builds
-- Clinics/Schools only, Middle Farm/Clinic/School, Capitalist Farm/Factory,
-- Working nothing) — the step never hard-codes them. Unaffordable or
-- forbidden builds are skipped with a log entry (section 10).

local Types = require(script.Parent.Parent.Types)
local Step = require(script.Parent.Step)
local StateOps = require(script.Parent.Parent.State.StateOps)
local ConfigClasses = require(script.Parent.Parent.Parent.Config.Classes)
local ConfigLines = require(script.Parent.Parent.Parent.Config.Lines)

type ClassId = Types.ClassId
type Line = Types.Line
type LineId = Types.LineId
type LineType = Types.LineType
type MatchState = Types.MatchState
type StepContext = Step.StepContext
type ClassEntry = ConfigClasses.ClassEntry

-- Largest "N" over this line type's existing "<LineType>-N" ids, or 0 when
-- none exist. Parsed numerically ("Farm-10" > "Farm-4") and order-independent
-- (a max), so `pairs` order can never affect the minted id (D-040 keeps the
-- per-type counter running).
local function lastNumberOfType(lines: { [LineId]: Line }, lineType: LineType): number
	local best = 0
	for _, line in lines do
		if line.type == lineType then
			local found = tonumber(string.match(line.id, "%-(%d+)$"))
			if found ~= nil and found > best then
				best = found
			end
		end
	end
	return best
end

local function mayBuild(entry: ClassEntry, lineType: LineType): boolean
	for _, permitted in entry.canBuild do
		if permitted == lineType then
			return true
		end
	end
	return false
end

-- One class's build attempt this Day. A plain local (not class API); each
-- rejection keeps a single return (skip-and-log, never throw — section 10).
local function attempt(state: MatchState, classId: ClassId, lineType: LineType)
	local entry = ConfigClasses.entries[classId] :: ClassEntry
	local day = state.day

	if not mayBuild(entry, lineType) then
		table.insert(state.eventLog, {
			day = day,
			text = `{classId} build skipped: {classId} cannot build {lineType}`,
			actor = classId,
		})
		return
	end

	local cost = ConfigLines[lineType].buildCost

	if not StateOps.subtractResource(state, classId, "Money", cost) then
		table.insert(state.eventLog, {
			day = day,
			text = `{classId} build skipped: cannot afford {lineType} ({cost} Money)`,
			actor = classId,
		})
		return
	end

	-- A new line is ready to operate the moment it activates: without open
	-- slots it could never be staffed, and 6.2 promises "operating the next
	-- Day". Owners tune openSlots down later (sticky); same default as the
	-- initial lines (5.2).
	local lineId: LineId = `{lineType}-{lastNumberOfType(state.lines, lineType) + 1}`
	local line: Line = {
		id = lineId,
		type = lineType,
		owner = classId,
		openSlots = ConfigLines[lineType].slotsMax,
		builtOnDay = day, -- today's Production must not see it; tomorrow's may
		assigned = 0,
	}
	StateOps.addLine(state, line)

	table.insert(state.eventLog, {
		day = day,
		text = `{classId} built {lineId} for {cost} Money`,
		actor = classId,
	})
end

local BuildStep = setmetatable({}, { __index = Step })
BuildStep.__index = BuildStep

function BuildStep.new(): BuildStep
	return setmetatable({}, BuildStep)
end

export type BuildStep = typeof(setmetatable({} :: {}, BuildStep))

function BuildStep.run(_self: BuildStep, state: MatchState, _ctx: StepContext)
	for ci = 1, #Types.CLASS_IDS do
		-- luau-lsp 1.70.1: loop variables read from the mirror degrade to
		-- `string`; re-narrow with the annotation+any idiom
		local classId: ClassId = Types.CLASS_IDS[ci] :: any
		local draft = state.drafts[classId]
		if draft.build ~= nil then
			attempt(state, classId, draft.build.lineType)
		end
	end
end

return BuildStep
