--!strict
-- Client entry point. It creates the store, connects the net client, and
-- mounts the app shell (M7-T2). The design-system Gallery stays available as
-- a dev screen (M7-T0): it is mounted in its own ScreenGui, which is off by
-- default and can be switched on while the game runs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Required through the Wally shims (Packages/react, Packages/react-roblox):
-- their values are fully typed, but the react module's `export type` names
-- (React.Element, ...) are not visible to luau-lsp through the shim, so typed
-- element types come from inference. If type aliases are ever needed, M7-T0
-- should add one re-export module that requires the _Index paths directly.
local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages["react-roblox"])
-- Lives under this LocalScript (src/client/UI/Dev) because it is a dev tool;
-- the config/game modules live in ReplicatedStorage.
local ChildrenGuard = require(script.UI.Dev.ChildrenGuard)
local Store = require(script.State.Store)
local Client = require(script.Net.Client)
local App = require(script.UI.App)
local ThemeContext = require(script.UI.Theme.ThemeContext)
local DefaultSkin = require(script.UI.Theme.Skins.Default)
local Gallery = require(script.UI.Gallery.Gallery)

-- Dev-time guard for react-lua issue #42 (D-031): wraps createElement and
-- warns, with the call site, about forbidden children patterns. Studio only —
-- it must never reach a live client. Installed before the first createElement
-- so every call site in this file is covered.
if RunService:IsStudio() then
	ChildrenGuard.install(React)
end

local store = Store.new()
local client = Client.new(store)
Client.connect(client)

-- The game screen.
local appGui = Instance.new("ScreenGui")
appGui.Name = "AppScreenGui"
appGui.ResetOnSpawn = false
appGui.IgnoreGuiInset = true
appGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
appGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local appRoot = ReactRoblox.createRoot(appGui)
appRoot:render(React.createElement(
	ThemeContext.provider,
	{
		value = DefaultSkin,
	},
	React.createElement(App.render, {
		store = store,
		onDraft = function(draft)
			Client.queueDraft(client, draft)
		end,
		onProposeBill = function(requestId, policyId, level)
			Client.proposeBill(client, requestId, policyId, level)
		end,
		onProposeTrade = function(requestId, to, give, want, promises)
			Client.proposeTrade(client, requestId, to, give, want, promises)
		end,
		onRespondTrade = function(offerId, accept)
			Client.respondTrade(client, offerId, accept)
		end,
		onCancelTrade = function(offerId)
			Client.cancelTrade(client, offerId)
		end,
		onProposeAlliance = function(to)
			Client.proposeAlliance(client, to)
		end,
		onRespondAlliance = function(from, accept)
			Client.respondAlliance(client, from, accept)
		end,
		onBreakAlliance = function()
			Client.breakAlliance(client)
		end,
		onSendChat = function(channel, text, classTo)
			Client.sendChat(client, channel, text, classTo)
		end,
	})
))

-- The dev Gallery (M7-T0): off by default, so it never covers the game.
local galleryGui = Instance.new("ScreenGui")
galleryGui.Name = "GalleryScreenGui"
galleryGui.ResetOnSpawn = false
galleryGui.Enabled = false
galleryGui.IgnoreGuiInset = true
galleryGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
galleryGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local galleryRoot = ReactRoblox.createRoot(galleryGui)
galleryRoot:render(React.createElement(Gallery.render))
