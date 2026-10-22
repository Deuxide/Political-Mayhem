--!strict
-- The client half of the net layer (NETWORKING 1 and 3): it waits for the
-- server's remotes, sends the client's intents, and hands every server
-- message to the store. It never touches the game state and never decides
-- anything — the server is the authority (D-003).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Store = require(script.Parent.Parent.State.Store)

type StoreType = Store.Store
type StoreState = Store.StoreState

export type Client = {
	_remotes: { [string]: any },
	_store: StoreType,
	_connected: boolean,
}

local Client = {}

-- The remotes are the server's (NETWORKING 3): the client waits for them.
function Client.new(store: StoreType): Client
	return { _remotes = {}, _store = store, _connected = false }
end

local function remote(client: Client, name: string): any
	local instance = client._remotes[name]
	if instance == nil then
		local net = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net")
		instance = net:WaitForChild(name)
		client._remotes[name] = instance
	end
	return instance
end

-- Connects the listeners and feeds the store (UI_SPEC section 7).
function Client.connect(client: Client)
	if client._connected then
		return
	end
	client._connected = true

	remote(client, "View_Snapshot").OnClientEvent:Connect(function(payload)
		Client.onSnapshot(client, payload)
	end)
	remote(client, "View_Patch").OnClientEvent:Connect(function(payload)
		Client.onPatch(client, payload)
	end)
	remote(client, "Phase_Changed").OnClientEvent:Connect(function(payload)
		Client.onPhase(client, payload)
	end)
	remote(client, "Reveal_Report").OnClientEvent:Connect(function(payload)
		Client.onReveal(client, payload)
	end)
	remote(client, "Notice").OnClientEvent:Connect(function(payload)
		Client.onNotice(client, payload)
	end)
	remote(client, "Chat_Message").OnClientEvent:Connect(function(payload)
		Client.onChat(client, payload)
	end)
	remote(client, "Trade_Incoming").OnClientEvent:Connect(function(payload)
		Client.onTradeIncoming(client, payload)
	end)
	remote(client, "Trade_Result").OnClientEvent:Connect(function(payload)
		Client.onTradeResult(client, payload)
	end)
	remote(client, "Match_Ended").OnClientEvent:Connect(function(payload)
		Client.onMatchEnded(client, payload)
	end)
end

-- ===== What the server sends =====

function Client.onSnapshot(client: Client, payload: any)
	local state = client._store:state()
	client._store:set(
		Store.applySnapshot(state, payload.view, payload.protocol, payload.serverTime, os.clock())
	)
end

function Client.onPatch(client: Client, payload: any)
	client._store:set(Store.applyPatch(client._store:state(), payload.ops))
end

function Client.onPhase(client: Client, payload: any)
	client._store:set(
		Store.applyPhase(
			client._store:state(),
			payload.phase,
			payload.day,
			payload.endsAt,
			os.clock() + client._store:state().match.serverOffset,
			os.clock()
		)
	)
end

function Client.onReveal(client: Client, payload: any)
	-- the report of the Day: the events are public, the deltas are the
	-- viewer's own (NETWORKING 3.2)
	client._store:set(Store.applyPatch(client._store:state(), {
		{ op = "set", path = "reveal", value = payload },
	}))
end

function Client.onNotice(client: Client, payload: any)
	client._store:set(Store.addNotice(client._store:state(), payload))
end

function Client.onChat(client: Client, payload: any)
	client._store:set(Store.addChat(client._store:state(), payload))
end

function Client.onTradeIncoming(client: Client, payload: any)
	client._store:set(Store.addNotice(client._store:state(), {
		code = "TradeIncoming",
		message = "a trade offer arrived",
		offer = payload.offer,
	}))
end

function Client.onTradeResult(client: Client, payload: any)
	client._store:set(Store.addNotice(client._store:state(), {
		code = "TradeResult",
		message = payload.status,
		offerId = payload.offerId,
	}))
end

function Client.onMatchEnded(client: Client, payload: any)
	client._store:set(Store.addNotice(client._store:state(), {
		code = "MatchEnded",
		message = payload.summary,
		result = payload.result,
	}))
end

-- ===== What the client sends =====

function Client.setClass(client: Client, classId: string)
	remote(client, "Lobby_SetClass"):FireServer({ class = classId })
end

function Client.setReady(client: Client, ready: boolean)
	remote(client, "Lobby_SetReady"):FireServer({ ready = ready })
end

function Client.configure(client: Client, difficulty: string)
	remote(client, "Lobby_Configure"):FireServer({ difficulty = difficulty })
end

function Client.start(client: Client)
	remote(client, "Lobby_Start"):FireServer({})
end

function Client.updateDraft(client: Client, seq: number, draft: any)
	remote(client, "Draft_Update"):FireServer({ seq = seq, draft = draft })
end

function Client.lockDraft(client: Client, locked: boolean)
	remote(client, "Draft_LockIn"):FireServer({ locked = locked })
end

function Client.proposeTrade(
	client: Client,
	requestId: string,
	to: string,
	give: any,
	want: any,
	promises: any
)
	remote(client, "Trade_Propose"):FireServer({
		requestId = requestId,
		to = to,
		give = give,
		want = want,
		promises = promises,
	})
end

function Client.respondTrade(client: Client, offerId: string, accept: boolean)
	remote(client, "Trade_Respond"):FireServer({ offerId = offerId, accept = accept })
end

function Client.cancelTrade(client: Client, offerId: string)
	remote(client, "Trade_Cancel"):FireServer({ offerId = offerId })
end

function Client.proposeAlliance(client: Client, to: string)
	remote(client, "Alliance_Propose"):FireServer({ to = to })
end

function Client.respondAlliance(client: Client, from: string, accept: boolean)
	remote(client, "Alliance_Respond"):FireServer({ from = from, accept = accept })
end

function Client.breakAlliance(client: Client)
	remote(client, "Alliance_Break"):FireServer({})
end

function Client.proposeBill(client: Client, requestId: string, policyId: string, level: number)
	remote(client, "Bill_Propose"):FireServer({
		requestId = requestId,
		policyId = policyId,
		level = level,
	})
end

function Client.sendChat(client: Client, channel: string, text: string, classTo: string?)
	remote(client, "Chat_Send"):FireServer({ channel = channel, text = text, classTo = classTo })
end

return Client
