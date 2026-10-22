--!strict
-- R13 VictoryCheck (GAME_DESIGN 11.2): decides whether this Closing Bell
-- ends the match, and with whom. ARCHITECTURE section 8's `Victory.check`,
-- run as a step so the result is committed with the Day that produced it.
--
-- Precedence follows the order section 11.2 lists: solo, shared, final Day,
-- collapse (D-070). Remaining ties fall to the earlier class in CLASS_IDS
-- order; an alliance compares by its earliest member, so the winner never
-- depends on table iteration order.
--
-- The result is written to `state.victory` (a section 4 extension, D-070) so
-- it survives serialization, feeds the views, and cannot be recomputed into a
-- different answer later. A match that already ended is left alone.
local Types = require(script.Parent.Parent.Types)
local Step = require(script.Parent.Step)
local RuleSet = require(script.Parent.Parent.RuleSet)
local Alliances = require(script.Parent.Parent.Ops.Alliances)
local ConfigScoring = require(script.Parent.Parent.Parent.Config.Scoring)

type ClassId = Types.ClassId
type LogEntry = Types.LogEntry
type MatchState = Types.MatchState
type RuleSetType = RuleSet.RuleSet
type StepContext = Step.StepContext
type VictoryResult = Types.VictoryResult

-- One side of the final-Day comparison: a class alone or an alliance.
-- `order` is the earliest member's position in CLASS_IDS (the last
-- tie-break); `value` is the comparable score (VP, or floor(combined x 0.7)).
type Contender = {
	ids: { ClassId },
	value: number,
	money: number,
	order: number,
}

local CLASS_IDS = Types.CLASS_IDS

local function log(state: MatchState, entry: LogEntry)
	table.insert(state.eventLog, entry)
end

local function countVp(state: MatchState, ids: { ClassId }): number
	local total = 0
	for ci = 1, #ids do
		local classId: ClassId = ids[ci]
		total += state.classes[classId].vp
	end
	return total
end

local function countMoney(state: MatchState, ids: { ClassId }): number
	local total = 0
	for ci = 1, #ids do
		local classId: ClassId = ids[ci]
		total += state.classes[classId].money
	end
	return total
end

local function copyIds(ids: { ClassId }): { ClassId }
	local copy: { ClassId } = {}
	for ci = 1, #ids do
		table.insert(copy, ids[ci])
	end
	return copy
end

local function classOrder(classId: ClassId): number
	for ci = 1, #CLASS_IDS do
		if CLASS_IDS[ci] == classId then
			return ci
		end
	end
	return #CLASS_IDS + 1
end

local function earliestOrder(ids: { ClassId }): number
	local first = #CLASS_IDS + 1
	for ci = 1, #ids do
		first = math.min(first, classOrder(ids[ci]))
	end
	return first
end

-- True when `a` beats `b`: more value, then more money, then the earlier
-- class. A missing `b` loses to anything.
local function better(a: Contender, b: Contender?): boolean
	if b == nil then
		return true
	end
	if a.value ~= b.value then
		return a.value > b.value
	end
	if a.money ~= b.money then
		return a.money > b.money
	end
	return a.order < b.order
end

-- Solo victory: every class at or above the target, best VP first, ties to
-- the higher wallet, then to CLASS_IDS order (the loop only replaces on a
-- strict improvement, so the earlier class keeps the tie).
local function soloWinner(state: MatchState, target: number): ClassId?
	local winner: ClassId? = nil
	local bestVp = 0
	local bestMoney = 0
	for ci = 1, #CLASS_IDS do
		local classId: ClassId = CLASS_IDS[ci] :: any
		local entry = state.classes[classId]
		if
			entry.vp >= target
			and (entry.vp > bestVp or (entry.vp == bestVp and entry.money > bestMoney))
		then
			winner = classId
			bestVp = entry.vp
			bestMoney = entry.money
		end
	end
	return winner
end

