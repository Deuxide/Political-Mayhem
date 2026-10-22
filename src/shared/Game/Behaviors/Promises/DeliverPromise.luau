--!strict
-- The Deliver promise kind (GAME_DESIGN 8.3): the promisor owes the
-- promisee a transfer of at least `amount` of `resource` by `byDay`. It is
-- kept when transfers of that amount happened between the promise's
-- creation and `byDay` (inclusive).
local Types = require(script.Parent.Parent.Parent.Types)
local PromiseRules = require(script.Parent.PromiseRules)

type ClassId = Types.ClassId
type MatchState = Types.MatchState
type Promise = Types.Promise
type PromiseEvent = PromiseRules.PromiseEvent
type PromiseSpec = Types.PromiseSpec
type AuditResult = PromiseRules.AuditResult

local DeliverPromise = setmetatable({}, { __index = PromiseRules })
DeliverPromise.__index = DeliverPromise

function DeliverPromise.validate(
	_self: DeliverPromise,
	_from: ClassId,
	to: ClassId,
	spec: PromiseSpec
): (boolean, string)
	if spec.kind ~= "Deliver" then
		return false, "not a Deliver promise"
	end
	if spec.to ~= to then
		return false, "the promise's recipient does not match the promisee"
	end
	if spec.amount <= 0 or spec.amount ~= math.floor(spec.amount) then
		return false, "the promised amount must be a whole number"
	end
	return true, ""
end

function DeliverPromise.create(
	_self: DeliverPromise,
	id: string,
	from: ClassId,
	to: ClassId,
	spec: PromiseSpec,
	createdDay: number
): Promise
	return {
		id = id,
		kind = "Deliver",
		spec = spec,
		from = from,
		to = to,
		createdDay = createdDay,
		status = "open",
		progress = { delivered = 0 },
	}
end

function DeliverPromise.credit(
	_self: DeliverPromise,
	_state: MatchState,
	promise: Promise,
	event: PromiseEvent
)
	if event.kind ~= "Transfer" then
		return
	end
	local spec = promise.spec
	if spec.kind ~= "Deliver" then
		return
	end
	if event.from ~= promise.from or event.to ~= promise.to then
		return
	end
	if event.resource ~= spec.resource then
		return
	end
	promise.progress.delivered = (promise.progress.delivered or 0) + event.amount
end

function DeliverPromise.audit(
	_self: DeliverPromise,
	_state: MatchState,
	promise: Promise,
	today: number
): AuditResult
	local spec = promise.spec
	if spec.kind ~= "Deliver" then
		return "open"
	end
	if today < spec.byDay then
		return "open" -- the promise is still running
	end
	if (promise.progress.delivered or 0) >= spec.amount then
		return "kept"
	end
	return "broken"
end

export type DeliverPromise = typeof(setmetatable({} :: {}, DeliverPromise))

return DeliverPromise
