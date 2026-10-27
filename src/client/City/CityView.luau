--!strict
-- CityView: the 3D half of the match screen. It owns one ViewportFrame, a
-- WorldModel, the four class districts and one LineVisual per production line.
-- The only input is the PlayerView; the city never reads MatchState, never
-- changes gameplay and never decides what a player may see.
--
-- CityLayout turns the view into plot positions. This class turns that plan
-- into Instances and keeps them in step: a new line appears, a removed line
-- disappears, and an owner/type change replaces the building. M11-T2 will add
-- the Reveal animations on top of this model; M11-T3 owns the camera/lighting
-- budget.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Tokens = require(script.Parent.Parent.UI.Theme.Tokens)
local CityLayout = require(script.Parent.CityLayout)
local LineVisual = require(script.Parent.LineVisual)

type ClassId = Types.ClassId
type PlayerView = Types.PlayerView
type Theme = Tokens.Theme
type Visual = LineVisual.LineVisual

local CityView = {}
CityView.__index = CityView

local function makePart(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	part.Size = size
	part.CFrame = cframe
	part.Parent = parent
	return part
end

local function districtText(theme: Theme, owner: ClassId, count: number): string
	local icon = theme.icons[owner] or string.sub(owner, 1, 1)
	return `{icon} {owner}  {count}`
end

local function makeDistrictLabel(parent: BasePart, theme: Theme, owner: ClassId): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Name = `DistrictLabel_{owner}`
	billboard.Size = UDim2.fromOffset(150, 24)
	billboard.StudsOffset = Vector3.new(0, 1.0, CityLayout.DISTRICT_SIZE / 2 - 1.5)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 120
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = theme.font.family
	label.TextSize = theme.type.s
	label.TextColor3 = theme.colors["text.primary"]
	label.TextStrokeTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = districtText(theme, owner, 0)
	label.Parent = billboard
	return label
end

function CityView.new(viewport: ViewportFrame, theme: Theme): CityView
	local world = Instance.new("WorldModel")
	world.Name = "CityWorld"
	world.Parent = viewport

	local camera = Instance.new("Camera")
	camera.Name = "CityCamera"
	camera.FieldOfView = 45
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 24, 40), Vector3.new(0, 0, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Ambient = theme.tones.state.dark
	viewport.LightColor = theme.colors["text.primary"]
	viewport.LightDirection = Vector3.new(-0.4, -1, -0.6)

	local ground = makePart(
		"Ground",
		Vector3.new(CityLayout.CITY_SIZE, 0.4, CityLayout.CITY_SIZE),
		CFrame.new(0, -0.2, 0),
		world
	)
	ground.Color = theme.tones.state.dark

	-- The two roads meet at the plaza between the four districts. They are
	-- geometry, not UI, so they stay flat and untextured like the buildings.
	local roadX =
		makePart("RoadX", Vector3.new(CityLayout.CITY_SIZE, 0.04, 2), CFrame.new(0, 0.02, 0), world)
	roadX.Color = theme.colors["line.hairline"]
	local roadZ =
		makePart("RoadZ", Vector3.new(2, 0.04, CityLayout.CITY_SIZE), CFrame.new(0, 0.02, 0), world)
	roadZ.Color = theme.colors["line.hairline"]

	local districtLabels: { [ClassId]: TextLabel? } = {}
	local empty = CityLayout.build(nil)
	for _, district in empty.districts do
		local base = makePart(
			`District_{district.owner}`,
			Vector3.new(CityLayout.DISTRICT_SIZE, 0.08, CityLayout.DISTRICT_SIZE),
			CFrame.new(district.centerX, 0.04, district.centerZ),
			world
		)
		local tone = theme.tones[string.lower(district.owner)] or theme.tones.state
		base.Color = tone.dark
		districtLabels[district.owner] = makeDistrictLabel(base, theme, district.owner)
	end

	local self = setmetatable({
		_viewport = viewport,
		_world = world,
		_camera = camera,
		_districtLabels = districtLabels,
		_visuals = {} :: { [string]: Visual? },
		_theme = theme,
	}, CityView) :: CityView
	self:sync(nil)
	return self
end

function CityView.sync(self: CityView, view: PlayerView?)
	local layout = CityLayout.build(view)

	for _, district in layout.districts do
		local label = self._districtLabels[district.owner]
		if label ~= nil then
			label.Text = districtText(self._theme, district.owner, district.count)
		end
	end

	local seen: { [string]: boolean } = {}
	for _, plot in layout.plots do
		seen[plot.lineId] = true
		local visual = self._visuals[plot.lineId]
		if visual ~= nil and not visual:matches(plot) then
			visual:destroy()
			visual = nil
		end
		if visual == nil then
			visual = LineVisual.new(self._world, plot, self._theme)
			self._visuals[plot.lineId] = visual
		end
		if visual ~= nil then
			visual:update(plot, self._theme)
		end
	end

	for lineId, visual in self._visuals do
		if visual ~= nil and not seen[lineId] then
			visual:destroy()
			self._visuals[lineId] = nil
		end
	end
end

function CityView.destroy(self: CityView)
	for _, visual in self._visuals do
		if visual ~= nil then
			visual:destroy()
		end
	end
	table.clear(self._visuals)
	self._camera:Destroy()
	self._world:Destroy()
end

export type CityView = typeof(setmetatable(
	{} :: {
		_viewport: ViewportFrame,
		_world: WorldModel,
		_camera: Camera,
		_districtLabels: { [ClassId]: TextLabel? },
		_visuals: { [string]: Visual? },
		_theme: Theme,
	},
	CityView
))

return CityView
