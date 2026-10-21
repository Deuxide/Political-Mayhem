--!nocheck
-- Code-model foundation checks (M1-T0): the example behavior family, the
-- abstract-method helper, and the Signal class run as the REAL src files
-- through the loader (D-014); nothing is pasted (D-034).

local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

function M.run()
	print("code model")
	local shared = Loader.mount("src/shared")
	local Signal = Loader.require(shared.Game.Signal)
	local ExampleRule = Loader.require(shared.Game.Examples.ExampleRule)
	local ExampleDoubler = Loader.require(shared.Game.Examples.ExampleDoubler)

	Lib.test("behavior subclass: config field is private state, hook runs", function()
		local doubler = ExampleDoubler.new(21)
		Lib.eq(doubler:apply(2), 42)
		Lib.eq(doubler:apply(-3), -63)
	end)

	Lib.test("abstract base method raises with the documented wording", function()
		local base = ExampleRule.new("base")
		local ok, err = pcall(function()
			base:apply(7)
		end)
		Lib.truthy(not ok, "ExampleRule:apply must raise on the base")
		Lib.contains(tostring(err), "not implemented: ExampleRule:apply")
	end)

	Lib.test("Signal fires handlers in connect order", function()
		local hit: { string } = {}
		local signal = Signal.new()
		signal:connect(function(a: string, b: number)
			table.insert(hit, `first:{a}:{b}`)
		end)
		signal:connect(function()
			table.insert(hit, "second")
		end)
		signal:fire("x", 5)
		Lib.eq(hit[1], "first:x:5")
		Lib.eq(hit[2], "second")
		Lib.truthy(#hit == 2, "each handler fires once")
	end)

	Lib.test("Signal disconnect removes only its own handler (no shifts)", function()
		local hit: { string } = {}
		local signal = Signal.new()
		signal:connect(function()
			table.insert(hit, "first")
		end)
		local disconnectMid = signal:connect(function()
			table.insert(hit, "middle")
		end)
		signal:connect(function()
			table.insert(hit, "last")
		end)
		disconnectMid()
		signal:fire()
		Lib.eq(#hit, 2, "exactly the two still-connected handlers fired")
		Lib.eq(hit[1], "first")
		Lib.eq(hit[2], "last")
		-- disconnect closures are one-shot: firing again must not reuse them
		signal:fire()
		Lib.eq(#hit, 4)
	end)

	Lib.test("Signal fires every live handler across disconnect cycles", function()
		local signal = Signal.new()
		local fired = 0
		local disconnects: { () -> () } = {}
		for i = 1, 10 do
			table.insert(
				disconnects,
				signal:connect(function()
					fired += 1
				end)
			)
		end
		signal:fire() -- every handler fires once: 10
		Lib.eq(fired, 10)
		for i = 2, 10, 2 do
			disconnects[i]() -- remove ids 2,4,6,8,10
		end
		signal:fire() -- ids 1,3,5,7,9 remain mid-list: 10 + 5
		Lib.eq(fired, 15, "mid-list disconnects must not shift or drop other handlers")
	end)
end

return M
