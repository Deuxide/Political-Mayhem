--!strict
-- Deterministic hash of plain state tables (sorted keys).

local Types = require(script.Parent.Parent.Types)

export type StateHash = {
	compute: (state: Types.MatchState) -> string,
	_hashValue: (value: any, depth: number?) -> string,
}

local StateHash = {}

local function hashString(s: string): string
	-- Simple FNV-1a hash
	local hash = 2166136261
	for i = 1, #s do
		hash = bit32.bxor(hash, string.byte(s, i))
		hash = (hash * 16777619) % 4294967296
	end
	return string.format("%08x", hash)
end

function StateHash._hashValue(value: any, depth: number?): string
	depth = depth or 0
	if depth > 50 then return "DEEP" end

	local t = type(value)
	if t == "nil" then
		return "N"
	elseif t == "boolean" then
		return value and "T" or "F"
	elseif t == "number" then
		if value ~= value then -- NaN
			return "NaN"
		elseif value == math.huge then
			return "Inf"
		elseif value == -math.huge then
			return "-Inf"
		else
			return string.format("%.17g", value)
		end
	elseif t == "string" then
		return "S:" .. hashString(value)
	elseif t == "table" then
		-- Collect and sort keys for deterministic ordering
		local keys = {}
		for k in pairs(value) do
			if type(k) == "string" or type(k) == "number" then table.insert(keys, k) end
		end
		table.sort(keys, function(a, b)
			local ta, tb = type(a), type(b)
			if ta ~= tb then return ta < tb end
			return tostring(a) < tostring(b)
		end)

		local parts = { "{" }
		for i, k in ipairs(keys) do
			local v = value[k]
			table.insert(
				parts,
				"["
					.. StateHash._hashValue(k, depth + 1)
					.. "]="
					.. StateHash._hashValue(v, depth + 1)
			)
			if i < #keys then table.insert(parts, ",") end
		end
		table.insert(parts, "}")
		return table.concat(parts)
	else
		return "UNKNOWN:" .. t
	end
end

function StateHash.compute(state: Types.MatchState): string return StateHash._hashValue(state) end

return StateHash
