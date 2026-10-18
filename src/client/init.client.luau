--!strict
-- Client entry point: mounts the React root.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages["react-roblox"])

print("[UI] Client UI startup")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PoliticalMayhemUI"
screenGui.Enabled = true
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

print(
	"[UI] ScreenGui parented:",
	screenGui.Parent == playerGui,
	"enabled:",
	screenGui.Enabled,
	screenGui:GetFullName()
)

local root = ReactRoblox.createRoot(screenGui)
print("[UI] React root created:", screenGui:GetFullName())

local App = require(script.UI.App)
local appElement = React.createElement(App)
print("[UI] Rendering App element")
root:render(appElement)
print("[UI] App render submitted")

print("Client booted")
