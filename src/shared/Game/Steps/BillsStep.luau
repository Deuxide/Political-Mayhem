--!strict
-- R3 Bills (GAME_DESIGN 7.3, section 10): every live bill is tallied, the
-- Influence committed to a vote is spent (whether or not the bill passes),
-- and a passing bill changes its policy track immediately — before
-- production that Day.
--
-- The step only moves the level. The effect of the new level is carried
-- out by the step that owns it (R5 wages, R6 tariff, R7 taxes, R8 services,
-- R9 strikes), so the rules stay in one place instead of being applied
-- twice (D-057).

local Types = require(script.Parent.Parent.Types)
local Step = require(script.Parent.Step)
local Bills = require(script.Parent.Parent.Ops.Bills)

type ClassId = Types.ClassId
type LogEntry = Types.LogEntry
type MatchState = Types.MatchState
type PolicyId = Types.PolicyId
type StepContext = Step.StepContext

local function log(state: MatchState, entry: LogEntry)
	table.insert(state.eventLog, entry)
end

local BillsStep = setmetatable({}, { __index = Step })
BillsStep.__index = BillsStep

function BillsStep.new(): BillsStep
	return setmetatable({}, BillsStep)
end

export type BillsStep = typeof(setmetatable({} :: {}, BillsStep))

function BillsStep.run(_self: BillsStep, state: MatchState, _ctx: StepContext)
	-- The live bills, in proposal order.
	for _, bill in state.bills do
		local tally = Bills.tally(state, bill.id)
		local spent = Bills.spendCommitted(state, bill.id)

		for ci = 1, #Types.CLASS_IDS do
			local classId: ClassId = Types.CLASS_IDS[ci] :: any
			local amount = spent[classId]
			if amount ~= nil and amount > 0 then
				log(state, {
					day = state.day,
					text = `{classId} spent {amount} Influence on its vote`,
					actor = classId,
				})
			end
		end

		if tally.passed then
			local policyId: PolicyId = bill.policyId
			-- the policies map is keyed by a union; the assignment goes
			-- through a local (luau-lsp 1.70.1 rejects a cast as a target)
			local policies = state.policies :: any
			policies[policyId] = bill.level
			log(state, {
				day = state.day,
				text = `{policyId} is now level {bill.level} ({tally.yesWeight} for, {tally.noWeight} against)`,
				actor = bill.proposer,
			})
		else
			log(state, {
				day = state.day,
				text = `The bill on {bill.policyId} failed ({tally.yesWeight} for, {tally.noWeight} against — {tally.reason})`,
				actor = bill.proposer,
			})
		end
	end

	-- The bills are resolved; new proposals belong to the next Window.
	state.bills = {}
end

return BillsStep
