--!strict
-- CityAnimator: the Reveal reaction's motion layer. It turns typed CityEvents
-- (already classified from the public Evening Report) into short, cancelable
-- tweens on the existing city Instances: production hops and flashes green,
-- a strike shakes and flashes red, a protest raises red markers around the
-- affected district, and a new build rises out of the ground. It never reads
-- MatchState, never decides an outcome and never changes the view; it only
-- plays motion on what CityView already built.
--
-- Every animation is a Tween (no task loops), so it is cheap and stops with
-- the city. The event kind is also stamped on the affected model/district as
-- `CityEvent`/`CityEventDay`; that is inspection metadata for L2, not UI.

local TweenService = game:GetService("TweenService")
local Tokens = require(script.Parent.Parent.UI.Theme.Tokens)
local LineVisual = require(script.Parent.LineVisual)
local RevealEvents = require(script.Parent.Parent.State.RevealEvents)

type Theme = Tokens.Theme
type Visual = LineVisual.LineVisual
type CityEvent = RevealEvents.CityEvent

local CityAnimator = {}
CityAnimator.__index = CityAnimator

local PRODUCTION_HOP = 0.7
local PRODUCTION_TIME = 0.3
local STRIKE_SHAKE = 0.4
local STRIKE_STEP = 0.1
local NEW_BUILD_DROP = 3
local NEW_BUILD_TIME = 1.4
local FLASH_TIME = 1.0
local PROTEST_TIME = 2.5

local function makeMarker(theme: Theme): Part
	local marker = Instance.new("Part")
	marker.Name = "ProtestMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Material = Enum.Material.SmoothPlastic
	marker.Size = Vector3.new(0.45, 0.45, 0.45)
	marker.Color = theme.tones.danger.light
	marker.Transparency = 0.1
	return marker
end

function CityAnimator.new(theme: Theme): CityAnimator
	return setmetatable({
		_theme = theme,
		_destroyed = false,
		_tweens = {} :: { Tween },
		_connections = {} :: { RBXScriptConnection },
		_values = {} :: { Instance },
	}, CityAnimator) :: CityAnimator
end

function CityAnimator._play(self: CityAnimator, tween: Tween)
	if self._destroyed then
		return
	end
	table.insert(self._tweens, tween)
	tween:Play()
end

function CityAnimator._flashPart(
	self: CityAnimator,
	part: BasePart,
	color: Color3,
	duration: number
)
	local original = part.Color
	local half = duration / 2
	local to = TweenService:Create(
		part,
		TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Color = color }
	)
	local back = TweenService:Create(
		part,
		TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Color = original }
	)
	to.Completed:Once(function()
		self:_play(back)
	end)
	self:_play(to)
end

function CityAnimator._flashParts(
	self: CityAnimator,
	parts: { BasePart },
	color: Color3,
	duration: number
)
	for _, part in parts do
		self:_flashPart(part, color, duration)
	end
end

function CityAnimator._tweenModel(
	self: CityAnimator,
	model: Model,
	target: CFrame,
	duration: number,
	style: Enum.EasingStyle,
	direction: Enum.EasingDirection,
	onComplete: (() -> ())?
)
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	local connection = value:GetPropertyChangedSignal("Value"):Connect(function()
		model:PivotTo(value.Value)
	end)
	table.insert(self._values, value)
	table.insert(self._connections, connection)

	local tween = TweenService:Create(value, TweenInfo.new(duration, style, direction), {
		Value = target,
	})
	tween.Completed:Once(function()
		connection:Disconnect()
		value:Destroy()
		if not self._destroyed and onComplete ~= nil then
			onComplete()
		end
	end)
	self:_play(tween)
end

