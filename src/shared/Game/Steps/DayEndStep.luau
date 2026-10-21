--!strict
-- R14 Events (GAME_DESIGN section 10) — the end-of-Day step. Its Events
-- half is V2 and does nothing yet; the step does the two things every Day
-- needs: it rolls the drafts forward and advances the Day counter.
--
-- Draft roll-forward (section 9): the sticky fields (openSlots, assign,
-- strike) carry into the next Day's draft, the per-Day fields (build,
-- lobby, market, votes) clear — market orders in particular must not repeat
-- by accident (6.6).

local Types = require(script.Parent.Parent.Types)
local Step = require(script.Parent.Step)

type ClassId = Types.ClassId
type LogEntry = Types.LogEntry
type MatchState = Types.MatchState
type StepContext = Step.StepContext

local function log(state: MatchState, entry: LogEntry)
	table.insert(state.eventLog, entry)
end

local DayEndStep = setmetatable({}, { __index = Step })
DayEndStep.__index = DayEndStep

function DayEndStep.new(): DayEndStep
	return setmetatable({}, DayEndStep)
end

export type DayEndStep = typeof(setmetatable({} :: {}, DayEndStep))

function DayEndStep.run(_self: DayEndStep, state: MatchState, _ctx: StepContext)
	log(state, {
		day = state.day,
		text = `Day {state.day} closed`,
	})

	for ci = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[ci] :: any
		local draft = state.drafts[classId]
		draft.build = nil
		draft.lobby = nil
		draft.market = { sell = {}, buy = {} }
		draft.votes = {}
	end

	state.day += 1
end

return DayEndStep