-- Shared victory: an alliance that has held for the configured number of
-- Days, whose combined VP reaches the combined minimum and whose every
-- member reaches the per-member minimum. Several qualifying alliances resolve
-- like the solo case (combined VP, then combined Money, then CLASS_IDS order).
--
-- With the shipped numbers the per-member bar cannot bind on its own: if one
-- member is under ceil(t x 0.4) the other would need more than t to reach the
-- combined ceil(t x 1.5), and that would already be a solo win. The check
-- stays because §11.2 states it and the factors are tunable.
local function sharedWinners(state: MatchState, target: number): { ClassId }?
	local eachMin = math.ceil(target * ConfigScoring.sharedEachFactor)
	local combinedMin = math.ceil(target * ConfigScoring.sharedCombinedFactor)
	local winner: { ClassId }? = nil
	local bestVp = 0
	local bestMoney = 0

	for ai = 1, #state.alliances do
		local alliance = state.alliances[ai]
		if Alliances.age(state, alliance) >= ConfigScoring.sharedAllianceAgeDays then
			local eachOk = true
			for mi = 1, #alliance.members do
				local member: ClassId = alliance.members[mi]
				if state.classes[member].vp < eachMin then
					eachOk = false
				end
			end
			local combined = countVp(state, alliance.members)
			local money = countMoney(state, alliance.members)
			if
				eachOk
				and combined >= combinedMin
				and (combined > bestVp or (combined == bestVp and money > bestMoney))
			then
				winner = copyIds(alliance.members)
				bestVp = combined
				bestMoney = money
			end
		end
	end

	return winner
end

-- Final Day: the best class VP against every active alliance's
-- floor(combinedVP x 0.7). Any active alliance takes part; no age
-- requirement (D-070) — the multiplier is what balances it.
local function finalWinner(state: MatchState): Contender?
	local best: Contender? = nil

	for ci = 1, #CLASS_IDS do
		local classId: ClassId = CLASS_IDS[ci] :: any
		local contender: Contender = {
			ids = { classId },
			value = state.classes[classId].vp,
			money = state.classes[classId].money,
			order = ci,
		}
		if better(contender, best) then
			best = contender
		end
	end

	for ai = 1, #state.alliances do
		local alliance = state.alliances[ai]
		local combined = countVp(state, alliance.members)
		local contender: Contender = {
			ids = copyIds(alliance.members),
			value = math.floor(combined * ConfigScoring.finalAllianceFactor),
			money = countMoney(state, alliance.members),
			order = earliestOrder(alliance.members),
		}
		if better(contender, best) then
			best = contender
		end
	end

	return best
end

local function describe(state: MatchState, result: VictoryResult): string
	local day = result.day
	if result.kind == "collapse" then
		return `The world collapsed on Day {day} — no winner`
	end

	local first: ClassId = result.winners[1]
	if result.kind == "solo" then
		return `{first} wins solo with {state.classes[first].vp} VP on Day {day}`
	end

	if #result.winners == 1 then
		-- final Day, a class alone
		return `{first} wins the final count with {state.classes[first].vp} VP on Day {day}`
	end

	local second: ClassId = result.winners[2]
	if result.kind == "shared" then
		local combined = countVp(state, result.winners)
		return `{first} and {second} win together with {combined} VP on Day {day}`
	end

	local combined = countVp(state, result.winners)
	local value = math.floor(combined * ConfigScoring.finalAllianceFactor)
	return `{first} and {second} win the final count with {value} VP on Day {day}`
end

local VictoryCheck = setmetatable({}, { __index = Step })
VictoryCheck.__index = VictoryCheck

function VictoryCheck.new(): VictoryCheck
	return setmetatable({}, VictoryCheck)
end

export type VictoryCheck = typeof(setmetatable({} :: {}, VictoryCheck))

-- The pure decision (ARCHITECTURE section 8): the result this Day produces,
-- or nil when the match goes on.
function VictoryCheck.check(state: MatchState, ruleSet: RuleSetType): VictoryResult?
	if state.victory ~= nil then
		return state.victory
	end

	local target = ruleSet:soloTarget()

	local solo: ClassId? = soloWinner(state, target)
	if solo ~= nil then
		return { kind = "solo", winners = { solo }, day = state.day }
	end

	local shared: { ClassId }? = sharedWinners(state, target)
	if shared ~= nil then
		return { kind = "shared", winners = shared, day = state.day }
	end

	if state.day >= ruleSet:rounds() then
		local best: Contender? = finalWinner(state)
		if best ~= nil then
			return { kind = "final", winners = best.ids, day = state.day }
		end
	end

	if
		ruleSet:collapseEnabled()
		and state.collapseCounter >= ConfigScoring.collapseCounterLimit
	then
		return { kind = "collapse", winners = {}, day = state.day }
	end

	return nil
end

function VictoryCheck.run(_self: VictoryCheck, state: MatchState, ctx: StepContext)
	if state.victory ~= nil then
		return
	end

	local result = VictoryCheck.check(state, ctx.ruleSet)
	if result == nil then
		return
	end

	state.victory = result
	local actor: ClassId? = nil
	if #result.winners == 1 then
		actor = result.winners[1]
	end
	log(state, {
		day = state.day,
		text = describe(state, result),
		actor = actor,
	})
end

return VictoryCheck
