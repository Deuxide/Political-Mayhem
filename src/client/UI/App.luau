--!strict
-- App: main React root component.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local ThemeContext = require(script.Parent.Theme.ThemeContext)
local Screens = require(script.Parent.Screens)
local GalleryScreen = require(script.Parent.Gallery.GalleryScreen)

local LobbyScreen = Screens.LobbyScreen
local MatchHUD = Screens.MatchHUD
local EndScreen = Screens.EndScreen

local function App()
	local state, setState = React.useState({
		screen = "Lobby",
		lobby = {
			availableClasses = { "Working", "Middle", "Capitalist", "State" },
			selectedClass = nil,
			ready = false,
			canStart = false,
		},
		match = {
			ownClass = "Working",
			phase = "ActionWindow",
			round = 1,
			timeRemaining = 90,
			ownResources = {
				Money = 10,
				Influence = 5,
				Food = 5,
				Goods = 0,
				Health = 5,
				Education = 0,
			},
			ownVP = 0,
			maxVP = 10,
			ownStability = 50,
			ownInfluence = 5,
			otherClasses = {
				{
					classId = "Middle",
					resources = {
						Money = 15,
						Influence = 5,
						Food = 3,
						Goods = 3,
						Health = 3,
						Education = 3,
					},
					vp = 0,
					maxVP = 10,
					stability = 50,
					alliance = false,
				},
				{
					classId = "Capitalist",
					resources = {
						Money = 20,
						Influence = 5,
						Food = 0,
						Goods = 5,
						Health = 0,
						Education = 5,
					},
					vp = 0,
					maxVP = 10,
					stability = 50,
					alliance = false,
				},
				{
					classId = "State",
					resources = {
						Money = 30,
						Influence = 10,
						Food = 0,
						Goods = 0,
						Health = 0,
						Education = 0,
					},
					vp = 0,
					maxVP = 10,
					stability = 50,
					alliance = false,
				},
			},
		},
		final = {
			result = "None",
			winners = {},
			finalScores = {},
		},
	})

	local function goToMatch()
		setState(
			function(prev)
				return {
					screen = "Match",
					lobby = prev.lobby,
					match = {
						ownClass = prev.lobby.selectedClass or "Working",
						phase = "ActionWindow",
						round = 1,
						timeRemaining = 90,
						ownResources = {
							Money = 10,
							Influence = 5,
							Food = 5,
							Goods = 0,
							Health = 5,
							Education = 0,
						},
						ownVP = 0,
						maxVP = 10,
						ownStability = 50,
						ownInfluence = 5,
						otherClasses = {
							{
								classId = "Middle",
								resources = {
									Money = 15,
									Influence = 5,
									Food = 3,
									Goods = 3,
									Health = 3,
									Education = 3,
								},
								vp = 0,
								maxVP = 10,
								stability = 50,
								alliance = false,
							},
							{
								classId = "Capitalist",
								resources = {
									Money = 20,
									Influence = 5,
									Food = 0,
									Goods = 5,
									Health = 0,
									Education = 5,
								},
								vp = 0,
								maxVP = 10,
								stability = 50,
								alliance = false,
							},
							{
								classId = "State",
								resources = {
									Money = 30,
									Influence = 10,
									Food = 0,
									Goods = 0,
									Health = 0,
									Education = 0,
								},
								vp = 0,
								maxVP = 10,
								stability = 50,
								alliance = false,
							},
						},
					},
					final = prev.final,
				}
			end
		)
	end

	local function goToEnd()
		setState(
			function(prev)
				return {
					screen = "End",
					lobby = prev.lobby,
					match = prev.match,
					final = {
						result = "Solo",
						winners = { "Working" },
						finalScores = { Working = 10, Middle = 5, Capitalist = 3, State = 2 },
					},
				}
			end
		)
	end

	local function goToLobby()
		setState(
			function(prev)
				return {
					screen = "Lobby",
					lobby = prev.lobby,
					match = prev.match,
					final = prev.final,
				}
			end
		)
	end

	local function goToGallery()
		setState(
			function(prev)
				return {
					screen = "Gallery",
					lobby = prev.lobby,
					match = prev.match,
					final = prev.final,
				}
			end
		)
	end

	local currentScreen = state.screen

	return React.createElement(ThemeContext.ThemeProvider, nil, {
		Screen = currentScreen == "Lobby" and React.createElement(LobbyScreen, {
			availableClasses = state.lobby.availableClasses,
			selectedClass = state.lobby.selectedClass,
			onClassSelect = function(classId)
				setState(
					function(prev)
						return {
							screen = prev.screen,
							lobby = {
								availableClasses = prev.lobby.availableClasses,
								selectedClass = classId,
								ready = prev.lobby.ready,
								canStart = prev.lobby.canStart,
							},
							match = prev.match,
							final = prev.final,
						}
					end
				)
			end,
			ready = state.lobby.ready,
			onReadyToggle = function()
				setState(
					function(prev)
						return {
							screen = prev.screen,
							lobby = {
								availableClasses = prev.lobby.availableClasses,
								selectedClass = prev.lobby.selectedClass,
								ready = not prev.lobby.ready,
								canStart = prev.lobby.canStart,
							},
							match = prev.match,
							final = prev.final,
						}
					end
				)
			end,
			canStart = state.lobby.canStart,
			onStart = goToMatch,
		}) or currentScreen == "Match" and React.createElement(MatchHUD, {
			ownClass = state.match.ownClass,
			phase = state.match.phase,
			round = state.match.round,
			timeRemaining = state.match.timeRemaining,
			ownResources = state.match.ownResources,
			ownVP = state.match.ownVP,
			maxVP = state.match.maxVP,
			ownStability = state.match.ownStability,
			ownInfluence = state.match.ownInfluence,
			otherClasses = state.match.otherClasses,
			onSubmitActions = goToEnd,
		}) or currentScreen == "End" and React.createElement(EndScreen, {
			result = state.final.result,
			winners = state.final.winners,
			finalScores = state.final.finalScores,
			onReturnToLobby = goToLobby,
		}) or currentScreen == "Gallery" and React.createElement(GalleryScreen, {
			onClose = goToLobby,
		}) or nil,
		DevKeys = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0, 0),
		}, {}),
	})
end

return App
