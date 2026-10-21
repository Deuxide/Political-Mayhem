--!strict
-- R8 PublicServices (GAME_DESIGN 6.8, section 10). In Universal mode the
-- State's Health and Education stock is distributed free to the classes'
-- unmet needs, in priority order Working, Middle, Capitalist, until the
-- State's stock or the needs run out; the State's stock is reduced
-- accordingly. In Market mode (the default) the step does nothing — the
-- State's own output is its stock to sell, trade, or hold.
--
-- "Unmet" means the part of a class's daily needs (§5.3, scaled by the
-- difficulty — the same numbers R9 consumes) its own stock does not cover.
-- Only Health and Education are distributed; the State's Food and Goods
-- stay with the State.
local Types = require(script.Parent.Parent.Types)
local Step = require(script.Parent.Step)
local StateOps = require(script.Parent.Parent.State.StateOps)
local Needs = require(script.Parent.Parent.Needs)
local StockMap = require(script.Parent.Parent.StockMap)
local ConfigResources = require(script.Parent.Parent.Parent.Config.Resources)

type ClassId = Types.ClassId
type LogEntry = Types.LogEntry
type MatchState = Types.MatchState
type PolicyId = Types.PolicyId
type ResourceId = Types.ResourceId
type StockId = Types.StockId
type StepContext = Step.StepContext

local function log(state: MatchState, entry: LogEntry)
	table.insert(state.eventLog, entry)
end

local function resourceName(resourceId: ResourceId): string
	return (ConfigResources :: any)[resourceId].name
end

-- The stock resources the State distributes (§6.8: Health and Education).
local DISTRIBUTED: { StockId } = { "health", "education" }

local PublicServicesStep = setmetatable({}, { __index = Step })
PublicServicesStep.__index = PublicServicesStep

function PublicServicesStep.new(): PublicServicesStep
	return setmetatable({}, PublicServicesStep)
end

export type PublicServicesStep = typeof(setmetatable({} :: {}, PublicServicesStep))

function PublicServicesStep.run(_self: PublicServicesStep, state: MatchState, ctx: StepContext)
	local publicId: PolicyId = "PublicServices"
	local level: number = (state.policies :: any)[publicId]
	if level == nil or level == 0 then
		return -- Market mode: the State's output is its own stock
	end

	local stateId: ClassId = "State"

	for ci = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[ci] :: any
		if classId ~= stateId then
			local required = Needs.required(state, classId, ctx.ruleSet)
			local given: { string } = {}

			for di = 1, #DISTRIBUTED do
				-- index loop + annotation: `for-in` keys degrade to `string`
				-- in luau-lsp 1.70.1 (see luau-conventions)
				local stockId: StockId = DISTRIBUTED[di] :: any
				local need = required[stockId] or 0
				if need > 0 then
					local resourceId: ResourceId = (StockMap :: any)[stockId]
					local own = StateOps.resourceValue(state, classId, resourceId)
					local unmet = need - own
					if unmet > 0 then
						local pool = StateOps.resourceValue(state, stateId, resourceId)
						local give = math.min(unmet, pool)
						if
							give > 0 and StateOps.subtractResource(state, stateId, resourceId, give)
						then
							StateOps.addResource(state, classId, resourceId, give)
							table.insert(given, `{give} {resourceName(resourceId)}`)
						end
					end
				end
			end

			if #given > 0 then
				log(state, {
					day = state.day,
					text = `State gave {classId} {table.concat(given, " and ")} (free public services)`,
					actor = stateId,
				})
			end
		end
	end
end

return PublicServicesStep