function CityAnimator._hop(self: CityAnimator, model: Model)
	local base = model:GetPivot()
	self:_tweenModel(
		model,
		base + Vector3.new(0, PRODUCTION_HOP, 0),
		PRODUCTION_TIME,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out,
		function()
			self:_tweenModel(
				model,
				base,
				PRODUCTION_TIME + 0.08,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
		end
	)
end

function CityAnimator._shake(self: CityAnimator, model: Model)
	local base = model:GetPivot()
	local offsets = { STRIKE_SHAKE, -STRIKE_SHAKE, STRIKE_SHAKE * 0.7, -STRIKE_SHAKE * 0.4, 0 }
	local index = 1
	local function step()
		if index > #offsets then
			model:PivotTo(base)
			return
		end
		local offset = offsets[index]
		index += 1
		self:_tweenModel(
			model,
			base + Vector3.new(offset, 0, 0),
			STRIKE_STEP,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out,
			step
		)
	end
	step()
end

function CityAnimator._rise(self: CityAnimator, model: Model)
	local base = model:GetPivot()
	model:PivotTo(base - Vector3.new(0, NEW_BUILD_DROP, 0))
	self:_tweenModel(model, base, NEW_BUILD_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

function CityAnimator.playLine(self: CityAnimator, event: CityEvent, visual: Visual)
	local model = visual:model()
	model:SetAttribute("CityEvent", event.kind)
	model:SetAttribute("CityEventDay", event.day)

	if event.kind == "Production" then
		self:_flashParts(visual:accentParts(), self._theme.tones.success.light, FLASH_TIME)
		self:_hop(model)
	elseif event.kind == "Strike" then
		self:_flashParts(visual:accentParts(), self._theme.tones.danger.base, FLASH_TIME)
		self:_flashPart(visual:plotPart(), self._theme.tones.danger.dark, FLASH_TIME)
		self:_shake(model)
	elseif event.kind == "NewBuild" then
		self:_flashPart(visual:plotPart(), self._theme.tones.success.base, FLASH_TIME + 0.2)
		self:_rise(model)
	end
end

function CityAnimator.playProtest(self: CityAnimator, event: CityEvent, district: BasePart)
	district:SetAttribute("CityEvent", event.kind)
	district:SetAttribute("CityEventDay", event.day)
	self:_flashPart(district, self._theme.tones.danger.base, FLASH_TIME)

	local parent = district.Parent
	if parent == nil then
		return
	end
	local offsets = {
		Vector3.new(-2.2, 0, -2.2),
		Vector3.new(2.2, 0, -1.6),
		Vector3.new(-1.4, 0, 2.2),
		Vector3.new(2.0, 0, 2.0),
	}
	for index, offset in offsets do
		local marker = makeMarker(self._theme)
		marker.Name = `ProtestMarker_{event.day}_{index}`
		marker.CFrame = CFrame.new(district.Position + offset + Vector3.new(0, 0.35, 0))
		marker.Parent = parent
		local target = marker.Position + Vector3.new(0, 2.4, 0)
		local tween = TweenService:Create(
			marker,
			TweenInfo.new(PROTEST_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = target, Transparency = 1 }
		)
		tween.Completed:Once(function()
			marker:Destroy()
		end)
		self:_play(tween)
	end
end

function CityAnimator.markDistrict(self: CityAnimator, event: CityEvent, district: BasePart)
	district:SetAttribute("CityEvent", event.kind)
	district:SetAttribute("CityEventDay", event.day)
	self:_flashPart(district, self._theme.tones.danger.dark, FLASH_TIME)
end

function CityAnimator.destroy(self: CityAnimator)
	self._destroyed = true
	for _, tween in self._tweens do
		tween:Cancel()
	end
	table.clear(self._tweens)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	for _, value in self._values do
		value:Destroy()
	end
	table.clear(self._values)
end

export type CityAnimator = typeof(setmetatable(
	{} :: {
		_theme: Theme,
		_destroyed: boolean,
		_tweens: { Tween },
		_connections: { RBXScriptConnection },
		_values: { Instance },
	},
	CityAnimator
))

return CityAnimator
