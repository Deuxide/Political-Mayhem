--!strict
-- The VoteYes promise kind (GAME_DESIGN 8.3): the promisor promises to
-- vote Yes on a bill that sets `policyId` to `level` by `byDay`. It is kept
-- when the promisor cast a Yes vote on a matching bill (any committed
-- Influence) on or before `byDay`.
local Types = require(script.Parent.Parent.Parent.Types)
local PromiseRules = require(script.Parent.PromiseRules)

type ClassId = Types.ClassId
type MatchState = Types.MatchState
type Promise = Types.Promise
type PromiseEvent = PromiseRules.PromiseEvent
type PromiseSpec = Types.PromiseSpec
type AuditResult = PromiseRules.AuditResult

local VoteYesPromise = setmetatable({}, { __index = PromiseRules })
VoteYesPromise.__index = VoteYesPromise

function VoteYesPromise.validate(
	_self: VoteYesPromise,
	_from: ClassId,
	_to: ClassId,
	spec: PromiseSpec
): (boolean, string)
	if spec.kind ~= "VoteYes" then
		return false, "not a VoteYes promise"
	end
	return true, ""
end

function VoteYesPromise.create(
	_self: VoteYesPromise,
	id: string,
	from: ClassId,
	to: ClassId,
	spec: PromiseSpec,
	createdDay: number
): Promise
	return {
		id = id,
		kind = "VoteYes",
		spec = spec,
		from = from,
		to = to,
		createdDay = createdDay,
		status = "open",
		progress = { yesVoted = false },
	}
end

function VoteYesPromise.credit(
	_self: VoteYesPromise,
	_state: MatchState,
	promise: Promise,
	event: PromiseEvent
)
	if event.kind ~= "VoteYes" then
		return
	end
	local spec = promise.spec
	if spec.kind ~= "VoteYes" then
		return
	end
	if event.from ~= promise.from then
		return
	end
	if event.policyId ~= spec.policyId or event.level ~= spec.level then
		return
	end
	promise.progress.yesVoted = true
end

function VoteYesPromise.audit(
	_self: VoteYesPromise,
	_state: MatchState,
	promise: Promise,
	today: number
): AuditResult
	local spec = promise.spec
	if spec.kind ~= "VoteYes" then
		return "open"
	end
	if today < spec.byDay then
		return "open" -- the promise is still running
	end
	if promise.progress.yesVoted == true then
		return "kept"
	end
	return "broken"
end

export type VoteYesPromise = typeof(setmetatable({} :: {}, VoteYesPromise))

return VoteYesPromise
