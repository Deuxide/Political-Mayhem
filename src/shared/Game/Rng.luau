--!strict
-- The only randomness source in src/shared/Game (D-018): a seedable xorshift32
-- over a 32-bit internal state. No `math.random`, no `Random.new` — the
-- config.test/pipeline tests and replays count on full determinism.
-- Runtime object with identity (ARCHITECTURE 3.1 "Objects"), never part of
-- state. Methods are dot-defined with an explicit `self` (M1-T0 template);
-- call sites keep the `:` sugar.

local Rng = {}
Rng.__index = Rng

-- xorshift32 (Marsaglia triple shift 13/17/5). State 0 is a fixed point, so a
-- seed that folds to 0 falls back to a non-zero constant.
local ZERO_SEED_FALLBACK = 0x6C078965

local function nextU32(state: number): number
	state = bit32.bxor(state, bit32.lshift(state, 13))
	state = bit32.bxor(state, bit32.rshift(state, 17))
	state = bit32.bxor(state, bit32.lshift(state, 5))
	return state
end

local function fromState(state: number): Rng
	return setmetatable({ _state = state } :: { _state: number }, Rng)
end

function Rng.new(seed: number): Rng
	-- bit32 folds any integer (incl. negative) into 0..2^32-1; floor handles
	-- float seeds so `Rng.new(s)` and `Rng.new(math.floor(s))` agree.
	local state = bit32.band(math.floor(seed), 0xFFFFFFFF)
	if state == 0 then
		state = ZERO_SEED_FALLBACK
	end
	-- Two warm-up rounds so neighboring integer seeds diverge before the
	-- first draw (a raw xorshift starts on a short correlated prefix).
	state = nextU32(state)
	state = nextU32(state)
	return fromState(state)
end

-- Uniform u32 (0..2^32-1) — the primitive every other method draws from.
function Rng.next(self: Rng): number
	self._state = nextU32(self._state)
	return self._state
end

-- Uniform integer in [a, b] inclusive. Errors on an inverted range rather
-- than returning something a call site would silently misread. The modulo
-- introduces a negligible bias for game-sized ranges (way below 2^32); the
-- pipeline only needs determinism, not perfect uniformity.
function Rng.int(self: Rng, a: number, b: number): number
	local lo = math.floor(a)
	local hi = math.floor(b)
	if lo > hi then
		error("Rng:int requires a <= b", 2)
	end
	local span = hi - lo + 1
	if span > 0x100000000 then
		error("Rng:int span must fit in 2^32", 2)
	end
	if span == 1 then
		return lo
	end
	return lo + self:next() % span
end

-- Fisher-Yates in descending order; mutates and returns the input list.
-- Draws int(1, i) for i = n..2, so a fresh `Rng.new(seed)` shuffling the same
-- list always produces the same permutation.
function Rng.shuffle<T>(self: Rng, list: { T }): { T }
	for i = #list, 2, -1 do
		local j = self:int(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Forks the stream: the copy continues exactly from here, and further draws
-- on `self` never affect it (per-bot RNGs will ride on this).
function Rng.clone(self: Rng): Rng
	return fromState(self._state)
end

export type Rng = typeof(setmetatable(
	{} :: {
		_state: number,
	},
	Rng
))

return Rng
