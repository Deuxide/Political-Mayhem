--!strict
-- R10 Influence (GAME_DESIGN 7.1, section 10): every class gains its
-- per-Day Influence income (Config/Classes.influenceIncome), and no class
-- may hold more than the shared Influence cap. The income lands after the
-- Bills step, so the Influence a class committed to a vote is already
-- spent when the income arrives.

local Types = require(script.Parent.Parent.Types)
local Step = require(script.Parent.Step)
local StateOps = require(script.Parent.Parent.State.StateOps)
local ConfigClasses = require(script.Parent.Parent.Parent.Config.Classes)

type ClassId = Types.ClassId
type LogEntry = Types.LogEntry
type MatchState = Types.MatchState
type StepContext = Step.StepContext

local function log(state: MatchState, entry: LogEntry)
	table.insert(state.eventLog, entry)
end

local InfluenceStep = setmetatable({}, { __index = Step })
InfluenceStep.__index = InfluenceStep

function InfluenceStep.new(): InfluenceStep
	return setmetatable({}, InfluenceStep)
end

export type InfluenceStep = typeof(setmetatable({} :: {}, InfluenceStep))

function InfluenceStep.run(_self: InfluenceStep, state: MatchState, _ctx: StepContext)
	for ci = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[ci] :: any
		local entry = ConfigClasses.entries[classId] :: ConfigClasses.ClassEntry
		local current = state.classes[classId].influence
		local after = math.min(ConfigClasses.influenceCap, current + entry.influenceIncome)
		if after > current then
			StateOps.addResource(state, classId, "Influence", after - current)
			log(state, {
				day = state.day,
				text = `{classId} gained {after - current} Influence`,
				actor = classId,
			})
		end
	end
end

return InfluenceStep
