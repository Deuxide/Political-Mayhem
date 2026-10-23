--!strict
-- The client store (UI_SPEC section 7): the client's copy of the world. It
-- holds the latest view from the server, the local draft, the inbox, the
-- chat and the UI state.
--
-- The reducers are pure functions over plain data, so they are unit-tested
-- without Roblox (tests/client_store.test.luau). The store itself only
-- holds the state and the listeners.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

type ActionDraft = Types.ActionDraft
type ClassId = Types.ClassId
type LogEntry = Types.LogEntry
type PlayerView = Types.PlayerView
type Phase = Types.Phase

export type ConnectionStatus = "connecting" | "ready" | "closed"

export type StoreState = {
	connection: {
		status: ConnectionStatus,
		protocol: number?,
	},
	match: {
		view: PlayerView?,
		phase: Phase,
		day: number,
		endsAt: number,
		serverOffset: number, -- serverTime minus the local clock
	},
	draft: {
		current: ActionDraft,
		seq: number,
		syncState: "clean" | "pending" | "rejected",
	},
	inbox: {
		offers: { any },
		bills: { any },
		notices: { any },
	},
	chat: {
		channels: { [string]: { any } },
		unread: { [string]: number },
	},
	ui: {
		activeTab: string,
		drawerOpen: boolean,
		selectedClass: ClassId?,
		modals: { string },
	},
}

export type PatchOp = Remotes.PatchOp

local Store = {}
Store.__index = Store

-- The state a fresh client starts with.
function Store.initialState(): StoreState
	return {
		connection = { status = "connecting", protocol = nil },
		match = { view = nil, phase = "Window", day = 1, endsAt = 0, serverOffset = 0 },
		draft = { current = Store.emptyDraft(), seq = 0, syncState = "clean" },
		inbox = { offers = {}, bills = {}, notices = {} },
		chat = { channels = {}, unread = {} },
		ui = { activeTab = "economy", drawerOpen = false, selectedClass = nil, modals = {} },
	}
end

function Store.emptyDraft(): ActionDraft
	return {
		sequence = 0,
		locked = false,
		openSlots = {},
		assign = {},
		market = { sell = {}, buy = {} },
		votes = {},
	}
end

-- ===== The reducers (pure) =====

-- A full view from the server (NETWORKING 3.2). The view replaces the old
-- one; the draft the server accepted is the new local draft.
function Store.applySnapshot(
	state: StoreState,
	view: PlayerView,
	protocol: number,
	serverTime: number,
	localTime: number
): StoreState
	local next = Store.copy(state)
	next.connection = { status = "ready", protocol = protocol }
	next.match.view = view
	next.match.serverOffset = serverTime - localTime
	next.draft.current = view.draft
	next.draft.seq = view.draft.sequence
	next.draft.syncState = "clean"
	return next
end

-- The phase and the Day (NETWORKING 3.2).
function Store.applyPhase(
	state: StoreState,
	phase: Phase,
	day: number,
	endsAt: number,
	serverTime: number,
	localTime: number
): StoreState
	local next = Store.copy(state)
	next.match.phase = phase
	next.match.day = day
	next.match.endsAt = endsAt
	next.match.serverOffset = serverTime - localTime
	return next
end

-- A patch (NETWORKING 4). The paths are the ones the server sends: "draft"
-- is set, "bills" and "alliances" are appended.
function Store.applyPatch(state: StoreState, ops: { PatchOp }): StoreState
	local next = Store.copy(state)
	for _, op in ops do
		if op.op == "set" and op.path == "draft" then
			next.draft.current = op.value :: ActionDraft
			next.draft.seq = (op.value :: ActionDraft).sequence
			next.draft.syncState = "clean"
		elseif op.op == "append" and op.path == "bills" then
			table.insert(next.inbox.bills, op.value)
		elseif op.op == "append" and op.path == "alliances" then
			local view = next.match.view
			if view ~= nil then
				table.insert(view.alliances, op.value)
			end
		end
	end
	return next
end

-- The active tab (UI_SPEC section 7): a local UI choice, never a server
-- field. The dock and the own panel both read it.
function Store.applyActiveTab(state: StoreState, tab: string): StoreState
	local next = Store.copy(state)
	next.ui.activeTab = tab
	return next
end

-- The local draft changed: it is pending until the server echoes it.
function Store.setLocalDraft(state: StoreState, draft: ActionDraft, seq: number): StoreState
	local next = Store.copy(state)
	next.draft.current = draft
	next.draft.seq = seq
	next.draft.syncState = "pending"
	return next
end

-- The server refused a draft: the local copy is dropped and the client shows
-- the server's version (NETWORKING 4).
function Store.rejectDraft(state: StoreState): StoreState
	local next = Store.copy(state)
	local view = next.match.view
	if view ~= nil then
		next.draft.current = view.draft
		next.draft.seq = view.draft.sequence
	end
	next.draft.syncState = "rejected"
	return next
end

-- A notice from the server (NETWORKING 3.2).
function Store.addNotice(state: StoreState, notice: any): StoreState
	local next = Store.copy(state)
	table.insert(next.inbox.notices, notice)
	return next
end

-- A chat message (NETWORKING 3.2).
function Store.addChat(state: StoreState, message: any): StoreState
	local next = Store.copy(state)
	local channel = message.channel
	local list = next.chat.channels[channel]
	if list == nil then
		list = {}
		next.chat.channels[channel] = list
	end
	table.insert(list, message)
	return next
end

-- A copy of the state, one level deep: the parts the reducers replace are
-- copied, the lists are copied before they change.
function Store.copy(state: StoreState): StoreState
	return {
		connection = { status = state.connection.status, protocol = state.connection.protocol },
		match = {
			view = state.match.view,
			phase = state.match.phase,
			day = state.match.day,
			endsAt = state.match.endsAt,
			serverOffset = state.match.serverOffset,
		},
		draft = {
			current = state.draft.current,
			seq = state.draft.seq,
			syncState = state.draft.syncState,
		},
		inbox = {
			offers = { table.unpack(state.inbox.offers) },
			bills = { table.unpack(state.inbox.bills) },
			notices = { table.unpack(state.inbox.notices) },
		},
		chat = {
			channels = state.chat.channels,
			unread = state.chat.unread,
		},
		ui = {
			activeTab = state.ui.activeTab,
			drawerOpen = state.ui.drawerOpen,
			selectedClass = state.ui.selectedClass,
			modals = { table.unpack(state.ui.modals) },
		},
	}
end

-- ===== The store =====

export type Store = typeof(setmetatable({
	_state = {} :: StoreState,
	_listeners = {} :: { (StoreState) -> () },
}, Store))

function Store.new(): Store
	return setmetatable({
		_state = Store.initialState(),
		_listeners = {},
	}, Store)
end

function Store.state(store: Store): StoreState
	return store._state
end

-- The listeners: the panels subscribe and re-render on a change.
function Store.subscribe(store: Store, listener: (StoreState) -> ()): () -> ()
	table.insert(store._listeners, listener)
	return function()
		for index, candidate in store._listeners do
			if candidate == listener then
				table.remove(store._listeners, index)
				return
			end
		end
	end
end

-- Every change goes through here: the state is replaced and the listeners
-- hear about it.
function Store.set(store: Store, state: StoreState)
	store._state = state
	for _, listener in store._listeners do
		listener(state)
	end
end

return Store
