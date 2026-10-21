--!strict
-- Signal (ARCHITECTURE 3.1 "Key pieces"): minimal event class, no Instances,
-- no yielding. Handler firing order equals connect order. Handlers run inline;
-- a handler erroring propagates to the firing code (no silent swallowing), the
-- Store in M4 decides how to surface errors.
--
-- Runtime-only: Signal and its closures never appear in MatchState —
-- State.assertSerializable rejects metatable-bearing values, which covers them.
--
-- Handlers are stored in a numeric-key map with increasing ids so a mid-list
-- disconnect can never shift other connections (a plain array with holes would
-- make `#` and inserts unreliable).
--
-- Methods are dot-defined with an explicit `self: Signal` annotation: that is
-- the only form luau-lsp can type reliably here. Call sites keep `:` sugar
-- (`signal:connect(fn)` is exactly `Signal.connect(signal, fn)`).

local Signal = {}
Signal.__index = Signal

export type Handler = (...any) -> ()

function Signal.new(): Signal
	return setmetatable({ _handlers = {}, _nextId = 1 }, Signal)
end

-- connect returns the disconnect closure itself (a separate Connection class
-- would only add identity the caller never needs).
function Signal.connect(self: Signal, handler: Handler): () -> ()
	local id = self._nextId
	self._nextId += 1
	self._handlers[id] = handler
	return function()
		self._handlers[id] = nil
	end
end

-- Ids are sorted so fire order is connect order regardless of disconnects.
-- A handler removed before its fire turn is skipped.
function Signal.fire(self: Signal, ...: any)
	local ids: { number } = {}
	for id in pairs(self._handlers) do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		(self._handlers[id] :: Handler)(...)
	end
end

-- The instance type alias sits below the method definitions so `typeof` sees
-- the complete metatable; Luau type aliases are order-independent.
export type Signal = typeof(setmetatable(
	{} :: {
		_handlers: { [number]: Handler },
		_nextId: number,
	},
	Signal
))

return Signal
