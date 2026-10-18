--!strict
-- Tooltip composite: hover tooltip using Surface.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local Primitives = require(script.Parent.Primitives)

local Surface = Primitives.Surface
local Text = Primitives.Text

export type TooltipProps = {
	text: string,
	visible: boolean,
	position: UDim2?, -- position relative to parent
	size: UDim2?,
	layoutOrder: number?,
}

local function Tooltip(props: TooltipProps)
	if not props.visible then return nil end

	return React.createElement(Surface, {
		gradientRole = "surfaceInset",
		size = props.size or UDim2.fromOffset(200, 0),
		position = props.position or UDim2.fromScale(0.5, 0),
		anchorPoint = Vector2.new(0.5, 1),
		automaticSize = Enum.AutomaticSize.Y,
		zIndex = 200,
		layoutOrder = props.layoutOrder,
	}, {
		UIPadding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		}),
		Text = React.createElement(Text, {
			text = props.text,
			tone = "neutral",
			size = "sm",
		}),
	})
end

return Tooltip
