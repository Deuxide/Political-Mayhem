--!strict
-- Client entry point. The M0 scaffold is gone: the client now mounts the
-- design-system Gallery, the dev screen that shows every component in every
-- state (UI_STYLE section 4.1). The game screens (the lobby, the match HUD)
-- arrive with M7-T2 and the client networking with M7-T1.

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
local Gallery = require(script.UI.Gallery.Gallery)

-- Dev-time guard for react-lua issue #42 (D-031): wraps createElement and
-- warns, with the call site, about forbidden children patterns. Studio only —
-- it must never reach a live client. Installed before the first createElement
-- so every call site in this file is covered.
if RunService:IsStudio() then
	ChildrenGuard.install(React)
end

local galleryGui = Instance.new("ScreenGui")
galleryGui.Name = "GalleryScreenGui"
galleryGui.ResetOnSpawn = false
galleryGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local root = ReactRoblox.createRoot(galleryGui)
root:render(React.createElement(Gallery.render))
