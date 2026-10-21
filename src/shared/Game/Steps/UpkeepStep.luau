--!strict
-- R9 Upkeep (GAME_DESIGN 6.9, section 10): every class consumes its daily
-- needs (§5.3) from its stock; what it could not cover is unmet. The
-- Stability change for the Day is
--   -1 per unmet unit (all classes combined), capped at -10,
--   +2 when nothing is unmet at all,
--   -1 per unpaid wage slot (R5, 6.4) and -1 per outlawed strike (6.5),
-- clamped to 0..100. When Stability ends the Day at 0 the collapse counter
-- advances, otherwise it resets to 0.
--
-- The rest of the outlawed strike's penalty (Working loses 2 Influence, the
-- State gains 1, 6.5) is applied here too, so the whole penalty lands in
-- one step and is never charged twice (D-059).
--
-- The needs come from Game/Needs.luau, the same numbers R8 distributed
-- against, so the State's free stock counts as covered here (D-051).

local Types = require(script.Parent.Parent.Types)
local Step = require(script.Parent.Step)
local StateOps = require(script.Parent.Parent.State.StateOps)
local Needs = require(script.Parent.Parent.Needs)
local StockMap = require(script.Parent.Parent.StockMap)
local ConfigClasses = require(script.Parent.Parent.Parent.Config.Classes)
local ConfigPolicies = require(script.Parent.Parent.Parent.Config.Policies)
local ConfigResources = require(script.Parent.Parent.Parent.Config.Resources)

type ClassId = Types.ClassId
type LogEntry = Types.LogEntry
type MatchState = Types.MatchState
type PolicyId = Types.PolicyId
type ResourceId = Types.ResourceId
type StockId = Types.StockId
type StepContext = Step.StepContext

-- The Stability cost of unmet needs is capped (§6.9).
local UNMET_CAP = 10

local function log(state: MatchState, entry: LogEntry)
	table.insert(state.eventLog, entry)
end

local function resourceName(resourceId: ResourceId): string
	return (ConfigResources :: any)[resourceId].name
end

-- The number of outlawed strikes this Day: Working's strike while the
-- StrikeRights policy is Outlawed (level 0, 6.5). Only the Stability term
-- of the penalty is applied here; the Influence half (Working -2, State +1)
-- belongs to M3-T4's StrikeRights consequences (D-052).
local function outlawedStrikes(state: MatchState): number
	local strikeRightsId: PolicyId = "StrikeRights"
	local level = (state.policies :: any)[strikeRightsId]
	if level ~= 0 then
		return 0 -- Allowed, or no such policy in this match
	end
	local workingId: ClassId = "Working"
	if state.drafts[workingId].strike == nil then
		return 0
	end
	return 1
end

local UpkeepStep = setmetatable({}, { __index = Step })
UpkeepStep.__index = UpkeepStep

function UpkeepStep.new(): UpkeepStep
	return setmetatable({}, UpkeepStep)
end

export type UpkeepStep = typeof(setmetatable({} :: {}, UpkeepStep))

function UpkeepStep.run(_self: UpkeepStep, state: MatchState, ctx: StepContext)
	local scratch = ctx.scratch
	local totalUnmet = 0

	-- Consume the needs class by class (CLASS_ORDER) and resource by
	-- resource (STOCK_IDS order), so a short stock always leaves the same
	-- resources unmet.
	for ci = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[ci] :: any
		local required = Needs.required(state, classId, ctx.ruleSet)
		local unmetParts: { string } = {}
		local unmetCount = 0

		for si = 1, #Types.STOCK_IDS do
			local stockId: StockId = Types.STOCK_IDS[si] :: any
			local need = required[stockId] or 0
			if need > 0 then
				local resourceId: ResourceId = (StockMap :: any)[stockId]
				local have = StateOps.resourceValue(state, classId, resourceId)
				local take = math.min(need, have)
				if take > 0 then
					StateOps.subtractResource(state, classId, resourceId, take)
				end
				local unmet = need - take
				if unmet > 0 then
					unmetCount += unmet
					table.insert(unmetParts, `{unmet} {resourceName(resourceId)}`)
				end
			end
		end

		if #unmetParts > 0 then
			totalUnmet += unmetCount
			log(state, {
				day = state.day,
				text = `{classId} could not cover {table.concat(unmetParts, " and ")}`,
				actor = classId,
			})
		end
	end

	-- Stability change.
	local delta = -math.min(totalUnmet, UNMET_CAP)
	local parts: { string } = {}
	if totalUnmet > 0 then
		table.insert(parts, `{totalUnmet} unmet need unit(s)`)
	else
		delta += 2
		table.insert(parts, "all needs met")
	end

	local unpaid = scratch.unpaidSlots
	if unpaid > 0 then
		-- 6.4: each unpaid slot costs Stability `unpaidWagePenalty` (config)
		delta -= unpaid * ConfigPolicies.unpaidWagePenalty
		table.insert(parts, `{unpaid} unpaid wage slot(s)`)
	end

	local strikes = outlawedStrikes(state)
	if strikes > 0 then
		delta -= strikes
		table.insert(parts, `{strikes} outlawed strike(s)`)

		-- 6.5: the rest of the outlawed strike's penalty — Working loses
		-- Influence (not below 0), the State gains some (never past the
		-- Influence cap). The whole penalty lives here, next to its
		-- Stability term, so it is never charged twice (D-059).
		local workingId: ClassId = "Working"
		local lost = math.min(
			ConfigPolicies.strikeRights.workingInfluenceLoss,
			state.classes[workingId].influence
		)
		if lost > 0 then
			StateOps.subtractResource(state, workingId, "Influence", lost)
			log(state, {
				day = state.day,
				text = `{workingId} lost {lost} Influence to the outlawed strike`,
				actor = workingId,
			})
		end

		local stateId: ClassId = "State"
		local gained = math.min(
			ConfigPolicies.strikeRights.stateInfluenceGain,
			ConfigClasses.influenceCap - state.classes[stateId].influence
		)
		if gained > 0 then
			StateOps.addResource(state, stateId, "Influence", gained)
			log(state, {
				day = state.day,
				text = `{stateId} gained {gained} Influence from the outlawed strike`,
				actor = stateId,
			})
		end
	end

	local before = state.stability
	local after = math.clamp(before + delta, 0, 100)
	state.stability = after

	local change = after - before
	local sign = if change > 0 then "+" else ""
	log(state, {
		day = state.day,
		text = `Stability {sign}{change} ({table.concat(parts, ", ")})`,
	})

	-- Collapse counter: consecutive Days at stability 0.
	if after == 0 then
		state.collapseCounter += 1
		log(state, {
			day = state.day,
			text = `Stability hit 0 — collapse counter {state.collapseCounter}`,
		})
	else
		state.collapseCounter = 0
	end
end

return UpkeepStep
