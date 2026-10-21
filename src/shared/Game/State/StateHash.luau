--!strict
-- Content hash over the canonical serialization of a state
-- (ARCHITECTURE 3.1: "hash = StateHash.compute(state), deterministic: sorted
-- keys"). Pure Luau: byte-fold arithmetic needs no bit32, and the fold keeps
-- every intermediate under 2^53 so doubles stay exact everywhere this code
-- runs (Lune host or Roblox server). Same content -> same hex string, always.

local StateHash = {}

-- Canonical serialization: every value becomes a self-delimiting token:
--   n<int>; n<%.17g>;   numbers (integers via the exact %d path)
--   b0; b1;             booleans
--   s<len>:<bytes>;     strings (length-prefixed: no escaping needed)
--   t<entry*>;          tables, entries sorted: keys ascending — numeric
--                       keys numerically, mixed keys by encoded form
--   entry               = encode(key) .. encode(value)
-- Because each token's extent is determined by its tag (lengths for strings,
-- single char for scalars, the closing `;` for tables), two different states
-- never produce the same token stream.
-- Absent map fields (nil values skipped) are not encoded, so nil-valued and
-- missing keys hash identically. Keys that are not strings or integers are
-- rejected — the serializable contract already guarantees they never appear.

local function isExactInteger(value: number): boolean
	-- 2^53 = 9007199254740992: doubles stay exact below it
	return value == math.floor(value) and math.abs(value) < 9007199254740992
end

local function encodeKey(key: any): string
	local kind = type(key)
	if kind == "number" then
		if not isExactInteger(key) then
			error("StateHash: non-integer numeric key", 0)
		end
		return `i{string.format("%d", key)};`
	elseif kind == "string" then
		return `s{#key}:{key};`
	end
	error(`StateHash: invalid key of type {kind}`, 0)
end

local function encode(value: any): string
	local kind = type(value)
	if kind == "number" then
		if isExactInteger(value) then
			return `n{string.format("%d", value)};`
		end
		return `n{string.format("%.17g", value)};`
	elseif kind == "boolean" then
		return value and `b1;` or `b0;`
	elseif kind == "string" then
		return `s{#value}:{value};`
	elseif kind == "table" then
		local keys: { any } = {}
		for key in value do
			table.insert(keys, key)
		end
		-- sorted order makes the stream independent of insertion order
		table.sort(keys, function(a: any, b: any): boolean
			local ka, kb = type(a), type(b)
			if ka == "number" and kb == "number" then
				return a < b
			end
			if ka ~= kb then
				-- numbers sort before strings (never occurs in valid state,
				-- but the order must still be canonical)
				return ka == "number"
			end
			return encodeKey(a) < encodeKey(b)
		end)
		local out: { string } = {}
		for _, key in keys do
			table.insert(out, encodeKey(key) .. encode(value[key]))
		end
		return `t{table.concat(out)};`
	end
	-- functions, threads, Instances: rejected by the serializable contract
	-- before anything reaches here; fail loudly rather than encode junk
	error(`StateHash: cannot encode value of type {kind}`, 0)
end

-- The canonical serialization itself — useful for exact-content tests and
-- debug output (Network documents per-Day hashes alongside the match seed).
function StateHash.serialize(value: any): string
	return encode(value)
end

function StateHash.compute(value: any): string
	local stream = encode(value)
	-- classic text-finger fold: h = h*131 + byte (mod 2^32)
	local hash = 0
	for index = 1, #stream do
		hash = (hash * 131 + string.byte(stream, index)) % 4294967296
	end
	return string.format("%08x", hash)
end

return table.freeze(StateHash)
