--!strict
-- Surface primitive: the ONLY component that creates UIGradient.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)

export type SurfaceProps = {
	gradientRole: string, -- e.g., "surfaceCard", "surfaceRaised", "accentWorking"
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	children: React.ReactNode,
	automaticSize: Enum.AutomaticSize?,
	layoutOrder: number?,
	zIndex: number?,
	clipsDescendants: boolean?,
	backgroundTransparency: number?,
}

local function stopsToColorSequence(stops: { { t: number, color: Color3 } }): ColorSequence
	local keypoints = {}
	for _, stop in ipairs(stops) do
		table.insert(keypoints, ColorSequenceKeypoint.new(stop.t, stop.color))
	end
	return ColorSequence.new(keypoints)
end

local function stopsToNumberSequence(stops: { { t: number, v: number } }): NumberSequence
	local keypoints = {}
	for _, stop in ipairs(stops) do
		table.insert(keypoints, NumberSequenceKeypoint.new(stop.t, stop.v))
	end
	return NumberSequence.new(keypoints)
end

local function Surface(props: SurfaceProps)
	local theme = ThemeContext.useTheme()
	local gradientSpec = theme.getGradient(props.gradientRole)

	return React.createElement("Frame", {
		Size = props.size or UDim2.fromScale(1, 1),
		AutomaticSize = props.automaticSize,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = Color3.new(1, 1, 1), -- White so gradient shows through
		BackgroundTransparency = props.backgroundTransparency or 0,
		BorderSizePixel = 0,
		ClipsDescendants = props.clipsDescendants or false,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, {
		UIGradient = React.createElement("UIGradient", {
			Color = stopsToColorSequence(gradientSpec.stops),
			Rotation = gradientSpec.rotation,
			Transparency = gradientSpec.transparency and stopsToNumberSequence(
				gradientSpec.transparency
			) or nil,
		}),
		Children = React.createElement(React.Fragment, nil, props.children),
	})
end

return Surface
