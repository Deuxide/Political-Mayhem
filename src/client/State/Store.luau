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
type BillId = Types.BillId
type ClassId = Types.ClassId
type LineId = Types.LineId
type LineType = Types.LineType
type LogEntry = Types.LogEntry
type PlayerView = Types.PlayerView
type Phase = Types.Phase
type StockId = Types.StockId
type TradeOffer = Types.TradeOffer
type VoteSide = Types.VoteSide
type VoteSpec = Types.VoteSpec

export type ConnectionStatus = "connecting" | "ready" | "closed"

export type TradeDirection = "in" | "out"
export type TradeStatus = "pending" | "accepted" | "declined" | "failed" | "expired"

-- One live (or just-resolved) trade offer in the inbox/outbox. The view does
-- not carry trades (NETWORKING 3.1 sends them as events), so the store keeps
-- them: `direction` says which side the viewer is on, `requestId` correlates
-- an outgoing proposal with the server's ack, and `pendingAck` is true until
-- that ack gives the offer its server id.
export type TradeEntry = {
	offer: TradeOffer,
	direction: TradeDirection,
	status: TradeStatus,
	reason: string?,
	requestId: string?,
	pendingAck: boolean?,
}

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
		offers: { TradeEntry },
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
	-- A snapshot for a new Day starts a new Window: any offer from the old
	-- Day is stale (the server expired it at the Closing Bell).
	if view.day ~= state.match.day then
		next.inbox.offers = {}
	end
	next.match.view = view
	next.match.serverOffset = serverTime - localTime
	next.draft.current = view.draft
	next.draft.seq = view.draft.sequence
	next.draft.syncState = "clean"
	return next
end

-- The phase and the Day (NETWORKING 3.2). Offers are live only in a Window
-- (GAME_DESIGN 8.2): the Closing Bell expires the pending ones, and the next
-- Window starts with a clean inbox/outbox.
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
	if phase == "Resolve" then
		local offers: { TradeEntry } = {}
		for _, entry in next.inbox.offers do
			local copy = Store.copyTradeEntry(entry)
			if copy.status == "pending" then
				copy.status = "expired"
			end
			table.insert(offers, copy)
		end
		next.inbox.offers = offers
	elseif phase == "Window" then
		next.inbox.offers = {}
	end
	return next
end

-- A shallow copy of a view with one field replaced. The view is immutable
-- in the store: a patch builds a new table (the UI compares views and the
-- old state must stay intact).
local function copyView(view: PlayerView): PlayerView
	return {
		viewer = view.viewer,
		day = view.day,
		rounds = view.rounds,
		phase = view.phase,
		stability = view.stability,
		policies = view.policies,
		own = view.own,
		ownLines = view.ownLines,
		needs = view.needs,
		draft = view.draft,
		others = view.others,
		bills = view.bills,
		promises = view.promises,
		alliances = view.alliances,
		allianceProposals = view.allianceProposals,
		reputation = view.reputation,
		victory = view.victory,
	}
end

-- A shallow copy of a view with one field replaced (the server's accepted
-- draft).
function Store.withDraft(view: PlayerView, draft: ActionDraft): PlayerView
	local next = copyView(view)
	next.draft = draft
	return next
end

-- A shallow copy of a view with a new live-bills list (M8-T1). A public bill
-- patch must not mutate the view the old state still holds.
function Store.withBills(view: PlayerView, bills: { Types.Bill }): PlayerView
	local next = copyView(view)
	next.bills = bills
	return next
end

-- The same for the public promises (M8-T2) and alliances (M8-T3).
function Store.withPromises(view: PlayerView, promises: { Types.Promise }): PlayerView
	local next = copyView(view)
	next.promises = promises
	return next
end

function Store.withAlliances(view: PlayerView, alliances: { Types.Alliance }): PlayerView
	local next = copyView(view)
	next.alliances = alliances
	return next
end

-- The viewer's private pending proposals (M8-T3).
function Store.withAllianceProposals(
	view: PlayerView,
	proposals: { Types.AllianceProposal }
): PlayerView
	local next = copyView(view)
	next.allianceProposals = proposals
	return next
end

