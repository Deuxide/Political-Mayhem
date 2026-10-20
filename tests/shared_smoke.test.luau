--!nocheck
-- Real-module smoke test (D-014): loads the REAL src/shared/Game/Types.luau
-- through the loader and asserts what it exports. No pasted copies (D-034);
-- the pasted-copies guard in scripts/check backs that up.
local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

function M.run()
	print("shared smoke")
	local shared = Loader.mount("src/shared")
	local Types = Loader.require(shared.Game.Types)

	Lib.test("the loader ran the real Types module (a frozen table)", function()
		Lib.truthy(type(Types) == "table", "Types should be a table")
		Lib.eq(
			pcall(function()
				Types.new = function() end
			end),
			false,
			"Types should be frozen"
		)
	end)

	-- One exact assertion per exported enum, in canonical order (GAME_DESIGN 2
	-- and 3.1; D-008 defines the resource list). Order is part of the contract:
	-- M1 will iterate CLASS_IDS as the fixed CLASS_ORDER.
	local EXPECTED = {
		CLASS_IDS = "Working,Middle,Capitalist,State",
		RESOURCE_IDS = "Money,Influence,Food,Goods,Health,Education",
		PHASES = "Window,Resolve,Reveal",
		DIFFICULTIES = "Easy,Normal,Hard,Extreme",
	}

	for field, expected in EXPECTED do
		Lib.test(`Types.{field} mirrors the enum values in canonical order`, function()
			Lib.truthy(Types[field] ~= nil, `Types.{field} should be exported`)
			Lib.eq(table.concat(Types[field], ","), expected)
		end)
	end

	Lib.test("the enum mirrors are frozen too", function()
		Lib.eq(
			pcall(function()
				Types.CLASS_IDS[1] = "Middle"
			end),
			false,
			"enum mirrors should be read-only"
		)
	end)
end

return M
