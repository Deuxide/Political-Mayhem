--!nocheck
-- The client store of M7-T1 (UI_SPEC section 7): the reducers are pure, so
-- they are tested without Roblox. The snapshot replaces the view, the patches
-- change what they name, and the local draft is pending until the server
-- echoes it.

local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

function M.run()
	print("client store")
	local root = Loader.mount("src")
	local Store = Loader.require(root.client.State.Store)
	local Types = Loader.require(root.shared.Game.Types)

	local function view()
		return {
			viewer = "Middle",
			day = 1,
			rounds = 12,
			phase = "Window",
			stability = 60,
			policies = { Wage = 2 },
			own = {
				id = "Middle",
				money = 25,
				influence = 2,
				stock = {},
				vp = 0,
				workers = 0,
				seats = {},
			},
			ownLines = {},
			needs = { food = 2, goods = 1, health = 1, education = 1 },
			draft = {
				sequence = 4,
				locked = false,
				openSlots = {},
				assign = {},
				market = { sell = {}, buy = {} },
				votes = {},
			},
			others = {},
			bills = {},
			promises = {},
			alliances = {},
			reputation = {},
			victory = nil,
		}
	end

	Lib.test("a fresh store starts empty", function()
		local state = Store.initialState()
		Lib.eq(state.connection.status, "connecting", "the status")
		Lib.eq(state.match.view, nil, "no view yet")
		Lib.eq(state.draft.seq, 0, "no draft yet")
		Lib.eq(state.draft.syncState, "clean", "nothing pending")
		Lib.eq(state.ui.activeTab, "economy", "the first tab")
		Lib.eq(#state.inbox.notices, 0, "no notices")
	end)

	Lib.test("a snapshot brings the view, the protocol and the server offset", function()
		local state = Store.initialState()
		local next = Store.applySnapshot(state, view(), 1, 1000, 900)

		Lib.eq(next.connection.status, "ready", "the status")
		Lib.eq(next.connection.protocol, 1, "the protocol")
		Lib.eq(next.match.view.viewer, "Middle", "the view")
		Lib.eq(next.match.serverOffset, 100, "the server offset")
		Lib.eq(next.draft.seq, 4, "the server's draft is the local one")
		Lib.eq(next.draft.syncState, "clean", "nothing pending")
		-- the old state is untouched
		Lib.eq(state.match.view, nil, "the old state did not change")
		Lib.eq(state.connection.status, "connecting", "the old status did not change")
	end)

	Lib.test("a phase change sets the phase, the Day and the end time", function()
		local state = Store.applySnapshot(Store.initialState(), view(), 1, 1000, 900)
		local next = Store.applyPhase(state, "Reveal", 2, 1200, 1100, 1000)
		Lib.eq(next.match.phase, "Reveal", "the phase")
		Lib.eq(next.match.day, 2, "the Day")
		Lib.eq(next.match.endsAt, 1200, "the end time")
		Lib.eq(state.match.phase, "Window", "the old state did not change")
	end)

	Lib.test("a patch sets the draft and appends the bills and the alliances", function()
		local state = Store.applySnapshot(Store.initialState(), view(), 1, 1000, 900)
		local draft = {
			sequence = 9,
			locked = false,
			openSlots = {},
			assign = {},
			market = { sell = {}, buy = {} },
			votes = {},
		}
		local next = Store.applyPatch(state, {
			{ op = "set", path = "draft", value = draft },
			{ op = "append", path = "bills", value = { id = "Bill-1" } },
			{ op = "append", path = "alliances", value = { id = "Alliance-1" } },
		})

		Lib.eq(next.draft.seq, 9, "the draft came back")
		Lib.eq(next.draft.syncState, "clean", "and it is in sync")
		Lib.eq(#next.inbox.bills, 1, "the bill arrived")
		Lib.eq(next.inbox.bills[1].id, "Bill-1", "the bill")
		Lib.eq(#next.match.view.bills, 1, "the live bill is in the view")
		Lib.eq(next.match.view.bills[1].id, "Bill-1", "the live bill")
		Lib.eq(#state.match.view.bills, 0, "the old view did not change")
		Lib.eq(#next.match.view.alliances, 1, "the alliance arrived")
		Lib.eq(#state.inbox.bills, 0, "the old state did not change")
	end)

	Lib.test("the active tab is a local choice", function()
		local state = Store.applySnapshot(Store.initialState(), view(), 1, 1000, 900)
		local next = Store.applyActiveTab(state, "politics")
		Lib.eq(next.ui.activeTab, "politics", "the new tab")
		Lib.eq(state.ui.activeTab, "economy", "the old state did not change")
	end)

	Lib.test("a local draft is pending until the server echoes it", function()
		local state = Store.initialState()
		local draft = {
			sequence = 5,
			locked = false,
			openSlots = {},
			assign = {},
			market = { sell = {}, buy = {} },
			votes = {},
		}
		local pending = Store.setLocalDraft(state, draft, 5)
		Lib.eq(pending.draft.syncState, "pending", "pending")
		Lib.eq(pending.draft.seq, 5, "the sequence")

		-- a refusal drops the local copy and shows the server's
		local withView = Store.applySnapshot(state, view(), 1, 1000, 900)
		local rejected = Store.rejectDraft(withView)
		Lib.eq(rejected.draft.syncState, "rejected", "rejected")
		Lib.eq(rejected.draft.seq, 4, "the server's sequence is back")
	end)

	Lib.test("the economy reducers edit one field and bump the sequence", function()
		local state = Store.applySnapshot(Store.initialState(), view(), 1, 1000, 900)
		local slots = Store.setOpenSlots(state, "Farm-1", 1)
		Lib.eq(slots.draft.current.openSlots["Farm-1"], 1, "open slots")
		Lib.eq(slots.draft.seq, 5, "the sequence bumps")
		Lib.eq(slots.draft.syncState, "pending", "pending")
		Lib.eq(state.draft.current.openSlots["Farm-1"], nil, "the old draft did not change")

		local assigned = Store.setAssign(slots, "Farm-1", 2)
		Lib.eq(assigned.draft.current.assign["Farm-1"], 2, "assign")
		Lib.eq(assigned.draft.current.openSlots["Farm-1"], 1, "the earlier field stays")

		local strike = Store.setStrike(assigned, "Capitalist")
		Lib.eq(strike.draft.current.strike.target, "Capitalist", "the strike target")
		Lib.eq(Store.setStrike(strike, nil).draft.current.strike, nil, "a second click clears it")

		local build = Store.setBuild(strike, "Farm")
		Lib.eq(build.draft.current.build.lineType, "Farm", "the build")
		Lib.eq(Store.setBuild(build, nil).draft.current.build, nil, "clear the build")

		local lobby = Store.setLobby(build, 2)
		Lib.eq(lobby.draft.current.lobby.amount, 2, "the lobby")
		Lib.eq(Store.setLobby(lobby, 0).draft.current.lobby, nil, "zero clears the lobby")

		local market = Store.setMarket(lobby, "sell", "food", 2)
		Lib.eq(market.draft.current.market.sell.food, 2, "the sell")
		Lib.eq(
			Store.setMarket(market, "sell", "food", 0).draft.current.market.sell.food,
			nil,
			"zero clears the sell"
		)
		local buy = Store.setMarket(market, "buy", "goods", 1)
		Lib.eq(buy.draft.current.market.buy.goods, 1, "the buy")
		Lib.eq(buy.draft.current.market.sell.food, 2, "the sell stays")
	end)

	Lib.test("a vote edits the draft, switches and clears", function()
		local state = Store.applySnapshot(Store.initialState(), view(), 1, 1000, 900)
		local yes = Store.setVote(state, "Bill-1", "yes", 1)
		Lib.eq(yes.draft.current.votes["Bill-1"].side, "yes", "the side")
		Lib.eq(yes.draft.current.votes["Bill-1"].influence, 1, "the Influence")
		Lib.eq(yes.draft.seq, 5, "the sequence bumps")
		Lib.eq(yes.draft.syncState, "pending", "pending")
		Lib.eq(state.draft.current.votes["Bill-1"], nil, "the old draft did not change")

		local no = Store.setVote(yes, "Bill-1", "no", 0)
		Lib.eq(no.draft.current.votes["Bill-1"].side, "no", "the switched side")
		Lib.eq(no.draft.current.votes["Bill-1"].influence, 0, "no extra Influence")
		Lib.eq(no.draft.seq, 6, "the sequence bumps again")

		local cleared = Store.setVote(no, "Bill-1", nil, 0)
		Lib.eq(cleared.draft.current.votes["Bill-1"], nil, "the cleared vote")
		Lib.eq(cleared.draft.seq, 7, "the clear bumps the sequence")
	end)

	Lib.test("an older echo does not overwrite a newer local edit", function()
		local state = Store.applySnapshot(Store.initialState(), view(), 1, 1000, 900)
		local first = Store.setOpenSlots(state, "Farm-1", 1) -- seq 5
		local second = Store.setOpenSlots(first, "Farm-1", 2) -- seq 6

		-- the server accepts seq 5: it is the accepted baseline, but the
		-- newer local seq 6 stays
		local echoed = {
			sequence = 5,
			locked = false,
			openSlots = { ["Farm-1"] = 1 },
			assign = {},
			market = { sell = {}, buy = {} },
			votes = {},
		}
		local next = Store.applyPatch(second, { { op = "set", path = "draft", value = echoed } })
		Lib.eq(next.draft.seq, 6, "the local edit stays")
		Lib.eq(next.draft.current.openSlots["Farm-1"], 2, "the newer value stays")
		Lib.eq(next.draft.syncState, "pending", "still pending")
		Lib.eq(next.match.view.draft.sequence, 5, "the view remembers the accepted draft")

		-- a refusal reverts to the accepted seq 5, not the snapshot's seq 4
		local rejected = Store.rejectDraft(next)
		Lib.eq(rejected.draft.seq, 5, "the accepted draft")
		Lib.eq(rejected.draft.current.openSlots["Farm-1"], 1, "the accepted value")
		Lib.eq(rejected.draft.syncState, "rejected", "rejected")

		-- the echo of seq 6 is accepted and cleans the state
		local echoed6 = {
			sequence = 6,
			locked = false,
			openSlots = { ["Farm-1"] = 2 },
			assign = {},
			market = { sell = {}, buy = {} },
			votes = {},
		}
		local clean =
			Store.applyPatch(rejected, { { op = "set", path = "draft", value = echoed6 } })
		Lib.eq(clean.draft.seq, 6, "the newest echo")
		Lib.eq(clean.draft.syncState, "clean", "in sync")
	end)

	Lib.test("notices and chat messages arrive", function()
		local state = Store.initialState()
		local withNotice = Store.addNotice(state, { code = "RateLimited", message = "slow down" })
		Lib.eq(#withNotice.inbox.notices, 1, "the notice")
		Lib.eq(withNotice.inbox.notices[1].code, "RateLimited", "the code")

		local withChat = Store.addChat(withNotice, { channel = "Global", text = "hello" })
		Lib.eq(#withChat.chat.channels.Global, 1, "the message")
		Lib.eq(withChat.chat.channels.Global[1].text, "hello", "the text")
		Lib.eq(#state.inbox.notices, 0, "the old state did not change")
	end)

	Lib.test("the store tells its listeners about every change", function()
		local store = Store.new()
		local seen = 0
		local stop = store:subscribe(function(state)
			seen += 1
			Lib.eq(state, store:state(), "the listener sees the new state")
		end)
		store:set(Store.applySnapshot(store:state(), view(), 1, 1000, 900))
		Lib.eq(seen, 1, "one change")
		stop()
		store:set(Store.applyPhase(store:state(), "Reveal", 2, 1200, 1100, 1000))
		Lib.eq(seen, 1, "the listener is gone")
	end)
end

return M