-- A patch (NETWORKING 4). The paths are the ones the server sends: "draft"
-- is set; "bills" and "promises" are appended; "alliances" and the private
-- "allianceProposals" are appended or removed. An echoed draft older than
-- the local edit is remembered as the server's accepted copy but does not
-- overwrite the newer local edit.
function Store.applyPatch(state: StoreState, ops: { PatchOp }): StoreState
	local next = Store.copy(state)
	for _, op in ops do
		if op.op == "set" and op.path == "draft" then
			local echoed = op.value :: ActionDraft
			if echoed.sequence >= next.draft.seq then
				next.draft.current = echoed
				next.draft.seq = echoed.sequence
				next.draft.syncState = "clean"
			end
			local view = next.match.view
			if view ~= nil and echoed.sequence > view.draft.sequence then
				next.match.view = Store.withDraft(view, echoed)
			end
		elseif op.op == "append" and op.path == "bills" then
			local bill = op.value :: Types.Bill
			table.insert(next.inbox.bills, bill)
			local view = next.match.view
			if view ~= nil then
				local exists = false
				for _, existing in view.bills do
					if existing.id == bill.id then
						exists = true
						break
					end
				end
				if not exists then
					local bills: { Types.Bill } = {}
					for _, existing in view.bills do
						table.insert(bills, existing)
					end
					table.insert(bills, bill)
					next.match.view = Store.withBills(view, bills)
				end
			end
		elseif op.op == "append" and op.path == "promises" then
			local promise = op.value :: Types.Promise
			local view = next.match.view
			if view ~= nil then
				local exists = false
				for _, existing in view.promises do
					if existing.id == promise.id then
						exists = true
						break
					end
				end
				if not exists then
					local promises: { Types.Promise } = {}
					for _, existing in view.promises do
						table.insert(promises, existing)
					end
					table.insert(promises, promise)
					next.match.view = Store.withPromises(view, promises)
				end
			end
		elseif (op.op == "append" or op.op == "remove") and op.path == "allianceProposals" then
			local proposal = op.value :: Types.AllianceProposal
			local view = next.match.view
			if view ~= nil then
				local proposals: { Types.AllianceProposal } = {}
				for _, existing in view.allianceProposals do
					if existing.id ~= proposal.id then
						table.insert(proposals, existing)
					end
				end
				if op.op == "append" then
					table.insert(proposals, proposal)
				end
				next.match.view = Store.withAllianceProposals(view, proposals)
			end
		elseif (op.op == "append" or op.op == "remove") and op.path == "alliances" then
			local alliance = op.value :: Types.Alliance
			local view = next.match.view
			if view ~= nil then
				local alliances: { Types.Alliance } = {}
				for _, existing in view.alliances do
					if existing.id ~= alliance.id then
						table.insert(alliances, existing)
					end
				end
				if op.op == "append" then
					table.insert(alliances, alliance)
				end
				next.match.view = Store.withAlliances(view, alliances)
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

-- A copy of a draft deep enough for the reducers: every table a reducer may
-- change is copied, so the old state is never mutated.
local function copyMap<K, V>(source: { [K]: V }): { [K]: V }
	return table.clone(source)
end

function Store.copyDraft(draft: ActionDraft): ActionDraft
	local votes: { [BillId]: VoteSpec } = {}
	for billId, vote in draft.votes do
		votes[billId] = { side = vote.side, influence = vote.influence }
	end
	local market: Types.MarketOrder = {
		sell = copyMap(draft.market.sell) :: Types.MarketBag,
		buy = copyMap(draft.market.buy) :: Types.MarketBag,
	}
	return {
		sequence = draft.sequence,
		locked = draft.locked,
		openSlots = copyMap(draft.openSlots),
		assign = copyMap(draft.assign),
		strike = if draft.strike ~= nil then { target = draft.strike.target } else nil,
		build = if draft.build ~= nil then { lineType = draft.build.lineType } else nil,
		lobby = if draft.lobby ~= nil then { amount = draft.lobby.amount } else nil,
		market = market,
		votes = votes,
	}
end

-- The next local draft: a copy with the next sequence number. Every edit
-- bumps the sequence so the server can drop an older packet (NETWORKING 4).
local function editDraft(state: StoreState): ActionDraft
	local draft = Store.copyDraft(state.draft.current)
	draft.sequence = state.draft.seq + 1
	return draft
end

-- The economy reducers (UI_SPEC 4.2): each one changes one draft field and
-- leaves the rest alone. They are pure; the App sends the result through the
-- client's debounce.
function Store.setOpenSlots(state: StoreState, lineId: LineId, count: number): StoreState
	local draft = editDraft(state)
	draft.openSlots[lineId] = math.max(0, count)
	return Store.setLocalDraft(state, draft, draft.sequence)
end

function Store.setAssign(state: StoreState, lineId: LineId, count: number): StoreState
	local draft = editDraft(state)
	draft.assign[lineId] = math.max(0, count)
	return Store.setLocalDraft(state, draft, draft.sequence)
end

function Store.setStrike(state: StoreState, target: ClassId?): StoreState
	local draft = editDraft(state)
	draft.strike = if target ~= nil then { target = target } else nil
	return Store.setLocalDraft(state, draft, draft.sequence)
end

function Store.setBuild(state: StoreState, lineType: LineType?): StoreState
	local draft = editDraft(state)
	draft.build = if lineType ~= nil then { lineType = lineType } else nil
	return Store.setLocalDraft(state, draft, draft.sequence)
end

function Store.setLobby(state: StoreState, amount: number): StoreState
	local draft = editDraft(state)
	draft.lobby = if amount > 0 then { amount = amount } else nil
	return Store.setLocalDraft(state, draft, draft.sequence)
end

function Store.setMarket(
	state: StoreState,
	side: "sell" | "buy",
	stockId: StockId,
	volume: number
): StoreState
	local draft = editDraft(state)
	local bag = if side == "sell" then draft.market.sell else draft.market.buy
	if volume > 0 then
		bag[stockId] = volume
	else
		bag[stockId] = nil
	end
	return Store.setLocalDraft(state, draft, draft.sequence)
