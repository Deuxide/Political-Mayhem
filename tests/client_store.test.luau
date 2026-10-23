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
