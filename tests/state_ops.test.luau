--!nocheck
-- StateOps tests (M1-T5): safe resource math (boolean insufficiency, never
-- negative, loud programming errors), CLASS_ORDER, deepCopy isolation,
-- canonical serialization + deterministic hashing, and Match:snapshot/hash.

local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

local SEATS: { [string]: { string } } = {
	Working = { "Seat-Working" },
	Middle = { "Seat-Middle" },
	Capitalist = { "Seat-Capitalist" },
	State = { "Seat-State" },
}

-- structural equality for arbitrary plain data (order-independent)
local function deepEqual(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil and b[key] ~= nil then
			return false
		end
	end
	return true
end

local function countKeys(t: { any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function expectList(actual: { any }, expected: { string }, label: string)
	for i, item in expected do
		Lib.eq(actual[i], item, `{label}[{i}]`)
	end
	Lib.eq(#actual, #expected, `{label} length`)
end

-- two orders of the same small map, built explicitly so insertion order is
-- the only difference between them
local function ordA(): { [string]: number }
	local t = {}
	t.a = 1
	t.b = 2
	return t
end

local function ordB(): { [string]: number }
	local t = {}
	t.b = 2
	t.a = 1
	return t
end

function M.run()
	print("state ops")
	local shared = Loader.mount("src/shared")
	local Types = Loader.require(shared.Game.Types)
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateOps = Loader.require(shared.Game.State.StateOps)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local assertSerializable = Loader.require(shared.Game.State.assertSerializable)

	local problems = function(state: any): number
		return countKeys(assertSerializable.validate(state))
	end

	Lib.test("CLASS_ORDER is the fixed class order (GAME_DESIGN 10)", function()
		expectList(
			StateOps.CLASS_ORDER,
			{ "Working", "Middle", "Capitalist", "State" },
			"CLASS_ORDER"
		)
		for i, id in Types.CLASS_IDS do
			Lib.eq(StateOps.CLASS_ORDER[i], id, `CLASS_ORDER[{i}] mirrors CLASS_IDS`)
		end
	end)

	Lib.test("addResource routes money, influence, and stock ids", function()
		local state = StateFactory.create("Normal", SEATS, 1) :: any
		Lib.truthy(
			StateOps.addResource(state, "Working", "Money", 5) == true,
			"add money returns true"
		)
		Lib.eq(state.classes.Working.money, 15, "money 10 + 5")
		Lib.truthy(
			StateOps.addResource(state, "State", "Influence", 2) == true,
			"add influence returns true"
		)
		Lib.eq(state.classes.State.influence, 4, "influence 2 + 2")
		Lib.truthy(
			StateOps.addResource(state, "Middle", "Food", 3) == true,
			"add stock via Food id"
		)
		Lib.eq(state.classes.Middle.stock.food, 5, "food 2 + 3")
		Lib.truthy(
			StateOps.addResource(state, "Capitalist", "Education", 1) == true,
			"add stock via Education id"
		)
		Lib.eq(state.classes.Capitalist.stock.education, 4, "education 3 + 1")
		Lib.truthy(
			StateOps.addResource(state, "Working", "Money", 0) == true,
			"zero amount is a no-op"
		)
		Lib.eq(state.classes.Working.money, 15, "money unchanged after zero add")
	end)

	Lib.test("negative or non-finite amounts raise", function()
		local state = StateFactory.create("Normal", SEATS, 1) :: any
		Lib.truthy(not pcall(function()
			StateOps.addResource(state, "Working", "Money", -1)
		end), "negative add must raise")
		Lib.truthy(not pcall(function()
			StateOps.subtractResource(state, "Working", "Money", -3)
		end), "negative subtract must raise")
		local NAN = 0 / 0
		Lib.truthy(not pcall(function()
			StateOps.addResource(state, "Working", "Money", NAN)
		end), "NaN amount must raise")
		Lib.truthy(not pcall(function()
			StateOps.addResource(state, "Working", "Money", math.huge)
		end), "infinite amount must raise")
		Lib.eq(state.classes.Working.money, 10, "money untouched after rejected adds")
	end)

	Lib.test("subtractResource pays exactly, and refuses without going negative", function()
		local state = StateFactory.create("Normal", SEATS, 1) :: any
		Lib.truthy(
			StateOps.subtractResource(state, "Working", "Money", 10) == true,
			"exact balance pays"
		)
		Lib.eq(state.classes.Working.money, 0, "money down to 0")
		Lib.truthy(
			StateOps.subtractResource(state, "Working", "Goods", 1) == false,
			"insufficient stock refuses"
		)
		Lib.eq(state.classes.Working.stock.goods, 0, "stock unchanged after refusal")
		Lib.truthy(
			StateOps.subtractResource(state, "State", "Money", 80) == false,
			"insufficient money refuses"
		)
		Lib.eq(state.classes.State.money, 30, "money unchanged after refusal")
		Lib.truthy(
			StateOps.subtractResource(state, "Working", "Money", 0) == true,
			"zero subtract is a no-op"
		)
	end)

	Lib.test("unknown class, unknown resource, or missing stock key raises", function()
		local state = StateFactory.create("Normal", SEATS, 1) :: any
		Lib.truthy(not pcall(function()
			StateOps.addResource(state, "Anarchists" :: any, "Money", 1)
		end), "unknown class must raise")
		Lib.truthy(not pcall(function()
			StateOps.addResource(state, "Working", "Gold" :: any, 1)
		end), "unknown resource must raise")
		-- a malformed state (corrupted stock table) surfaces as a loud error
		local broken = { classes = { Working = { stock = {} } } }
		Lib.truthy(not pcall(function()
			StateOps.addResource(broken :: any, "Working", "Food", 1)
		end), "missing stock key must raise")
		Lib.eq(StateOps.resourceValue(state, "Working", "Money"), 10, "resourceValue reads money")
		Lib.eq(StateOps.resourceValue(state, "Middle", "Goods"), 1, "resourceValue reads stock")
	end)

	Lib.test("deepCopy is deep-equal and mutation-isolated at every level", function()
		local state = StateFactory.create("Normal", SEATS, 1) :: any
		local copy = StateOps.deepCopy(state) :: any
		Lib.truthy(
			deepEqual(copy, state) and deepEqual(state, copy),
			"copy deep-equals the original"
		)
		Lib.truthy(problems(copy) == 0, "copy is serializable")

		copy.classes.Working.money = 999
		copy.classes.Capitalist.stock.education = 999
		copy.classes.Working.seats[1] = "Seat-Copied"
		Lib.eq(state.classes.Working.money, 10, "top-level field isolation")
		Lib.eq(state.classes.Capitalist.stock.education, 3, "nested stock isolation")
		Lib.eq(state.classes.Working.seats[1], "Seat-Working", "array element isolation")
	end)

	Lib.test("serialize is canonical: order-independent, key-typed, unambiguous", function()
		Lib.eq(
			StateHash.serialize(ordA()),
			StateHash.serialize(ordB()),
			"insertion order must not change the stream"
		)
		-- integer keys vs equal-looking string keys must differ
		Lib.truthy(
			StateHash.serialize({ [1] = true }) ~= StateHash.serialize({ ["1"] = true }),
			"i1 vs s1 keys are distinguishable"
		)
		-- nested structure encodes recursively
		Lib.truthy(
			StateHash.serialize({ inner = { x = 1 }, list = { 1, 2 } })
				~= StateHash.serialize({ inner = { x = 2 }, list = { 1, 2 } }),
			"nested difference shows in the stream"
		)
		-- numbers: whole-number floats and integers encode identically (same value)
		Lib.eq(
			StateHash.serialize({ v = 5 }),
			StateHash.serialize({ v = 5.0 }),
			"5 == 5.0 encodes equal"
		)
		Lib.truthy(
			StateHash.serialize({ v = 0.5 }) ~= StateHash.serialize({ v = 1 }),
			"fractional path differs from integers"
		)
		-- empty table and booleans
		Lib.eq(StateHash.serialize({}), "t;", "empty table encodes as t;")
		Lib.eq(StateHash.serialize(true), "b1;", "true encodes")
	end)

	Lib.test("compute is stable across copies and sensitive to content", function()
		local state = StateFactory.create("Hard", SEATS, 7) :: any
		local hash1 = StateHash.compute(state)
		Lib.eq(hash1, StateHash.compute(state), "same state hashes twice identically")
		Lib.eq(hash1, StateHash.compute(StateOps.deepCopy(state)), "deep copy hashes identically")

		local mutated = StateOps.deepCopy(state) :: any
		mutated.classes.Working.money += 1
		Lib.truthy(StateHash.compute(mutated) ~= hash1, "money change changes the hash")
		mutated = StateOps.deepCopy(state) :: any
		mutated.lines["Farm-1"].assigned = 3
		Lib.truthy(StateHash.compute(mutated) ~= hash1, "line assignment change changes the hash")
		mutated = StateOps.deepCopy(state) :: any
		mutated.policies.Wage = 3
		Lib.truthy(StateHash.compute(mutated) ~= hash1, "policy level change changes the hash")
	end)

	Lib.test("Match:snapshot and Match:hash expose the state content", function()
		local Match = Loader.require(shared.Game.Match)
		local RuleSetClass = Loader.require(shared.Game.RuleSet)
		local RngClass = Loader.require(shared.Game.Rng)
		local state = StateFactory.create("Normal", SEATS, 11) :: any
		local match = Match.new(state, RuleSetClass.new("Normal"), RngClass.new(11)) :: any

		local snapshot = match:snapshot() :: any
		Lib.truthy(
			deepEqual(snapshot, state) and deepEqual(state, snapshot),
			"snapshot deep-equals live state"
		)
		Lib.eq(match:hash(), StateHash.compute(state), "Match:hash equals StateHash.compute(state)")
		Lib.eq(match:hash(), StateHash.compute(match:snapshot()), "snapshot hashes identically")

		snapshot.classes.Middle.money = 12345
		Lib.eq(state.classes.Middle.money, 25, "mutating the snapshot leaves the live state intact")
		Lib.eq(match:hash(), StateHash.compute(state), "live hash unchanged after snapshot edits")
	end)

	Lib.test("initial states for every difficulty pass assertSerializable as copies", function()
		for _, difficulty in Types.DIFFICULTIES do
			local state = StateFactory.create(difficulty, SEATS, 42) :: any
			local copy = StateOps.deepCopy(state) :: any
			Lib.truthy(problems(copy) == 0, `{difficulty}: deep copy has no serialization problems`)
			Lib.eq(
				StateHash.compute(copy),
				StateHash.compute(state),
				`{difficulty}: copy has an identical hash`
			)
		end
	end)
end

return M
