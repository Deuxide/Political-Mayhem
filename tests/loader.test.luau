--!nocheck
local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

function M.run()
	print("loader")
	local root = Loader.mount("tests/fixtures/virtual")

	Lib.test(
		"resolves Roblox-style requires (script.Parent.X)",
		function() Lib.eq(Loader.require(root.Types).answer, 42) end
	)

	Lib.test("folders with init.luau act as modules and expose children", function()
		local Sub = Loader.require(root.Sub)
		Lib.eq(Sub.value, 42)
		Lib.eq(Sub.child.double, 84)
	end)

	Lib.test(
		"modules are cached (same table on second require)",
		function() Lib.truthy(Loader.require(root.Types) == Loader.require(root.Types)) end
	)

	Lib.test("a wrong path fails loudly, like Studio does", function()
		local ok, err = pcall(function() return root.Missing end)
		Lib.eq(ok, false)
		Lib.contains(tostring(err), "not a valid member")
	end)
end

return M
