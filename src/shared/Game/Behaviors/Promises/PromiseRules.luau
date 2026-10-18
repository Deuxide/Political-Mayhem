--!strict
-- Abstract base for promise audit rules.

local Types = require(script.Parent.Parent.Parent.Types)

export type PromiseRules = {
	_kind: string,
	new: () -> PromiseRules,
	audit: (self: PromiseRules, state: Types.MatchState, promise: Types.Promise) -> boolean,
}

local PromiseRules = {}
PromiseRules.__index = PromiseRules

function PromiseRules.new(kind: string) return setmetatable({ _kind = kind }, PromiseRules) end

function PromiseRules:audit(state: Types.MatchState, promise: Types.Promise): boolean
	error("not implemented: PromiseRules:audit")
end

return PromiseRules
