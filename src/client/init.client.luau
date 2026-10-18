--!strict
-- Client entry point: mounts the React root.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ReactRoblox = require(ReplicatedStorage.Packages["react-roblox"])
local React = require(ReplicatedStorage.Packages.react)
local App = require(script.UI.App)

local root = ReactRoblox.createRoot(Players.LocalPlayer.PlayerGui)
root:render(React.createElement(App))

print("Client booted")
