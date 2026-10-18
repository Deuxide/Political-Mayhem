--!strict
-- Test helper: asserts a value is serializable (plain data only).
-- Fails if it contains functions, metatables, Instances, cycles, or non-string/number keys.

export type SerializableChecker = {
	assertSerializable: (value: any, path: string?) -> (),
	_check: (value: any, path: string, seen: { [any]: boolean }) -> (),
}

local SerializableChecker = {}

function SerializableChecker.assertSerializable(value: any, path: string?)
	SerializableChecker._check(value, path or "root", {})
end

function SerializableChecker._check(value: any, path: string, seen: { [any]: boolean })
	local t = type(value)
	if t == "nil" or t == "boolean" or t == "number" or t == "string" then
		return
	elseif t == "table" then
		if seen[value] then error("Cycle detected at " .. path, 0) end
		seen[value] = true

		-- Check for metatable
		if getmetatable(value) then error("Metatable found at " .. path, 0) end

		for k, v in pairs(value) do
			local kt = type(k)
			if kt ~= "string" and kt ~= "number" then
				error("Non-string/number key (" .. kt .. ") at " .. path, 0)
			end
			SerializableChecker._check(v, path .. "." .. tostring(k), seen)
		end

		seen[value] = nil
	elseif t == "function" then
		error("Function found at " .. path, 0)
	elseif t == "thread" then
		error("Thread found at " .. path, 0)
	elseif t == "userdata" then
		-- Could be an Instance or other Roblox userdata
		error("Userdata (possible Instance) found at " .. path, 0)
	else
		error("Unknown type " .. t .. " at " .. path, 0)
	end
end

return SerializableChecker
