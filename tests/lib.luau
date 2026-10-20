--!nocheck
-- Minimal test helpers shared by every test module.
local Lib = {}

local passed, failed = 0, 0

function Lib.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ✓ " .. name)
	else
		failed += 1
		print("  ✗ " .. name .. "\n      " .. tostring(err))
	end
end

function Lib.eq(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(
			`{message or "values differ"}: expected {tostring(expected)}, got {tostring(actual)}`,
			2
		)
	end
end

function Lib.truthy(value: any, message: string?)
	if not value then error(message or "expected a truthy value", 2) end
end

function Lib.contains(haystack: string, needle: string, message: string?)
	if string.find(haystack, needle, 1, true) == nil then
		error(`{message or "missing text"}: '{needle}' not found in '{haystack}'`, 2)
	end
end

function Lib.failures(): number return failed end

function Lib.summary(): number
	print(`\nResults: {passed} passed, {failed} failed`)
	return failed
end

return Lib
