--!strict
-- LineVisual: the 3D building for one production line. A line type picks the
-- silhouette (a low farm, a chimneyed factory, a cross-marked clinic, a roofed
-- school); the owner's class tone carries ownership. The type icon is drawn
-- above the building too, so meaning never relies on color alone.
--
-- This is a view object: it owns Instances and its lifecycle, but it never
-- reads MatchState or changes gameplay. CityView creates, updates and destroys
-- it; the data it receives is a CityLayout plot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Tokens = require(script.Parent.Parent.UI.Theme.Tokens)
local CityLayout = require(script.Parent.CityLayout)

type ClassId = Types.ClassId
type Plot = CityLayout.Plot
type Theme = Tokens.Theme
type Tone = Tokens.Tone

local LineVisual = {}
LineVisual.__index = LineVisual

local function toneFor(theme: Theme, owner: ClassId): Tone
	return theme.tones[string.lower(owner)] or theme.tones.state
end

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

local function makeLabel(parent: BasePart, theme: Theme, height: number): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LineLabel"
	billboard.Size = UDim2.fromOffset(40, 22)
	billboard.StudsOffset = Vector3.new(0, height + 0.8, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 100
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "TypeIcon"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = theme.font.family
	label.TextSize = theme.type.xs
	label.TextColor3 = theme.colors["text.primary"]
	label.TextStrokeTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = billboard
	return label
end

local function buildFarm(model: Model, tone: Tone, accent: { BasePart }): (BasePart, number)
	local body = makePart("Farm", Vector3.new(2.4, 0.5, 2.4), CFrame.new(0, 0.35, 0), model)
	body.Color = tone.base
	for row = -1, 1 do
		local crop = makePart(
			`Crop{row + 2}`,
			Vector3.new(2.0, 0.08, 0.35),
			CFrame.new(0, 0.63, row * 0.65),
			model
		)
		crop.Color = tone.light
		table.insert(accent, crop)
	end
	return body, 1.2
end

local function buildFactory(model: Model, tone: Tone, accent: { BasePart }): (BasePart, number)
	local body = makePart("Factory", Vector3.new(2.4, 2.4, 2.4), CFrame.new(0, 1.3, 0), model)
	body.Color = tone.base
	local roof = makePart("Roof", Vector3.new(2.6, 0.18, 2.6), CFrame.new(0, 2.58, 0), model)
	roof.Color = tone.light
	table.insert(accent, roof)

	local chimney = makePart(
		"Chimney",
		Vector3.new(1.2, 0.5, 0.5),
		CFrame.new(0.65, 3.3, 0.55) * CFrame.Angles(0, 0, math.rad(90)),
		model
	)
	chimney.Color = tone.dark
	table.insert(accent, chimney)
	return body, 3.8
end

local function buildClinic(
	model: Model,
	theme: Theme,
	tone: Tone,
	accent: { BasePart },
	health: { BasePart }
): (BasePart, number)
	local body = makePart("Clinic", Vector3.new(2.4, 1.8, 2.4), CFrame.new(0, 1.0, 0), model)
	body.Color = tone.base
	local roof = makePart("Roof", Vector3.new(2.6, 0.18, 2.6), CFrame.new(0, 1.98, 0), model)
	roof.Color = tone.light
	table.insert(accent, roof)

	-- A cross on the front face (the camera looks from +Z).
	local vertical =
		makePart("CrossVertical", Vector3.new(0.2, 0.9, 0.06), CFrame.new(0, 1.0, 1.23), model)
	local horizontal =
		makePart("CrossHorizontal", Vector3.new(0.9, 0.2, 0.06), CFrame.new(0, 1.0, 1.23), model)
	for _, part in { vertical, horizontal } do
		part.Color = theme.colors["state.success"]
		table.insert(health, part)
	end
	return body, 2.8
end

local function buildSchool(model: Model, tone: Tone, accent: { BasePart }): (BasePart, number)
	local body = makePart("School", Vector3.new(2.4, 2.0, 2.4), CFrame.new(0, 1.1, 0), model)
	body.Color = tone.base
	local roof = makePart("Roof", Vector3.new(2.8, 0.2, 2.8), CFrame.new(0, 2.2, 0), model)
	roof.Color = tone.light
	table.insert(accent, roof)
	return body, 3.0
end

function LineVisual.new(parent: Instance, plot: Plot, theme: Theme): LineVisual
	local tone = toneFor(theme, plot.owner)
	local model = Instance.new("Model")
	model.Name = `Line_{plot.lineId}`
	model.Parent = parent

	local plotPart = makePart("Plot", Vector3.new(3.0, 0.12, 3.0), CFrame.new(0, 0.06, 0), model)
	plotPart.Color = tone.dark

	local accent: { BasePart } = {}
	local health: { BasePart } = {}
	local body: BasePart
	local height: number
	if plot.lineType == "Farm" then
		body, height = buildFarm(model, tone, accent)
	elseif plot.lineType == "Factory" then
		body, height = buildFactory(model, tone, accent)
	elseif plot.lineType == "Clinic" then
		body, height = buildClinic(model, theme, tone, accent, health)
	else
		body, height = buildSchool(model, tone, accent)
	end

	local label = makeLabel(body, theme, height)
	model.WorldPivot = CFrame.new(0, 0, 0)

	local self = setmetatable({
		_model = model,
		_plot = plot,
		_plotPart = plotPart,
		_toneParts = { body },
		_accentParts = accent,
		_healthParts = health,
		_label = label,
	}, LineVisual) :: LineVisual
	self:update(plot, theme)
	return self
end

-- A changed line type or owner means different geometry, not a recolor; the
-- caller replaces the visual instead.
function LineVisual.matches(self: LineVisual, plot: Plot): boolean
	return self._plot.lineType == plot.lineType and self._plot.owner == plot.owner
end

function LineVisual.update(self: LineVisual, plot: Plot, theme: Theme)
	self._plot = plot
	self._model:PivotTo(CFrame.new(plot.x, 0, plot.z))

	local tone = toneFor(theme, plot.owner)
	for _, part in self._toneParts do
		part.Color = tone.base
	end
	self._plotPart.Color = tone.dark
	for _, part in self._accentParts do
		part.Color = tone.light
	end
	for _, part in self._healthParts do
		part.Color = theme.colors["state.success"]
	end
	self._label.Text = theme.icons[plot.lineType] or string.sub(plot.lineType, 1, 1)
end

function LineVisual.destroy(self: LineVisual)
	self._model:Destroy()
end

export type LineVisual = typeof(setmetatable(
	{} :: {
		_model: Model,
		_plot: Plot,
		_plotPart: Part,
		_toneParts: { BasePart },
		_accentParts: { BasePart },
		_healthParts: { BasePart },
		_label: TextLabel,
	},
	LineVisual
))

return LineVisual
