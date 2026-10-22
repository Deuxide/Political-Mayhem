--!strict
-- The lobby remote handlers (M6-T2): Lobby_SetClass, Lobby_SetReady,
-- Lobby_Configure, Lobby_Start. Every handler answers with a Notice when it
-- refuses, and it changes nothing it did not accept (NETWORKING 1.2).
--
-- The handlers take the remotes and the lobby as arguments, so they can be
-- driven with fake players in a test (M6-T4) and so nothing here depends on
-- a global.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Validate = require(ReplicatedStorage.Shared.Net.Validate)
local Match = require(ReplicatedStorage.Shared.Game.Match)
local RemoteFactory = require(script.Parent.Parent.Net.RemoteFactory)
local LobbyService = require(script.Parent.Parent.Services.LobbyService)

type ClassId = Types.ClassId
type Difficulty = Types.Difficulty
type LobbyServiceType = LobbyService.LobbyService
type RemoteSet = RemoteFactory.RemoteSet

local LobbyHandlers = {}

-- A payload may only carry the keys the remote defines (NETWORKING 7).
local function hasOnlyKeys(payload: any, allowed: { string }): boolean
	for key in payload do
		local known = false
		for _, name in allowed do
			if key == name then
				known = true
				break
			end
		end
		if not known then
			return false
		end
	end
	return true
end

local function notice(remotes: RemoteSet, player: any, code: string, message: string)
	remotes.Notice:FireClient(player, { code = code, message = message })
end

-- Connects the four lobby remotes. The match the host starts is handed to
-- `onMatchStarted` (the MatchService takes it from there, M6-T3).
function LobbyHandlers.connect(
	remotes: RemoteSet,
	lobby: LobbyServiceType,
	onMatchStarted: ((Match.Match) -> ())?
)
	remotes.Lobby_SetClass.OnServerEvent:Connect(function(player: any, payload: any)
		if
			type(payload) ~= "table"
			or not hasOnlyKeys(payload, { "class" })
			or not Validate.isClassId(payload.class)
		then
			notice(remotes, player, "InvalidPayload", "Lobby_SetClass needs one class.")
			return
		end
		local classId: ClassId = payload.class
		local ok, reason = lobby:setClass(player.UserId, classId)
		if not ok then
			notice(remotes, player, "Rejected", reason)
		end
	end)

	remotes.Lobby_SetReady.OnServerEvent:Connect(function(player: any, payload: any)
		if
			type(payload) ~= "table"
			or not hasOnlyKeys(payload, { "ready" })
			or type(payload.ready) ~= "boolean"
		then
			notice(remotes, player, "InvalidPayload", "Lobby_SetReady needs one boolean.")
			return
		end
		local ok, reason = lobby:setReady(player.UserId, payload.ready)
		if not ok then
			notice(remotes, player, "Rejected", reason)
		end
	end)

	remotes.Lobby_Configure.OnServerEvent:Connect(function(player: any, payload: any)
		if
			type(payload) ~= "table"
			or not hasOnlyKeys(payload, { "difficulty" })
			or not Validate.isDifficulty(payload.difficulty)
		then
			notice(remotes, player, "InvalidPayload", "Lobby_Configure needs a difficulty.")
			return
		end
		local difficulty: Difficulty = payload.difficulty
		local ok, reason = lobby:configure(player.UserId, difficulty)
		if not ok then
			notice(remotes, player, "Rejected", reason)
		end
	end)

	remotes.Lobby_Start.OnServerEvent:Connect(function(player: any, payload: any)
		if type(payload) ~= "table" or not hasOnlyKeys(payload, {}) then
			notice(remotes, player, "InvalidPayload", "Lobby_Start takes no arguments.")
			return
		end
		local match, reason = lobby:start(player.UserId)
		if match == nil then
			notice(remotes, player, "Rejected", reason)
			return
		end
		if onMatchStarted ~= nil then
			onMatchStarted(match)
		end
	end)
end

return LobbyHandlers
