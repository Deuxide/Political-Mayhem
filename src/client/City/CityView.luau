--!strict
-- CityView: the 3D half of the match screen. It owns one ViewportFrame, a
-- WorldModel, the four class districts and one LineVisual per production line.
-- The only input is the PlayerView; the city never reads MatchState, never
-- changes gameplay and never decides what a player may see.
--
-- CityLayout turns the view into plot positions. This class turns that plan
-- into Instances and keeps them in step: a new line appears, a removed line
-- disappears, and an owner/type change replaces the building. M11-T2 adds the
-- Reveal animations through CityAnimator; M11-T3 ties the camera and the
-- day/dusk/night lighting to the phase clock.
--
-- Performance budget: one ViewportFrame, one WorldModel and one Camera; four
-- district bases and four 3D signs (~70 parts); one Model per line (at most six
-- parts); a phase change runs two tweens and nothing runs per frame. Twenty
-- lines stay well under 250 parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Tokens = require(script.Parent.Parent.UI.Theme.Tokens)
local CityLayout = require(script.Parent.CityLayout)
local LineVisual = require(script.Parent.LineVisual)
local CityAnimator = require(script.Parent.CityAnimator)
local RevealEvents = require(script.Parent.Parent.State.RevealEvents)

type ClassId = Types.ClassId
type Phase = Types.Phase
type PlayerView = Types.PlayerView
type Theme = Tokens.Theme
type Visual = LineVisual.LineVisual
type CityEvent = RevealEvents.CityEvent

type PhaseLook = {
	ambient: Color3,
	lightColor: Color3,
	lightDirection: Vector3,
	camera: CFrame,
	fieldOfView: number,
}

local CityView = {}
CityView.__index = CityView

-- The 5x7 block letters above each district use the same W/M/C/S initials as
-- the theme icon set. A ViewportFrame does not render BillboardGui/SurfaceGui
-- (verified in Studio), so the owner mark is real 3D geometry.
local LETTERS: { [ClassId]: { string } } = {
	Working = {
		"#...#",
		"#...#",
		"#...#",
		"#.#.#",
		"#.#.#",
		"##.##",
		"#...#",
	},
	Middle = {
		"#...#",
		"##.##",
		"#.#.#",
		"#...#",
		"#...#",
		"#...#",
		"#...#",
	},
	Capitalist = {
		".###.",
		"#...#",
		"#....",
		"#....",
		"#....",
		"#...#",
		".###.",
	},
	State = {
		".####",
		"#....",
		"#....",
		".###.",
		"....#",
		"....#",
		"####.",
	},
}

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

local function makeDistrictSign(
	parent: Instance,
	theme: Theme,
	owner: ClassId,
	x: number,
	z: number
)
	local tone = theme.tones[string.lower(owner)] or theme.tones.state
	local model = Instance.new("Model")
	model.Name = `DistrictSign_{owner}`
	model.Parent = parent

	local plaque = makePart("Plaque", Vector3.new(2.6, 3.2, 0.12), CFrame.new(x, 5.4, z), model)
	plaque.Color = tone.dark

	local bitmap = LETTERS[owner]
	for row = 1, 7 do
		local line = bitmap[row]
		for column = 1, 5 do
			if string.sub(line, column, column) == "#" then
				local block = makePart(
					"Mark",
					Vector3.new(0.28, 0.28, 0.1),
					CFrame.new(x + (column - 3) * 0.32, 5.4 + (4 - row) * 0.32, z + 0.11),
					model
				)
				block.Color = tone.light
			end
		end
	end
end

-- Day, dusk and night are presentation only; the phase clock decides when each
-- look is active. The colours come from the theme, never raw values.
local function lookFor(theme: Theme, phase: Phase): PhaseLook
	if phase == "Resolve" then
		return {
			ambient = theme.tones.warning.dark,
			lightColor = theme.tones.warning.light,
			lightDirection = Vector3.new(-1, -0.55, -0.3),
			camera = CFrame.lookAt(Vector3.new(0, 20, 34), Vector3.new(0, 0, 0)),
			fieldOfView = 42,
		}
	elseif phase == "Reveal" then
		return {
			ambient = theme.tones.state.dark,
			lightColor = theme.tones.capitalist.light,
			lightDirection = Vector3.new(0.35, -0.8, -0.45),
			camera = CFrame.lookAt(Vector3.new(0, 27, 43), Vector3.new(0, 0, 0)),
			fieldOfView = 46,
		}
	end
	return {
		ambient = theme.tones.state.base,
		lightColor = theme.colors["text.primary"],
		lightDirection = Vector3.new(-0.4, -1, -0.6),
		camera = CFrame.lookAt(Vector3.new(0, 24, 40), Vector3.new(0, 0, 0)),
		fieldOfView = 45,
	}
end

function CityView.new(viewport: ViewportFrame, theme: Theme): CityView
	local world = Instance.new("WorldModel")
	world.Name = "CityWorld"
	world.Parent = viewport

	local windowLook = lookFor(theme, "Window")
	local camera = Instance.new("Camera")
	camera.Name = "CityCamera"
	camera.FieldOfView = windowLook.fieldOfView
	camera.CFrame = windowLook.camera
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Ambient = windowLook.ambient
	viewport.LightColor = windowLook.lightColor
	viewport.LightDirection = windowLook.lightDirection
	viewport:SetAttribute("CityPhase", "Window")

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

	local districtBases: { [ClassId]: BasePart? } = {}
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
		districtBases[district.owner] = base
		makeDistrictSign(world, theme, district.owner, district.centerX, district.centerZ)
	end

	local self = setmetatable({
		_viewport = viewport,
		_world = world,
		_camera = camera,
		_visuals = {} :: { [string]: Visual? },
		_districtBases = districtBases,
		_animator = CityAnimator.new(theme),
		_pendingNewBuilds = {} :: { [string]: CityEvent },
		_lastRevealDay = -1,
		_phase = "Window" :: Phase,
		_phaseTweens = {} :: { Tween },
		_theme = theme,
	}, CityView) :: CityView
	self:sync(nil)
	return self
