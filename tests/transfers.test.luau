--!nocheck
-- Transfers tests (M4-T1; GAME_DESIGN 8.1): the primitive moves resources
-- from one class to another, refuses what the sender does not have, and
-- never moves half of a bag. Runs the real module on real factory states
-- via tests/loader.luau.

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
	print("transfers ops")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local StateHash = Loader.require(shared.Game.State.StateHash)
	local assertSerializable = Loader.require(shared.Game.State.assertSerializable)
	local Transfers = Loader.require(shared.Game.Ops.Transfers)

	local function fresh(): any
		return StateFactory.create("Normal", SEATS, 41)
	end

	Lib.test("a transfer moves the resources (8.1)", function()
		local state = fresh()
		local ok, reason = Transfers.execute(state, "Middle", "Working", { Money = 5 })
		Lib.eq(ok, true, "accepted: " .. tostring(reason))
		Lib.eq(state.classes.Middle.money, 20, "25 - 5")
		Lib.eq(state.classes.Working.money, 15, "10 + 5")
	end)

	Lib.test("a transfer moves stock as well (8.1)", function()
		local state = fresh()
		local ok = Transfers.execute(state, "Capitalist", "Working", { Goods = 2 })
		Lib.eq(ok, true, "accepted")
		Lib.eq(state.classes.Capitalist.stock.goods, 0, "2 goods given")
		Lib.eq(state.classes.Working.stock.goods, 2, "2 goods received")
	end)

	Lib.test("a transfer the sender cannot afford fails and moves nothing (8.1)", function()
		local state = fresh()
		local before = StateHash.compute(state)
		local ok, reason = Transfers.execute(state, "Middle", "Working", { Money = 99 })
		Lib.eq(ok, false, "refused")
		Lib.eq(reason, "Middle does not have 99 Money", "reason")
		Lib.eq(state.classes.Middle.money, 25, "money untouched")
		Lib.eq(state.classes.Working.money, 10, "money untouched")
		Lib.eq(StateHash.compute(state), before, "nothing moved at all")
	end)

	Lib.test("a transfer to itself is refused (8.1)", function()
		local state = fresh()
		local ok, reason = Transfers.execute(state, "Middle", "Middle", { Money = 5 })
		Lib.eq(ok, false, "refused")
		Lib.eq(reason, "a class cannot transfer to itself", "reason")
		Lib.eq(state.classes.Middle.money, 25, "money untouched")
	end)

	Lib.test("an amount that is not a whole number is refused (8.1)", function()
		local state = fresh()
		local ok, reason = Transfers.execute(state, "Middle", "Working", { Money = 2.5 })
		Lib.eq(ok, false, "refused")
		Lib.eq(reason, "the amount of Money must be a whole number", "reason")
		local negative = fresh()
		local ok2 = Transfers.execute(negative, "Middle", "Working", { Money = -5 })
		Lib.eq(ok2, false, "a negative amount is refused")
		Lib.eq(negative.classes.Middle.money, 25, "money untouched")
	end)

	Lib.test("a bag with nothing in it moves nothing and succeeds (8.1)", function()
		local state = fresh()
		local ok = Transfers.execute(state, "Middle", "Working", { Money = 0 })
		Lib.eq(ok, true, "accepted")
		Lib.eq(state.classes.Middle.money, 25, "money untouched")
	end)

	Lib.test("transferred states stay serializable and deterministic (no RNG used)", function()
		local function runOnce(): any
			local state = fresh()
			Transfers.execute(state, "Middle", "Working", { Money = 5, Food = 1 })
			return state
		end
		local a = runOnce()
		local b = runOnce()
		Lib.eq(#assertSerializable.validate(a), 0, "state serializable")
		Lib.eq(StateHash.compute(a), StateHash.compute(b), "same input -> same result")
		Lib.eq(a.classes.Working.money, 15, "same money")
		Lib.eq(a.classes.Working.stock.food, 5, "same food")
	end)
end

return M
