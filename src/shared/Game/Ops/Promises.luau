--!strict
-- Promises (GAME_DESIGN 8.3): the module that creates promise records
-- from their specs and audits them. A promise is never enforced — the
-- audit decides whether the promisor kept it, and the R11 step turns that
-- into Reputation.
--
-- The kinds live under `Game/Behaviors/Promises/` (one behavior class
-- each); this module dispatches to them and keeps the records in the
-- state.
local Types = require(script.Parent.Parent.Types)
local PromiseRules = require(script.Parent.Parent.Behaviors.Promises.PromiseRules)
local DeliverPromise = require(script.Parent.Parent.Behaviors.Promises.DeliverPromise)
local VoteYesPromise = require(script.Parent.Parent.Behaviors.Promises.VoteYesPromise)
local NoStrikePromise = require(script.Parent.Parent.Behaviors.Promises.NoStrikePromise)
local NoBreakAlliancePromise =
	require(script.Parent.Parent.Behaviors.Promises.NoBreakAlliancePromise)

type AuditResult = PromiseRules.AuditResult
type ClassId = Types.ClassId
type MatchState = Types.MatchState
type Promise = Types.Promise
type PromiseEvent = PromiseRules.PromiseEvent
type PromiseKind = Types.PromiseKind
type PromiseSpec = Types.PromiseSpec

local Promises = {}

-- The behavior class of a kind (the registry of 8.3).
local function classFor(kind: PromiseKind): PromiseRules.PromiseKindClass
	if kind == "Deliver" then
		return DeliverPromise :: any
	end
	if kind == "VoteYes" then
		return VoteYesPromise :: any
	end
	if kind == "NoStrike" then
		return NoStrikePromise :: any
	end
	return NoBreakAlliancePromise :: any
end

-- Creates a promise record from a spec, and puts it in the state.
function Promises.create(
	state: MatchState,
	from: ClassId,
	to: ClassId,
	spec: PromiseSpec
): (Promise?, string)
	if from == to then
		return nil, "a class cannot promise something to itself"
	end

	local class = classFor(spec.kind)
	local valid, reason = class:validate(from, to, spec)
	if not valid then
		return nil, reason
	end

	local promise = class:create(`Promise-{#state.promises + 1}`, from, to, spec, state.day)
	table.insert(state.promises, promise)
	return promise, ""
end

-- Tells the open promises about something that happened; the kinds that
-- care about it update their progress.
function Promises.deliver(state: MatchState, event: PromiseEvent)
	for _, promise in state.promises do
		if promise.status == "open" then
			classFor(promise.kind):credit(state, promise, event)
		end
	end
end

-- The audit of one promise (8.3): open, kept, or broken.
function Promises.audit(state: MatchState, promise: Promise, today: number): AuditResult
	return classFor(promise.kind):audit(state, promise, today)
end

-- The open promises of a class that made them (the promisor).
function Promises.openOf(state: MatchState, classId: ClassId): { Promise }
	local open: { Promise } = {}
	for _, promise in state.promises do
		if promise.status == "open" and promise.from == classId then
			table.insert(open, promise)
		end
	end
	return open
end

return Promises