end

-- The phase clock is the server's, not a client timer. Window is day, Resolve is
-- dusk and Reveal is night; the camera also settles slightly wider at night.
-- The phase effect in CityViewport calls this only when the phase changes.
function CityView.setPhase(self: CityView, phase: Phase, day: number?)
	self._viewport:SetAttribute("CityPhase", phase)
	if day ~= nil then
		self._viewport:SetAttribute("CityDay", day)
	end
	if self._phase == phase then
		return
	end
	self._phase = phase

	for _, tween in self._phaseTweens do
		tween:Cancel()
	end
	table.clear(self._phaseTweens)

	local look = lookFor(self._theme, phase)
	if self._theme.motion.reduced then
		self._viewport.Ambient = look.ambient
		self._viewport.LightColor = look.lightColor
		self._viewport.LightDirection = look.lightDirection
		self._camera.CFrame = look.camera
		self._camera.FieldOfView = look.fieldOfView
		return
	end

	local info =
		TweenInfo.new(self._theme.motion.slow, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local viewportTween = TweenService:Create(self._viewport, info, {
		Ambient = look.ambient,
		LightColor = look.lightColor,
		LightDirection = look.lightDirection,
	})
	local cameraTween = TweenService:Create(self._camera, info, {
		CFrame = look.camera,
		FieldOfView = look.fieldOfView,
	})
	table.insert(self._phaseTweens, viewportTween)
	table.insert(self._phaseTweens, cameraTween)
	viewportTween:Play()
	cameraTween:Play()
end

function CityView.sync(self: CityView, view: PlayerView?)
	local layout = CityLayout.build(view)
	local seen: { [string]: boolean } = {}
	for _, plot in layout.plots do
		seen[plot.lineId] = true
		local visual = self._visuals[plot.lineId]
		if visual ~= nil and not visual:matches(plot) then
			visual:destroy()
			visual = nil
		end
		local created = false
		if visual == nil then
			visual = LineVisual.new(self._world, plot, self._theme)
			self._visuals[plot.lineId] = visual
			created = true
		end
		if visual ~= nil then
			visual:update(plot, self._theme)
			local pending = self._pendingNewBuilds[plot.lineId]
			if created and pending ~= nil then
				self._pendingNewBuilds[plot.lineId] = nil
				self._animator:playLine(pending, visual)
			end
		end
	end

	for lineId, visual in self._visuals do
		if visual ~= nil and not seen[lineId] then
			visual:destroy()
			self._visuals[lineId] = nil
		end
	end
end

-- One Reveal report per Day. A report can arrive just before the view snapshot
-- (the server sends Reveal_Report first), so a NewBuild whose line is not in
-- the view yet is parked and played when sync creates it; the Day guard keeps
-- the other events from replaying when the snapshot re-renders the city.
function CityView.playReveal(self: CityView, events: { CityEvent }, day: number)
	if self._lastRevealDay == day then
		return
	end
	self._lastRevealDay = day
	table.clear(self._pendingNewBuilds)

	for _, event in events do
		if event.kind == "NewBuild" then
			local lineId = event.lineId
			if lineId ~= nil then
				local visual = self._visuals[lineId]
				if visual ~= nil then
					self._animator:playLine(event, visual)
				else
					self._pendingNewBuilds[lineId] = event
				end
			end
		elseif event.kind == "Production" then
			local lineId = event.lineId
			if lineId ~= nil then
				local visual = self._visuals[lineId]
				if visual ~= nil then
					self._animator:playLine(event, visual)
				end
			end
		elseif event.kind == "Strike" then
			local target: ClassId? = event.target
			if target ~= nil then
				for _, visual in self._visuals do
					if visual ~= nil and visual:owner() == target then
						self._animator:playLine(event, visual)
					end
				end
				local district = self._districtBases[target]
				if district ~= nil then
					self._animator:markDistrict(event, district)
				end
			end
		elseif event.kind == "Protest" then
			local actor: ClassId? = event.actor
			if actor ~= nil then
				local district = self._districtBases[actor]
				if district ~= nil then
					self._animator:playProtest(event, district)
				end
			end
		end
	end
end

function CityView.destroy(self: CityView)
	for _, tween in self._phaseTweens do
		tween:Cancel()
	end
	table.clear(self._phaseTweens)
	self._animator:destroy()
	for _, visual in self._visuals do
		if visual ~= nil then
			visual:destroy()
		end
	end
	table.clear(self._visuals)
	table.clear(self._pendingNewBuilds)
	self._camera:Destroy()
	self._world:Destroy()
end

export type CityView = typeof(setmetatable(
	{} :: {
		_viewport: ViewportFrame,
		_world: WorldModel,
		_camera: Camera,
		_visuals: { [string]: Visual? },
		_districtBases: { [ClassId]: BasePart? },
		_animator: CityAnimator.CityAnimator,
		_pendingNewBuilds: { [string]: CityEvent },
		_lastRevealDay: number,
		_phase: Phase,
		_phaseTweens: { Tween },
		_theme: Theme,
	},
	CityView
))

return CityView
