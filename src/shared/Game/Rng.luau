--!strict
-- Seedable PRNG for deterministic game logic. No global math.random.

local Types = require(script.Parent.Types)

export type Rng = {
	_state: number,
	next: (self: Rng) -> number,
	int: (self: Rng, a: number, b: number) -> number,
	shuffle: <T>(self: Rng, list: { T }) -> { T },
	clone: (self: Rng) -> Rng,
}

local function xorshift32(state: number): number
	state = bit32.bxor(state, bit32.lshift(state, 13))
	state = bit32.bxor(state, bit32.rshift(state, 17))
	state = bit32.bxor(state, bit32.lshift(state, 5))
	return state
end

local Rng = {}
Rng.__index = Rng

function Rng.new(seed: number): Rng
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

function Rng:clone(): Rng
	local copy = Rng.new(1)
	copy._state = self._state
	return copy
end

return Rng
