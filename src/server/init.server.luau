--!strict
-- Server entry point: boots services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Services
local LobbyService = require(script.Services.LobbyService)
local TeamService = require(script.Services.TeamService)
local MatchService = require(script.Services.MatchService)
local BotService = require(script.Services.BotService)

-- Initialize services
LobbyService.init()
TeamService.init()
MatchService.init()
BotService.init()

print("Server booted")
