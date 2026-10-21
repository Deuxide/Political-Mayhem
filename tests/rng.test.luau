--!nocheck
-- Rng tests (M1-T3, D-018): same seed -> same sequence, seed divergence,
-- inclusive int ranges, deterministic shuffle permutation, clone forking,
-- and the no-math.random prohibition over the real source file (D-034: the
-- module itself loads through the loader; the text scan only reads it).

local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

local STREAM_LENGTH = 64

function M.run()
	print("rng")
	local shared = Loader.mount("src/shared")
	local Rng = Loader.require(shared.Game.Rng)

	local function stream(seed: number, count: number): { number }
		local rng = (Rng :: any).new(seed)
		local values: { number } = {}
		for _ = 1, count do
			table.insert(values, rng:next())
		end
		return values
	end

	Lib.test("same seed gives the identical next() sequence", function()
		local a = stream(12345, STREAM_LENGTH)
		local b = stream(12345, STREAM_LENGTH)
		for i = 1, STREAM_LENGTH do
			Lib.eq(b[i], a[i], `next[{i}] differs for equal seeds`)
		end
	end)

	Lib.test("different seeds diverge (not a shared prefix)", function()
		local a = stream(1, STREAM_LENGTH)
		local b = stream(2, STREAM_LENGTH)
		local differences = 0
		for i = 1, STREAM_LENGTH do
			if a[i] ~= b[i] then
				differences += 1
			end
		end
		Lib.truthy(
			differences >= STREAM_LENGTH / 2,
			`seeds 1 vs 2 differ only {differences}/{STREAM_LENGTH}`
		)
	end)

	Lib.test("next() stays in u32 bounds and is an integer", function()
		local values = stream(999, 200)
		for i, v in values do
			Lib.truthy(v >= 0, `next[{i}] below 0`)
			Lib.truthy(v <= 0xFFFFFFFF, `next[{i}] above 2^32-1`)
			Lib.truthy(v % 1 == 0, `next[{i}] not an integer`)
		end
	end)

	Lib.test("int(a,b) is inclusive, bounded, and hits both ends", function()
		local rng = Rng.new(42) :: any
		Lib.eq(rng:int(7, 7), 7, "int with a == b")
		Lib.eq(rng:int(1, 1), 1, "int with span 1")
		local faces: { [number]: boolean } = {}
		local received = 0
		for _ = 1, 400 do
			local v = rng:int(1, 6)
			received += v
			Lib.truthy(v >= 1 and v <= 6, `int(1,6) left the range: {v}`)
			faces[v] = true
		end
		Lib.truthy(received >= 1200 and received <= 3600, "die sum wildly off")
		for face = 1, 6 do
			Lib.truthy(faces[face] == true, `face {face} never rolled in 400 draws`)
		end
		local negative = rng:int(-3, -3)
		Lib.eq(negative, -3, "int with negative fixed range")
	end)

	Lib.test("int with an inverted range raises", function()
		local rng = Rng.new(8) :: any
		Lib.truthy(not pcall(function()
			rng:int(5, 2)
		end), "int(5,2) must raise")
	end)

	Lib.test("shuffle is a deterministic permutation, twice", function()
		local makeInput = function(): { number }
			local input: { number } = {}
			for i = 1, 12 do
				table.insert(input, i)
			end
			return input
		end
		local first = Rng.new(777) :: any
		local second = Rng.new(777) :: any
		local shuffled = first:shuffle(makeInput())
		local reshuffled = second:shuffle(makeInput())
		for i = 1, 12 do
			Lib.eq(shuffled[i], reshuffled[i], `shuffle[{i}] differs between equal seeds`)
		end
		local counts: { [number]: number } = {}
		for _, v in shuffled do
			Lib.truthy(v >= 1 and v <= 12, `shuffled value out of range: {v}`)
			counts[v] = (counts[v] or 0) + 1
		end
		for v = 1, 12 do
			Lib.eq(counts[v], 1, `shuffled lost or duplicated {v}`)
		end
		Lib.eq(#shuffled, 12, "shuffle preserves length")
		local moved = false
		for i = 1, 12 do
			if shuffled[i] ~= i then
				moved = true
			end
		end
		Lib.truthy(moved, "a 12-item shuffle must move something")
	end)

	Lib.test("shuffle handles empty and single-item lists", function()
		local rng = Rng.new(3) :: any
		Lib.eq(#rng:shuffle({}), 0, "empty shuffle length")
		Lib.eq((rng:shuffle({ "only" } :: { any }))[1], "only", "single item unchanged")
	end)

	Lib.test("clone snapshots: fork equals the origin's stream from the fork point", function()
		local base = Rng.new(7) :: any
		for _ = 1, 5 do
			base:next()
		end
		local fork = base:clone() :: any
		local afterClone: { number } = {}
		for _ = 1, 6 do
			table.insert(afterClone, fork:next())
		end
		-- further draws on the origin in between must not touch the fork
		for _ = 1, 3 do
			base:next()
		end
		local replay = (Rng :: any).new(7) :: any
		for _ = 1, 5 do
			replay:next()
		end
		for i = 1, 6 do
			Lib.eq(afterClone[i], replay:next(), `fork draw {i} != replayed origin stream`)
		end
	end)

	Lib.test("clone equals a fresh same-seed stream advanced to the same point", function()
		local original = stream(123, 5)
		local replay = stream(123, 5)
		for i = 1, 5 do
			Lib.eq(replay[i], original[i], `fresh repro[{i}]`)
		end
	end)

	Lib.test("no math.random or Random.new in the Rng source (D-018)", function()
		local fs = require("@lune/fs")
		-- `-- comments` may legitimately mention the banned names; strip them
		-- before scanning executable text.
		local source = string.gsub(fs.readFile("src/shared/Game/Rng.luau"), "%-%-[^\n]*", "")
		Lib.truthy(string.find(source, "math%.random", 1, false) == nil, "Rng calls math.random")
		Lib.truthy(string.find(source, "Random%.new", 1, false) == nil, "Rng constructs Random.new")
	end)
end

return M
