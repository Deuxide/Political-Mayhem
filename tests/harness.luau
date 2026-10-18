--!strict
-- Test harness for running shared/Game tests under Lune.
-- Inlined implementations match the actual modules in src/shared/Game.

-- Inlined Rng (matches src/shared/Game/Rng.luau)
local function xorshift32(state: number): number
	state = bit32.bxor(state, bit32.lshift(state, 13))
	state = bit32.bxor(state, bit32.rshift(state, 17))
	state = bit32.bxor(state, bit32.lshift(state, 5))
	return state
end

local Rng = {}
Rng.__index = Rng

function Rng.new(seed: number)
	assert(seed > 0, "RNG seed must be positive")
	local self = setmetatable({}, Rng)
	self._state = seed
	return self
end

function Rng:next(): number
	self._state = xorshift32(self._state)
	return self._state / 0x100000000
end

function Rng:int(a: number, b: number): number
	assert(a <= b, "int: a must be <= b")
	return a + math.floor(self:next() * (b - a + 1))
end

function Rng:shuffle<T>(list: { T }): { T }
	local result = {}
	for i, v in ipairs(list) do
		result[i] = v
	end
	for i = #result, 2, -1 do
		local j = self:int(1, i)
		result[i], result[j] = result[j], result[i]
	end
	return result
end

function Rng:clone()
	local copy = Rng.new(1)
	copy._state = self._state
	return copy
end

-- Inlined SerializableChecker (matches src/shared/Game/State/assertSerializable.luau)
local function assertSerializable(value: any, path: string?)
	local function check(v: any, p: string, seen: { [any]: boolean })
		local t = type(v)
		if t == "nil" or t == "boolean" or t == "number" or t == "string" then
			return
		elseif t == "table" then
			if seen[v] then
				error("Cycle detected at " .. p, 0)
			end
			seen[v] = true

			if getmetatable(v) then
				error("Metatable found at " .. p, 0)
			end

			for k, val in pairs(v) do
				local kt = type(k)
				if kt ~= "string" and kt ~= "number" then
					error("Non-string/number key (" .. kt .. ") at " .. p, 0)
				end
				check(val, p .. "." .. tostring(k), seen)
			end

			seen[v] = nil
		elseif t == "function" then
			error("Function found at " .. p, 0)
		elseif t == "thread" then
			error("Thread found at " .. p, 0)
		elseif t == "userdata" then
			error("Userdata (possible Instance) found at " .. p, 0)
		else
			error("Unknown type " .. t .. " at " .. p, 0)
		end
	end

	check(value, path or "root", {})
end

-- Inlined abstract helper (matches src/shared/Game/Util/abstract.luau)
local function abstract(methodName: string): never
	error("not implemented: " .. methodName, 2)
end

-- Inlined Signal (matches src/shared/Game/Util/Signal.luau, adapted for Lune)
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _connections = {} }, Signal)
end

function Signal:Connect(callback)
	local connection = {
		_connected = true,
		_callback = callback,
		Disconnect = function(self)
			self._connected = false
		end,
	}
	table.insert(self._connections, connection)
	return connection
end

