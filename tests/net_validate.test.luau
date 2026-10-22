--!nocheck
-- The validation toolkit of NETWORKING section 7 (M6-T1): every helper
-- rejects instead of coercing, and clampDraft turns an untrusted draft into a
-- safe one without touching what the client sent.
--
-- Runs the real module through tests/loader.luau.

local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

local SEATS: { [string]: { string } } = {
	Working = { "Seat-Working" },
	Middle = { "Seat-Middle" },
	Capitalist = { "Seat-Capitalist" },
	State = { "Seat-State" },
}

function M.run()
	print("net validate")
	local shared = Loader.mount("src/shared")
	local Types = Loader.require(shared.Game.Types)
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local Validate = Loader.require(shared.Net.Validate)

	local state = StateFactory.create("Normal", SEATS, 41)

	Lib.test("isClassId accepts the four classes and nothing else", function()
		for _, classId in Types.CLASS_IDS do
			Lib.truthy(Validate.isClassId(classId), classId)
		end
		Lib.eq(Validate.isClassId("Working "), false, "trailing space")
		Lib.eq(Validate.isClassId("Banker"), false, "unknown class")
		Lib.eq(Validate.isClassId(1), false, "not a string")
		Lib.eq(Validate.isClassId(nil), false, "nil")
	end)

	Lib.test("isRole accepts the four roles and nothing else", function()
		for _, role in Types.ROLES do
			Lib.truthy(Validate.isRole(role), role)
		end
		Lib.eq(Validate.isRole("Economics"), false, "unknown role")
		Lib.eq(Validate.isRole(true), false, "not a string")
	end)

	Lib.test("isPolicyId accepts the policy tracks and nothing else", function()
		for _, policyId in Types.POLICY_IDS do
			Lib.truthy(Validate.isPolicyId(policyId), policyId)
		end
		Lib.eq(Validate.isPolicyId("Wages"), false, "unknown policy")
		Lib.eq(Validate.isPolicyId(7), false, "not a string")
	end)

	Lib.test("isLineId knows the lines of this match", function()
		Lib.truthy(Validate.isLineId(state, "Farm-1"), "an existing line")
		Lib.eq(Validate.isLineId(state, "Farm-99"), false, "unknown line")
		Lib.eq(Validate.isLineId(state, 12), false, "not a string")
	end)

	Lib.test("isNonNegInt rejects NaN, infinity, negatives and fractions", function()
		Lib.truthy(Validate.isNonNegInt(0, 10), "zero")
		Lib.truthy(Validate.isNonNegInt(10, 10), "the maximum")
		Lib.eq(Validate.isNonNegInt(11, 10), false, "over the maximum")
		Lib.eq(Validate.isNonNegInt(-1, 10), false, "negative")
		Lib.eq(Validate.isNonNegInt(1.5, 10), false, "fraction")
		Lib.eq(Validate.isNonNegInt(0 / 0, 10), false, "NaN")
		Lib.eq(Validate.isNonNegInt(math.huge, 10), false, "infinity")
		Lib.eq(Validate.isNonNegInt("5", 10), false, "not a number")
		Lib.eq(Validate.isNonNegInt(nil, 10), false, "nil")
	end)

	Lib.test("isResourceBag accepts only real resources in whole amounts", function()
		Lib.truthy(Validate.isResourceBag({}), "an empty bag")
		Lib.truthy(Validate.isResourceBag({ Money = 5, Food = 2 }), "a normal bag")
		Lib.eq(Validate.isResourceBag({ Gold = 1 }), false, "unknown resource")
		Lib.eq(Validate.isResourceBag({ Money = -1 }), false, "negative")
		Lib.eq(Validate.isResourceBag({ Money = 1.5 }), false, "fraction")
		Lib.eq(Validate.isResourceBag({ Money = 0 / 0 }), false, "NaN")
		Lib.eq(Validate.isResourceBag("Money"), false, "not a table")
	end)

	Lib.test("isShortString bounds the length and the type", function()
		Lib.truthy(Validate.isShortString("hello", 5), "exactly the maximum")
		Lib.eq(Validate.isShortString("hello!", 5), false, "one over")
		Lib.eq(Validate.isShortString(5, 5), false, "not a string")
	end)

	Lib.test("isBoundedTable refuses oversized payloads", function()
		Lib.truthy(Validate.isBoundedTable({ a = 1, b = { c = 2 } }, 10, 4), "a small table")
		Lib.eq(
			Validate.isBoundedTable({ a = { b = { c = { d = { e = 1 } } } } }, 10, 4),
			false,
			"too deep"
		)
		Lib.eq(Validate.isBoundedTable({ a = 1, b = 2, c = 3 }, 2, 4), false, "too many entries")
		Lib.eq(Validate.isBoundedTable({ a = print }, 10, 4), false, "a function cannot travel")
	end)

	Lib.test("isDraftShape accepts a whole draft and rejects extra keys", function()
		local draft = {
			sequence = 3,
			locked = false,
			openSlots = { ["Farm-1"] = 2 },
			assign = { ["Farm-1"] = 1 },
			strike = { target = "Middle" },
			build = { lineType = "Farm" },
			lobby = { amount = 4 },
			market = { sell = { food = 1 }, buy = { goods = 2 } },
			votes = { ["Bill-1"] = { side = "yes", influence = 2 } },
		}
		Lib.truthy(Validate.isDraftShape(draft), "the full draft")

		local extra = {}
		for key, value in draft do
			extra[key] = value
		end
		extra.sneaky = 1
		Lib.eq(Validate.isDraftShape(extra), false, "an unknown key is rejected")

		Lib.eq(Validate.isDraftShape({}), false, "a draft without the required fields")
		Lib.eq(
			Validate.isDraftShape({
				sequence = 1,
				locked = false,
				openSlots = {},
				assign = {},
				market = { sell = {}, buy = {} },
				votes = {},
			}),
			true,
			"a draft with the lock flag"
		)
		Lib.eq(
			Validate.isDraftShape({
				sequence = 1.5,
				openSlots = {},
				assign = {},
				market = { sell = {}, buy = {} },
				votes = {},
			}),
			false,
			"a fractional sequence"
		)
		Lib.eq(
			Validate.isDraftShape({
				sequence = 1,
				locked = false,
				openSlots = {},
				assign = {},
				market = { sell = {}, buy = {} },
				votes = {},
				build = { lineType = "Spaceship" },
			}),
			false,
			"an unknown line type"
		)
	end)

	Lib.test("clampDraft keeps a valid draft and never mutates the input", function()
		local draft = {
			sequence = 4,
			locked = false,
			openSlots = { ["Farm-1"] = 2 },
			assign = { ["Farm-1"] = 1 },
			strike = nil,
			build = { lineType = "Clinic" },
			lobby = { amount = 3 },
			market = { sell = { food = 2 }, buy = { goods = 1 } },
			votes = {},
		}
		local safe = Validate.clampDraft(draft, state)

		Lib.eq(safe.sequence, 4, "the sequence is kept")
		Lib.eq(safe.openSlots["Farm-1"], 2, "the open slots are kept")
		Lib.eq(safe.assign["Farm-1"], 1, "the assignment is kept")
		Lib.eq(safe.build.lineType, "Clinic", "the build is kept")
		Lib.eq(safe.lobby.amount, 3, "the lobby is kept")
		Lib.eq(safe.market.sell.food, 2, "the sale is kept")
		Lib.eq(safe.market.buy.goods, 1, "the buy is kept")

		-- the input is untouched and the output is a separate table
		Lib.eq(draft.sequence, 4, "the input still holds its own values")
		safe.openSlots["Farm-1"] = 99
		Lib.eq(draft.openSlots["Farm-1"], 2, "the input is not the output")
	end)

	Lib.test("clampDraft drops what the state does not know", function()
		local safe = Validate.clampDraft({
			sequence = 1,
			locked = false,
			openSlots = { ["Farm-1"] = 1, ["Nope-9"] = 1 },
			assign = { ["Nope-9"] = 3 },
			strike = { target = "Banker" },
			build = { lineType = "Spaceship" },
			lobby = { amount = "lots" },
			market = { sell = { food = 1, unobtainium = 2 }, buy = {} },
			votes = { ["Bill-42"] = { side = "yes", influence = 3 } },
		}, state)

		Lib.eq(safe.openSlots["Farm-1"], 1, "a known line is kept")
		Lib.eq(safe.openSlots["Nope-9"], nil, "an unknown line is dropped")
		Lib.eq(safe.assign["Nope-9"], nil, "an unknown assignment is dropped")
		Lib.eq(safe.strike, nil, "an invalid strike target is dropped")
		Lib.eq(safe.build, nil, "an unknown line type is dropped")
		Lib.eq(safe.lobby, nil, "a malformed lobby is dropped")
		Lib.eq(safe.market.sell.food, 1, "a real resource is kept")
		Lib.eq(safe.market.sell.unobtainium, nil, "an unknown resource is dropped")
		Lib.eq(safe.votes["Bill-42"], nil, "a vote for an unknown bill is dropped")
	end)

	Lib.test("clampDraft caps the values to what the game allows", function()
		local safe = Validate.clampDraft({
			sequence = 1,
			locked = false,
			openSlots = { ["Farm-1"] = 99 },
			assign = { ["Farm-1"] = 999 },
			market = { sell = { food = 99 }, buy = {} },
			votes = {},
		}, state)

		Lib.eq(safe.openSlots["Farm-1"], 2, "open slots are capped at the line's slotsMax")
		Lib.eq(
			safe.assign["Farm-1"],
			state.classes.Working.workers,
			"assignments are capped by the worker pool"
		)
		Lib.eq(safe.market.sell.food, 6, "a market volume is capped at the market volume cap")
	end)

	Lib.test("clampDraft of rubbish is an empty safe draft", function()
		local safe = Validate.clampDraft("not a draft", state)
		Lib.eq(safe.sequence, 0, "sequence")
		Lib.eq(next(safe.openSlots), nil, "no open slots")
		Lib.eq(next(safe.assign), nil, "no assignments")
		Lib.eq(safe.strike, nil, "no strike")
		Lib.eq(safe.build, nil, "no build")
		Lib.eq(safe.lobby, nil, "no lobby")
		Lib.eq(next(safe.market.sell), nil, "no sale")
		Lib.eq(next(safe.votes), nil, "no votes")
	end)
end

return M
