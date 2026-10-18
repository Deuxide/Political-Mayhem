--!strict
-- Screens module: exports all screen components.

local LobbyScreen = require(script.LobbyScreen)
local MatchHUD = require(script.MatchHUD)
local EndScreen = require(script.EndScreen)

return {
	LobbyScreen = LobbyScreen,
	MatchHUD = MatchHUD,
	EndScreen = EndScreen,
}