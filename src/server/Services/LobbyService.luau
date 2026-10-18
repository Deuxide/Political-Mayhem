--!strict
-- Lobby service: join, class choice, ready, host start; bots fill empty seats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type LobbyService = {
	init: () -> (),
}

local LobbyService = {}

function LobbyService.init()
	-- TODO: Implement lobby logic (M6-T2)
	print("LobbyService initialized")
end

return LobbyService
