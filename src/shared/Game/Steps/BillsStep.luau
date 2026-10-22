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
local Promises = require(script.Parent.Parent.Ops.Promises)

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

function BillsStep.run(_self: BillsStep, state: MatchState, ctx: StepContext)
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
			-- R12 scores "a bill this class proposed passed" (11.1); keep
			-- the record here, before the Day's bills are cleared.
			table.insert(ctx.scratch.passedBills, {
				proposer = bill.proposer,
				policyId = policyId,
				level = bill.level,
			})
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

		-- a yes vote on this bill counts towards the open VoteYes promises
		-- of the classes that cast it (8.3)
		for ci = 1, #Types.CLASS_IDS do
			local classId: ClassId = Types.CLASS_IDS[ci] :: any
			if Bills.sideOf(state, classId, bill.id) == "yes" then
				Promises.deliver(state, {
					kind = "VoteYes",
					from = classId,
					policyId = bill.policyId,
					level = bill.level,
				})
			end
		end
	end

	-- The bills are resolved; new proposals belong to the next Window.
	state.bills = {}
end

return BillsStep
