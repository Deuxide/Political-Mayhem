--!strict
-- Server entry point: the composition root. It creates the remotes, the
-- lobby and the services, and connects them to the players. Every decision
-- lives in a service; this file only wires things together.

local Players = game:GetService("Players")
local RemoteFactory = require(script.Net.RemoteFactory)
local LobbyService = require(script.Services.LobbyService)
local LobbyHandlers = require(script.Handlers.LobbyHandlers)

print("Server booted")

-- The remotes are the server's (NETWORKING section 3): the client waits for
-- them, so a client can never create or fire a server-only remote.
local remotes = RemoteFactory.create()
local count = 0
for _ in pairs(remotes) do
	count += 1
end
print(`[Net] {count} remotes ready in ReplicatedStorage.Shared.Net`)

-- The match seed is the server's (the lobby configures the difficulty, not
-- the seed); the match logs it so a match can be replayed (NETWORKING 9).
local seed = Random.new():NextInteger(1, 1000000)
local lobby = LobbyService.new(seed)

LobbyHandlers.connect(remotes, lobby, function(match)
	local state = match:state()
	print(`[Lobby] match {state.id} started ({state.difficulty}, seed {state.seed})`)
end)

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
