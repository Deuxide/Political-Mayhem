--!strict
-- The NoBreakAlliance promise kind (GAME_DESIGN 8.3): the alliance with the
-- promisee must not be broken until `untilDay`. It is audited at every
-- Closing Bell: a broken alliance breaks the promise at once, otherwise it
-- is kept once `untilDay` has passed.
local Types = require(script.Parent.Parent.Parent.Types)
local PromiseRules = require(script.Parent.PromiseRules)

type ClassId = Types.ClassId
type MatchState = Types.MatchState
type Promise = Types.Promise
type PromiseEvent = PromiseRules.PromiseEvent
type PromiseSpec = Types.PromiseSpec
type AuditResult = PromiseRules.AuditResult

local NoBreakAlliancePromise = setmetatable({}, { __index = PromiseRules })
NoBreakAlliancePromise.__index = NoBreakAlliancePromise

function NoBreakAlliancePromise.validate(
	_self: NoBreakAlliancePromise,
	_from: ClassId,
	_to: ClassId,
	spec: PromiseSpec
): (boolean, string)
	if spec.kind ~= "NoBreakAlliance" then
		return false, "not a NoBreakAlliance promise"
	end
	return true, ""
end

function NoBreakAlliancePromise.create(
	_self: NoBreakAlliancePromise,
	id: string,
	from: ClassId,
	to: ClassId,
	spec: PromiseSpec,
	createdDay: number
): Promise
	return {
		id = id,
		kind = "NoBreakAlliance",
		spec = spec,
		from = from,
		to = to,
		createdDay = createdDay,
		status = "open",
		progress = { broken = false },
	}
end

function NoBreakAlliancePromise.credit(
	_self: NoBreakAlliancePromise,
	_state: MatchState,
	promise: Promise,
	event: PromiseEvent
)
	if event.kind ~= "BreakAlliance" then
		return
	end
	-- the alliance of the two classes is gone, whoever broke it (8.3)
	local touchesPromisor = event.from == promise.from or event.to == promise.from
	local touchesPromisee = event.from == promise.to or event.to == promise.to
	if touchesPromisor and touchesPromisee then
		promise.progress.broken = true
	end
end

function NoBreakAlliancePromise.audit(
	_self: NoBreakAlliancePromise,
	_state: MatchState,
	promise: Promise,
	today: number
): AuditResult
	local spec = promise.spec
	if spec.kind ~= "NoBreakAlliance" then
		return "open"
	end
	if promise.progress.broken == true then
		return "broken"
	end
	if today >= spec.untilDay then
		return "kept"
	end
	return "open"
end

export type NoBreakAlliancePromise = typeof(setmetatable({} :: {}, NoBreakAlliancePromise))

return NoBreakAlliancePromise
