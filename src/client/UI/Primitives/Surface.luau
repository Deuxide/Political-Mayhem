--!strict
-- Surface: the primitive every filled element is built on. It is the only
-- component that creates a UIGradient (UI_STYLE section 2) — the others ask
-- for a gradient role and hand it over.
--
-- Props are semantic (a gradient role, a color role) plus the layout the
-- parent controls; there is no color, font or pixel prop here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)

export type SurfaceComponent = (SurfaceProps) -> any

export type SurfaceProps = {
	gradient: string?, -- a gradient role of the skin
	color: string?, -- a color role of the skin
	children: any?,
	position: UDim2?,
	size: UDim2?,
	anchorPoint: Vector2?,
	backgroundTransparency: number?,
	borderSize: number?,
	borderColor: string?,
	zIndex: number?,
	visible: boolean?,
	layoutOrder: number?,
	hovered: boolean?, -- the hover state lightens the top stop
	pressed: boolean?, -- the pressed state reverses the direction
}

local Surface = {}

function Surface.render(props: SurfaceProps): any
	local theme = ThemeContext.useTheme()

	local frameProps: { [any]: any } = {
		Position = props.position or UDim2.fromOffset(0, 0),
		Size = props.size or UDim2.fromScale(1, 1),
		BackgroundTransparency = props.backgroundTransparency or 0,
		BorderSizePixel = props.borderSize or 0,
		ZIndex = props.zIndex or 1,
		Visible = props.visible ~= false,
	}
	if props.anchorPoint ~= nil then
		frameProps.AnchorPoint = props.anchorPoint
	end
	if props.layoutOrder ~= nil then
		frameProps.LayoutOrder = props.layoutOrder
	end
	if props.color ~= nil then
		frameProps.BackgroundColor3 = theme.colors[props.color]
	end
	if props.borderColor ~= nil then
		frameProps.BorderColor3 = theme.colors[props.borderColor]
	end

	-- The children travel in a Fragment, never as a raw table inside another
	-- children table (react-lua issue #42).
	local content = React.createElement(React.Fragment, nil, props.children)

	if props.gradient == nil then
		return React.createElement("Frame", frameProps, content)
	end

	-- A gradient needs a white base; the gradient carries the color.
	frameProps.BackgroundColor3 = Color3.new(1, 1, 1)
	local spec = theme.gradients[props.gradient]
	local keys = {}
	for index, stop in spec.stops do
		local color = stop.color
		if index == 1 and props.hovered == true then
			-- hover: lighten the top stop
			color = color:Lerp(Color3.new(1, 1, 1), 0.08)
		end
		table.insert(keys, ColorSequenceKeypoint.new(stop.t, color))
	end
	local gradientProps: { [any]: any } = {
		Color = ColorSequence.new(keys),
		Rotation = if props.pressed == true then spec.rotation + 180 else spec.rotation,
	}
	if spec.transparency ~= nil then
		local stops = {}
		for _, stop in spec.transparency do
			table.insert(stops, NumberSequenceKeypoint.new(stop.t, stop.v))
		end
		gradientProps.Transparency = NumberSequence.new(stops)
	end
	local gradient = React.createElement("UIGradient", gradientProps)
	return React.createElement("Frame", frameProps, gradient, content)
end

return Surface
