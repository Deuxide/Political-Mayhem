--!strict
-- The promise kinds (GAME_DESIGN 8.3): one behavior class per kind, all
-- under this abstract base (ARCHITECTURE 3.1 "Behavior" — one abstract
-- base, depth 1). Each kind knows how to validate its spec, how to build
-- its record, what it watches for, and when it was kept.
--
-- A promise is never enforced: it is audited, and the audit decides the
-- promisor's reputation (8.3).

local Types = require(script.Parent.Parent.Parent.Types)
local Abstract = require(script.Parent.Parent.Parent.Abstract)

type ClassId = Types.ClassId
type MatchState = Types.MatchState
type PolicyId = Types.PolicyId
type Promise = Types.Promise
type PromiseKind = Types.PromiseKind
type PromiseSpec = Types.PromiseSpec
type ResourceId = Types.ResourceId

-- What can happen to a promise. A kind reacts to the events it cares about
-- and ignores the others.
export type PromiseEvent =
	| { kind: "Transfer", from: ClassId, to: ClassId, resource: ResourceId, amount: number }
	| { kind: "VoteYes", from: ClassId, policyId: PolicyId, level: number }
	| { kind: "Strike", from: ClassId, to: ClassId }
	| { kind: "BreakAlliance", from: ClassId, to: ClassId }

-- The audit's answer: still open, kept, or broken.
export type AuditResult = "open" | "kept" | "broken"

local PromiseRules = {}
PromiseRules.__index = PromiseRules

-- Whether a class may make this promise (8.3).
function PromiseRules.validate(
	_self: PromiseRules,
	_from: ClassId,
	_to: ClassId,
	_spec: PromiseSpec
): (boolean, string)
	Abstract.notImplemented("PromiseRules", "validate")
	return false, ""
end

-- The record for a promise of this kind.
function PromiseRules.create(
	_self: PromiseRules,
	_id: string,
	_from: ClassId,
	_to: ClassId,
	_spec: PromiseSpec,
	_createdDay: number
): Promise
	Abstract.notImplemented("PromiseRules", "create")
	error("unreachable")
end

-- Reacts to an event; a kind only listens to its own.
function PromiseRules.credit(
	_self: PromiseRules,
	_state: MatchState,
	_promise: Promise,
	_event: PromiseEvent
)
	Abstract.notImplemented("PromiseRules", "credit")
end

-- Whether the promise is kept, broken, or still open (8.3).
function PromiseRules.audit(
	_self: PromiseRules,
	_state: MatchState,
	_promise: Promise,
	_today: number
): AuditResult
	Abstract.notImplemented("PromiseRules", "audit")
	return "open"
end

export type PromiseRules = typeof(setmetatable({} :: {}, PromiseRules))

export type PromiseKindClass = typeof(setmetatable({} :: {}, PromiseRules))

return PromiseRules
