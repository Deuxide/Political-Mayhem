--!strict
-- Server entry point: the composition root. It creates the remotes, the
-- lobby and the services, and connects them to the players. Every decision
-- lives in a service; this file only wires things together.

local Players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local TextService = game:GetService("TextService")
local RemoteFactory = require(script.Net.RemoteFactory)
local LobbyService = require(script.Services.LobbyService)
local MatchService = require(script.Services.MatchService)
local LobbyHandlers = require(script.Handlers.LobbyHandlers)
local Support = require(script.Handlers.Support)
local DraftHandlers = require(script.Handlers.DraftHandlers)
local TradeHandlers = require(script.Handlers.TradeHandlers)
local AllianceHandlers = require(script.Handlers.AllianceHandlers)
local BillHandlers = require(script.Handlers.BillHandlers)
local ChatHandlers = require(script.Handlers.ChatHandlers)

print("Server booted")

-- The remotes are the server's (NETWORKING section 3): the client waits for
-- them, so a client can never create or fire a server-only remote.
local remotes = RemoteFactory.create()
local count = 0
for _ in pairs(remotes) do
	count += 1
end
print(`[Net] {count} remotes ready in ReplicatedStorage.Shared.Net`)

-- Player text is filtered by Roblox's own text service before anybody sees
-- it (D-025). When the filter cannot answer, the message is refused: an
-- unfiltered message never goes out.
local function filterChat(text: string, fromUserId: number): (string?, string?)
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, fromUserId):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return nil, "the message could not be filtered"
	end
	return result, ""
end

-- The match seed is the server's (the lobby configures the difficulty, not
-- the seed); the match logs it so a match can be replayed (NETWORKING 9).
local seed = Random.new():NextInteger(1, 1000000)
local lobby = LobbyService.new(seed)

-- The shared parts of every handler: the remotes, the seats, the players,
-- the clock and the chat filter.
local support = Support.new(remotes, lobby, function()
	return Players:GetPlayers()
end, function()
	return workspace:GetServerTimeNow()
end, filterChat)

LobbyHandlers.connect(remotes, lobby, function(match)
	local state = match:state()
	print(`[Lobby] match {state.id} started ({state.difficulty}, seed {state.seed})`)

	-- The phase scheduler: the server owns the clock, and no client can move
	-- a phase (NETWORKING 5 and 8).
	MatchService.new({
		match = match,
		onPhaseChanged = function(payload)
			for _, player in Players:GetPlayers() do
				remotes.Phase_Changed:FireClient(player, payload)
			end
		end,
		onMatchEnded = function(result)
			print(`[Match] the match ended: {result.kind}`)
		end,
		clock = function()
			return workspace:GetServerTimeNow()
		end,
		schedule = function(delaySeconds, callback)
			task.delay(delaySeconds, callback)
		end,
	}):start()
end)

DraftHandlers.connect(support)
TradeHandlers.connect(support)
AllianceHandlers.connect(support)
BillHandlers.connect(support)
ChatHandlers.connect(support)

local function onPlayerAdded(player: any)
	if lobby:seatOf(player.UserId) ~= nil then
		return
	end
	local seat = lobby:join(player.UserId, player.Name)
	print(`[Lobby] {seat.name} joined the lobby`)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
