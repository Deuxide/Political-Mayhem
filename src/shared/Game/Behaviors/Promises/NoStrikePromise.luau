--!strict
-- The NoStrike promise kind (GAME_DESIGN 8.3, Working only): the promisor
-- promises not to strike against the promisee until `untilDay`. It is
-- audited at every Closing Bell: a strike breaks it at once, otherwise it
-- is kept once `untilDay` has passed.
local Types = require(script.Parent.Parent.Parent.Types)
local PromiseRules = require(script.Parent.PromiseRules)

type ClassId = Types.ClassId
type MatchState = Types.MatchState
type Promise = Types.Promise
type PromiseEvent = PromiseRules.PromiseEvent
type PromiseSpec = Types.PromiseSpec
type AuditResult = PromiseRules.AuditResult

local NoStrikePromise = setmetatable({}, { __index = PromiseRules })
NoStrikePromise.__index = NoStrikePromise

function NoStrikePromise.validate(
	_self: NoStrikePromise,
	from: ClassId,
	_to: ClassId,
	spec: PromiseSpec
): (boolean, string)
	if spec.kind ~= "NoStrike" then
		return false, "not a NoStrike promise"
	end
	if from ~= "Working" then
		return false, "only Working can promise not to strike"
	end
	return true, ""
end

function NoStrikePromise.create(
	_self: NoStrikePromise,
	id: string,
	from: ClassId,
	to: ClassId,
	spec: PromiseSpec,
	createdDay: number
): Promise
	return {
		id = id,
		kind = "NoStrike",
		spec = spec,
		from = from,
		to = to,
		createdDay = createdDay,
		status = "open",
		progress = { struck = false },
	}
end

function NoStrikePromise.credit(
	_self: NoStrikePromise,
	_state: MatchState,
	promise: Promise,
	event: PromiseEvent
)
	if event.kind ~= "Strike" then
		return
	end
	if event.from ~= promise.from or event.to ~= promise.to then
		return
	end
	promise.progress.struck = true
end

function NoStrikePromise.audit(
	_self: NoStrikePromise,
	_state: MatchState,
	promise: Promise,
	today: number
): AuditResult
	local spec = promise.spec
	if spec.kind ~= "NoStrike" then
		return "open"
	end
	if promise.progress.struck == true then
		return "broken" -- a strike breaks it right away
	end
	if today >= spec.untilDay then
		return "kept"
	end
	return "open"
end

export type NoStrikePromise = typeof(setmetatable({} :: {}, NoStrikePromise))

return NoStrikePromise
