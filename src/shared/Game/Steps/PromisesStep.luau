--!strict
-- R11 Promises (GAME_DESIGN 8.3, section 10): the promises that are due —
-- or that are audited every Closing Bell — are judged now, and the outcome
-- goes into the promisor's Reputation. A broken promise is public: the
-- Evening Report line names both classes (8.3).
--
-- The strike the promisor currently has in its draft is delivered to the
-- NoStrike promises before the audit (a strike that never reached a
-- Closing Bell left no record — D-064).
local Types = require(script.Parent.Parent.Types)
local Step = require(script.Parent.Step)
local Promises = require(script.Parent.Parent.Ops.Promises)
local Reputation = require(script.Parent.Parent.Ops.Reputation)

type ClassId = Types.ClassId
type LogEntry = Types.LogEntry
type MatchState = Types.MatchState
type StepContext = Step.StepContext

local function log(state: MatchState, entry: LogEntry)
	table.insert(state.eventLog, entry)
end

local PromisesStep = setmetatable({}, { __index = Step })
PromisesStep.__index = PromisesStep

function PromisesStep.new(): PromisesStep
	return setmetatable({}, PromisesStep)
end

export type PromisesStep = typeof(setmetatable({} :: {}, PromisesStep))

function PromisesStep.run(_self: PromisesStep, state: MatchState, _ctx: StepContext)
	-- A strike that is still in the promisor's draft breaks its NoStrike
	-- promises (8.3).
	for _, promise in state.promises do
		if promise.status == "open" and promise.kind == "NoStrike" then
			local strike = state.drafts[promise.from].strike
			if strike ~= nil and strike.target == promise.to then
				Promises.deliver(state, {
					kind = "Strike",
					from = promise.from,
					to = promise.to,
				})
			end
		end
	end

	for _, promise in state.promises do
		if promise.status == "open" then
			local result = Promises.audit(state, promise, state.day)
			if result == "kept" then
				promise.status = "kept"
				Reputation.record(state, promise.from, true)
				log(state, {
					day = state.day,
					text = `{promise.from} kept their {promise.kind} promise to {promise.to}`,
					actor = promise.from,
				})
			elseif result == "broken" then
				promise.status = "broken"
				Reputation.record(state, promise.from, false)
				log(state, {
					day = state.day,
					text = `{promise.from} broke their {promise.kind} promise to {promise.to}`,
					actor = promise.from,
				})
			end
		end
	end
end

return PromisesStep