end

-- The politics reducer (M8-T1): a bill's ballot is the side plus the extra
-- Influence committed to it, part of the draft like every other field. A nil
-- side clears the vote (the class abstains); everything is re-checked by the
-- server when the draft is sent.
function Store.setVote(
	state: StoreState,
	billId: BillId,
	side: VoteSide?,
	influence: number?
): StoreState
	local draft = editDraft(state)
	if side == nil then
		draft.votes[billId] = nil
	else
		draft.votes[billId] = { side = side, influence = math.max(0, influence or 0) }
	end
	return Store.setLocalDraft(state, draft, draft.sequence)
end

-- ===== The trade offers (M8-T2, GAME_DESIGN 8.2) =====
--
-- The PlayerView deliberately has no trades: the server sends Trade_Incoming
-- to the recipient and Trade_Result to the parties (NETWORKING 3.1). The
-- store is therefore the client's inbox/outbox; the reducers below keep it
-- in step with those events.

-- A copy of one entry. The entries in the store are never mutated: a reducer
-- replaces the list and the entries it changes, like the view.
function Store.copyTradeEntry(entry: TradeEntry): TradeEntry
	return {
		offer = entry.offer,
		direction = entry.direction,
		status = entry.status,
		reason = entry.reason,
		requestId = entry.requestId,
		pendingAck = entry.pendingAck,
	}
end

-- The server gave the offer its id on the proposal ack; the rest of the
-- offer is the local copy the composer built.
function Store.copyOfferWithId(offer: TradeOffer, id: string): TradeOffer
	return {
		id = id,
		from = offer.from,
		to = offer.to,
		give = offer.give,
		want = offer.want,
		promises = offer.promises,
		expiresAt = offer.expiresAt,
	}
end

-- An offer addressed to the viewer (Trade_Incoming).
function Store.addIncomingOffer(state: StoreState, offer: TradeOffer): StoreState
	local next = Store.copy(state)
	for _, entry in next.inbox.offers do
		if entry.offer.id == offer.id then
			return next
		end
	end
	table.insert(next.inbox.offers, {
		offer = offer,
		direction = "in",
		status = "pending",
		requestId = nil,
		pendingAck = false,
	})
	return next
end

-- An offer the viewer just sent. The composer builds the local offer and the
-- request id; the ack replaces the temporary id with the server's.
function Store.addOutgoingOffer(state: StoreState, offer: TradeOffer, requestId: string): StoreState
	local next = Store.copy(state)
	table.insert(next.inbox.offers, {
		offer = offer,
		direction = "out",
		status = "pending",
		requestId = requestId,
		pendingAck = true,
	})
	return next
end

-- Trade_Result does double duty (NETWORKING 3.1): with a requestId it is the
-- server accepting the *proposal* (the offer now has an id, but the trade is
-- still pending); without one it is the answer to the offer itself.
function Store.applyTradeResult(state: StoreState, payload: any): StoreState
	local next = Store.copy(state)
	local requestId = payload.requestId
	local offerId = payload.offerId
	local status: TradeStatus = payload.status :: any
	local offers: { TradeEntry } = {}
	for _, entry in next.inbox.offers do
		local copy = Store.copyTradeEntry(entry)
		if requestId ~= nil and requestId ~= "" then
			if entry.direction == "out" and entry.requestId == requestId then
				copy.offer = Store.copyOfferWithId(entry.offer, offerId)
				copy.pendingAck = false
			end
		elseif entry.offer.id == offerId then
			copy.status = status
			copy.reason = payload.reason
		end
		table.insert(offers, copy)
	end
	next.inbox.offers = offers
	return next
end

-- A notice from the server (NETWORKING 3.2).
function Store.addNotice(state: StoreState, notice: any): StoreState
	local next = Store.copy(state)
	table.insert(next.inbox.notices, notice)
	return next
end

-- A chat message (NETWORKING 3.2). It is appended to its channel and the
-- channel's unread count rises; the drawer marks the channel read while it
-- shows it (Store.applyChatRead). Both maps are copied, so the old state is
-- never mutated.
function Store.addChat(state: StoreState, message: any): StoreState
	local next = Store.copy(state)
	local channels: { [string]: { any } } = {}
	for name, list in next.chat.channels do
		channels[name] = { table.unpack(list) }
	end
	local list = channels[message.channel] or {}
	table.insert(list, message)
	channels[message.channel] = list
	next.chat.channels = channels
	local unread = table.clone(next.chat.unread)
	unread[message.channel] = (unread[message.channel] or 0) + 1
	next.chat.unread = unread
	return next
end

-- The drawer showed a channel: its unread count returns to zero. The
-- messages themselves stay.
function Store.applyChatRead(state: StoreState, channel: string): StoreState
	local next = Store.copy(state)
	local unread = table.clone(next.chat.unread)
	unread[channel] = 0
	next.chat.unread = unread
	return next
end

-- The chat drawer opens or closes (UI_SPEC section 7): a local UI choice.
function Store.applyDrawerOpen(state: StoreState, open: boolean): StoreState
	local next = Store.copy(state)
	next.ui.drawerOpen = open
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
