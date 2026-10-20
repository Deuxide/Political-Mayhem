--!strict
-- Client entry point. M0 scaffold only: create a placeholder ScreenGui and
-- mount a React root in it (one status label, four class corner labels). The
-- design system, screens, and Store arrive in M6/M7 (D-028); this stays the
-- smallest thing that proves React-Lua mounts and renders in Studio.

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
local Types = require(ReplicatedStorage.Shared.Game.Types)
-- Lives under this LocalScript (src/client/UI/Dev) because it is a dev tool;
-- the config/game modules live in ReplicatedStorage.
local ChildrenGuard = require(script.UI.Dev.ChildrenGuard)

-- Dev-time guard for react-lua issue #42 (D-031): wraps createElement and
-- warns, with the call site, about forbidden children patterns. Studio only —
-- it must never reach a live client. Installed before the first createElement
-- so every call site in this file is covered.
if RunService:IsStudio() then
	ChildrenGuard.install(React)
end

-- React-Lua names a host instance from its children-table key, not from a
-- `Name` prop (ReactRobloxHostConfig sets domElement.Name = key; selene
-- enforces this as roblox_incorrect_roact_usage), so every label lives under
-- the key it should be named by.
local children = {
	ScaffoldLabel = React.createElement("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 60),
		Text = "Political Mayhem: scaffold OK",
		TextSize = 28,
	}),
}

-- Corner anchors/positions in fixed order TL, TR, BR, BL. The scaffold has no
-- viewer, so the class-to-corner assignment is arbitrary; the real per-viewer
-- layout (own class always bottom-left, D-012) is built in M7-T2.
local CORNER_ANCHORS = {
	Vector2.new(0, 0),
	Vector2.new(1, 0),
	Vector2.new(1, 1),
	Vector2.new(0, 1),
}
local CORNER_POSITIONS = {
	UDim2.fromScale(0.02, 0.02),
	UDim2.fromScale(0.98, 0.02),
	UDim2.fromScale(0.98, 0.98),
	UDim2.fromScale(0.02, 0.98),
}

for index, classId in Types.CLASS_IDS do
	children[classId] = React.createElement("TextLabel", {
		AnchorPoint = CORNER_ANCHORS[index],
		Position = CORNER_POSITIONS[index],
		Size = UDim2.fromOffset(160, 40),
		Text = classId,
		TextSize = 22,
	})
end

local scaffoldGui = Instance.new("ScreenGui")
scaffoldGui.Name = "ScaffoldScreenGui"
scaffoldGui.ResetOnSpawn = false
scaffoldGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local root = ReactRoblox.createRoot(scaffoldGui)
root:render(React.createElement(React.Fragment, nil, children))
