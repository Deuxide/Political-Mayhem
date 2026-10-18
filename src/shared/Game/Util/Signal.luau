--!strict
-- Signal: minimal event class (no Instances).
-- Used for decoupled communication between objects with identity/lifecycle.

export type Connection = {
	Disconnect: (self: Connection) -> (),
	_connected: boolean,
	_callback: (...any) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Destroy: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	return setmetatable({
		_connections = {} :: { Connection },
	}, Signal)
end

function Signal:Connect(callback: (...any) -> ()): Connection
	local connection = {
		_connected = true,
		_callback = callback,
		Disconnect = function(self) self._connected = false end,
	}
	table.insert(self._connections, connection)
	return connection
end

function Signal:Fire(...)
	for i = #self._connections, 1, -1 do
		local conn = self._connections[i]
		if conn._connected then
			task.spawn(conn._callback, ...)
		else
			table.remove(self._connections, i)
		end
	end
end

function Signal:Wait(): any
	local thread = coroutine.running()
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:Once(callback: (...any) -> ()): Connection
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		callback(...)
	end)
	return conn
end

function Signal:Destroy()
	for _, conn in ipairs(self._connections) do
		conn._connected = false
	end
	table.clear(self._connections)
end

return Signal
