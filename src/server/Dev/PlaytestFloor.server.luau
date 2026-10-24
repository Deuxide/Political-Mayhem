--!strict
-- Temporary playtest floor (M7): the city world is M11, so until then the
-- character would fall into the void and respawn forever during Studio
-- checks. This script puts a small anchored platform and a neutral spawn at
-- the origin. Delete this file when the real city is built.

local Workspace = game:GetService("Workspace")

local PLATFORM_SIZE = Vector3.new(64, 2, 64)
local SPAWN_SIZE = Vector3.new(12, 1, 12)
local PLATFORM_TOP = 0

local function clear(name: string)
	local existing = Workspace:FindFirstChild(name)
	if existing ~= nil then
		existing:Destroy()
	end
end

clear("PlaytestFloor")
clear("PlaytestSpawn")

local floor = Instance.new("Part")
floor.Name = "PlaytestFloor"
floor.Anchored = true
floor.CanCollide = true
floor.Size = PLATFORM_SIZE
floor.Position = Vector3.new(0, PLATFORM_TOP - PLATFORM_SIZE.Y / 2, 0)
floor.Material = Enum.Material.SmoothPlastic
floor.Color = Color3.fromRGB(52, 57, 66)
floor.TopSurface = Enum.SurfaceType.Smooth
floor.BottomSurface = Enum.SurfaceType.Smooth
floor.CastShadow = false
floor.Parent = Workspace

local spawn = Instance.new("SpawnLocation")
spawn.Name = "PlaytestSpawn"
spawn.Anchored = true
spawn.CanCollide = true
spawn.Size = SPAWN_SIZE
spawn.Position = Vector3.new(0, PLATFORM_TOP + SPAWN_SIZE.Y / 2, 0)
spawn.Neutral = true
spawn.Duration = 0
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.Material = Enum.Material.SmoothPlastic
spawn.Color = Color3.fromRGB(72, 78, 90)
spawn.CastShadow = false
spawn.Parent = Workspace

print("[Dev] playtest floor ready")