function Signal:Fire(...)
	for i = #self._connections, 1, -1 do
		local conn = self._connections[i]
		if conn._connected then
			-- Direct call instead of task.spawn for Lune compatibility
			conn._callback(...)
		else
			table.remove(self._connections, i)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		coroutine.resume(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:Once(callback)
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

export type TestHarness = {
	run: () -> (),
}

local TestHarness = {}

local passed = 0
local failed = 0

local function assertEquals(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error((message or "Assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

local function assertTrue(condition: boolean, message: string?)
	if not condition then
		error(message or "Expected true", 2)
	end
end

local function test(name: string, fn: () -> ())
	local success, err = pcall(fn)
	if success then
		print("✓ " .. name)
		passed += 1
	else
		print("✗ " .. name .. ": " .. tostring(err))
		failed += 1
	end
end

function TestHarness.run()
	print("Running tests...")

	test("Rng:next returns value between 0 and 1", function()
		local rng = Rng.new(12345)
		local value = rng:next()
		assertTrue(value >= 0 and value < 1)
	end)

	test("Rng:int returns value in range", function()
		local rng = Rng.new(12345)
		for _ = 1, 100 do
			local value = rng:int(1, 10)
			assertTrue(value >= 1 and value <= 10)
		end
	end)

	test("Rng:clone produces same sequence", function()
		local rng1 = Rng.new(12345)
		local rng2 = rng1:clone()
		for _ = 1, 10 do
			assertEquals(rng1:next(), rng2:next())
		end
	end)

	test("Rng:shuffle returns permutation", function()
		local rng = Rng.new(12345)
		local list = { 1, 2, 3, 4, 5 }
		local shuffled = rng:shuffle(list)
		assertEquals(#shuffled, 5)
		table.sort(shuffled)
		for i, v in ipairs(shuffled) do
			assertEquals(v, i)
		end
	end)

	test("SerializableChecker: accepts plain tables", function()
		assertSerializable({
			name = "test",
			value = 42,
			nested = { a = 1, b = 2 },
		})
	end)

	test("SerializableChecker: accepts arrays", function()
		assertSerializable({ 1, 2, 3, "hello" })
	end)

	test("SerializableChecker: rejects functions", function()
		local success = pcall(function()
			assertSerializable({ fn = function() end })
		end)
		assertTrue(not success)
	end)

	test("SerializableChecker: rejects metatables", function()
		local success = pcall(function()
			local t = setmetatable({}, { __index = {} })
			assertSerializable(t)
		end)
		assertTrue(not success)
	end)

	test("SerializableChecker: rejects cycles", function()
		local success = pcall(function()
			local t: any = {}
			t.self = t
			assertSerializable(t)
		end)
		assertTrue(not success)
	end)

	-- Abstract helper tests
	test("abstract helper throws with method name", function()
		local success = pcall(function()
			abstract("MyClass:myMethod")
		end)
		assertTrue(not success)
	end)

	-- Signal tests
	test("Signal:Connect and Fire", function()
		local signal = Signal.new()
		local called = false
		local value = 0
		signal:Connect(function(v)
			called = true
			value = v
		end)
		signal:Fire(42)
		assertTrue(called)
		assertEquals(value, 42)
	end)

	test("Signal:Connect multiple callbacks", function()
		local signal = Signal.new()
		local count = 0
		signal:Connect(function() count += 1 end)
		signal:Connect(function() count += 1 end)
		signal:Fire()
		assertEquals(count, 2)
	end)

	test("Signal:Disconnect prevents firing", function()
		local signal = Signal.new()
		local called = false
		local conn = signal:Connect(function() called = true end)
		conn:Disconnect()
		signal:Fire()
		assertTrue(not called)
	end)

	test("Signal:Wait resumes with fired values", function()
		local signal = Signal.new()
		local received
		-- Use coroutine directly since task.spawn doesn't exist in Lune
		local co = coroutine.create(function()
			received = { signal:Wait() }
		end)
		coroutine.resume(co)
		signal:Fire("hello", "world")
		assertEquals(received[1], "hello")
		assertEquals(received[2], "world")
	end)

	test("Signal:Once fires only once", function()
		local signal = Signal.new()
		local count = 0
		signal:Once(function() count += 1 end)
		signal:Fire()
		signal:Fire()
		assertEquals(count, 1)
	end)

	test("Signal:Destroy clears all connections", function()
		local signal = Signal.new()
		signal:Connect(function() end)
		signal:Connect(function() end)
		signal:Destroy()
		signal:Fire()
		-- Should not error
	end)

	print("\nResults: " .. passed .. " passed, " .. failed .. " failed")
	if failed > 0 then
		error("Some tests failed", 0)
	end
end

return TestHarness