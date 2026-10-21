--!strict
-- R7 Taxes (GAME_DESIGN 6.7, section 10): Working is taxed on the wages it
-- received, Middle and Capitalist on their market sales revenue (both come
-- from the R5/R6 scratch channel, D-046). The tax is floor(rate x income)
-- and is transferred to the State.
--
-- The rate comes from the class's policy track (levels 0 to 3 map to 0, 10,
-- 20, 30 percent; Config/Policies holds the per-level fraction) and is
-- applied in INTEGER PERCENT: floor(income * percent / 100). Multiplying
-- the fraction directly loses a cent on values like 0.3 x 10, which floors
-- to 2 instead of 3 (D-050).
--
-- A class that cannot pay its tax in full does not pay it (the transfer
-- fails like any other transfer, GAME_DESIGN 8.1) and the collection is
-- skipped with a log entry (D-049). A class whose tax track is disabled on
-- this difficulty is not taxed at all.

local Types = require(script.Parent.Parent.Types)
local Step = require(script.Parent.Step)
local StateOps = require(script.Parent.Parent.State.StateOps)
local ConfigPolicies = require(script.Parent.Parent.Parent.Config.Policies)

type ClassId = Types.ClassId
type DayScratch = Step.DayScratch
type LogEntry = Types.LogEntry
type MatchState = Types.MatchState
type PolicyId = Types.PolicyId
type StepContext = Step.StepContext

local function log(state: MatchState, entry: LogEntry)
	table.insert(state.eventLog, entry)
end

-- The tax track of a class, or nil for the State (it is not taxed).
local function taxTrackFor(classId: ClassId): PolicyId?
	if classId == "Working" then
		return "TaxWorking"
	end
	if classId == "Middle" then
		return "TaxMiddle"
	end
	if classId == "Capitalist" then
		return "TaxCapitalist"
	end
	return nil
end

-- Income of a class this Day (6.7): Working earns wages, Middle and
-- Capitalist earn market revenue.
local function incomeFor(classId: ClassId, scratch: DayScratch): number
	local workingId: ClassId = "Working"
	if classId == workingId then
		local wages: number = (scratch.wagesReceived :: any)[workingId] or 0
		return wages
	end
	local revenue: number = (scratch.salesRevenue :: any)[classId] or 0
	return revenue
end

local TaxesStep = setmetatable({}, { __index = Step })
TaxesStep.__index = TaxesStep

function TaxesStep.new(): TaxesStep
	return setmetatable({}, TaxesStep)
end

export type TaxesStep = typeof(setmetatable({} :: {}, TaxesStep))

function TaxesStep.run(_self: TaxesStep, state: MatchState, ctx: StepContext)
	local scratch = ctx.scratch

	for ci = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[ci] :: any
		-- luau-lsp 1.70.1: a declared return type does not reach the call
		-- site, so the local is annotated here (see luau-conventions)
		local trackId: PolicyId? = taxTrackFor(classId)
		if trackId ~= nil then
			-- A disabled track is simply absent from the state (D-041): the
			-- class is not taxed on this difficulty.
			local level: number = (state.policies :: any)[trackId]
			if level ~= nil then
				local rate: number = (ConfigPolicies.tracks[trackId].levelValues :: { [any]: any })[level]
				-- Percent as an integer: the fraction in config is a float, and
				-- 0.3 * 10 lands just below 3 in binary floating point. The
				-- half-step keeps the conversion exact for the config's
				-- 0 / 0.1 / 0.2 / 0.3 fractions.
				local percent = math.floor(rate * 100 + 0.5)
				local income = incomeFor(classId, scratch)
				local tax = math.floor(income * percent / 100)

				if tax > 0 then
					if StateOps.subtractResource(state, classId, "Money", tax) then
						StateOps.addResource(state, "State", "Money", tax)
						log(state, {
							day = state.day,
							text = `{classId} paid {tax} Money tax ({percent}%)`,
							actor = classId,
						})
					else
						log(state, {
							day = state.day,
							text = `{classId} tax skipped: cannot pay {tax} Money`,
							actor = classId,
						})
					end
				end
			end
		end
	end
end

return TaxesStep
