--!nocheck
-- Serialization checks (M1-T0): the REAL State.assertSerializable module
-- accepts plain state and rejects functions, metatables, peers-of-non-primitive
-- kinds, cycles, and bad keys (D-034: no pasted copies).

local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

function M.run()
	print("serialization")
	local shared = Loader.mount("src/shared")
	local assertSerializable = Loader.require(shared.Game.State.assertSerializable)

	Lib.test("accepts plain numbers, strings, booleans, arrays", function()
		assertSerializable.assert({
			money = 10,
			name = "Working",
			flag = false,
			stock = { food = 4, goods = 0 },
			list = { 1, 2, 3 },
		})
	end)

	Lib.test("accepts deep integer-keyed nesting", function()
		assertSerializable.assert({ log = { { day = 1, text = "ok" }, { day = 2 } } })
	end)

	Lib.test("rejects a function value", function()
		local ok, err = pcall(assertSerializable.assert, { bad = function() end })
		Lib.truthy(not ok, "functions must be rejected")
		Lib.contains(tostring(err), "function")
	end)

	Lib.test("rejects a table with a metatable", function()
		local table = setmetatable({}, {})
		local ok, err = pcall(assertSerializable.assert, { wrapped = table })
		Lib.truthy(not ok, "metatable tables must be rejected")
		Lib.contains(tostring(err), "metatable")
	end)

	Lib.test("rejects a cycle", function()
		local node = {}
		node.self = node
		local ok, err = pcall(assertSerializable.assert, node)
		Lib.truthy(not ok, "cycles must be rejected")
		Lib.contains(tostring(err), "repeat of <root>")
	end)

	Lib.test("rejects a shared table reference (repeat, even acyclic)", function()
		local shared = { food = 1 }
		local ok, err = pcall(assertSerializable.assert, { first = shared, second = shared })
		Lib.truthy(not ok, "shared references must be rejected")
		Lib.contains(tostring(err), "repeat of")
	end)

	Lib.test("rejects a non-integer table key", function()
		local ok, err = pcall(assertSerializable.assert, { [1.5] = "bad" })
		Lib.truthy(not ok, "fractional keys must be rejected")
		Lib.contains(tostring(err), "non-string or non-integer key")
	end)

	Lib.test("rejects a non-primitive kind userdata/vector", function()
		local vector = vector.create(1, 2, 3)
		local ok, err = pcall(assertSerializable.assert, { anchor = vector })
		Lib.truthy(not ok, "userdata must be rejected (Instances are userdata too)")
		Lib.contains(tostring(err), "vector")
	end)

	Lib.test("rejects non-finite numbers", function()
		local ok, err = pcall(assertSerializable.assert, { broken = math.huge })
		Lib.truthy(not ok, "infinities must be rejected")
		Lib.contains(tostring(err), "non-finite")
		local ok2, err2 = pcall(assertSerializable.assert, { broken = 0 / 0 })
		Lib.truthy(not ok2, "NaN must be rejected")
		Lib.contains(tostring(err2), "non-finite")
	end)

	Lib.test("validate stays pure: returns problems instead of throwing", function()
		Lib.eq(#assertSerializable.validate({}), 0)
		local problems = assertSerializable.validate({ bad = function() end })
		Lib.eq(#problems, 1)
	end)
end

return M
