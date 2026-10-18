--!strict
-- TrackSegment primitive: a single segment in a segmented track (like a board game score track).

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local Surface = require(script.Parent.Surface)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)

export type TrackSegmentProps = {
	filled: boolean,
	state: "normal" | "warning" | "danger"?, -- affects gradient
	size: string?, -- "sm", "md", "lg"
	layoutOrder: number?,
}

local function TrackSegment(props: TrackSegmentProps)
	local theme = ThemeContext.useTheme()
	local size = props.size or "md"
	local state = props.state or "normal"

	local segmentSize = size == "sm" and UDim2.fromOffset(12, 12)
		or size == "md" and UDim2.fromOffset(20, 20)
		or UDim2.fromOffset(28, 28)

	local gradientRole = props.filled
			and (state == "warning" and "meterWarning" or state == "danger" and "meterDanger" or "meterFill")
		or "surfaceInset"

	return React.createElement(Surface, {
		gradientRole = gradientRole,
		size = segmentSize,
		layoutOrder = props.layoutOrder,
	}, {
		UIStroke = React.createElement("UIStroke", {
			Color = theme.tokens.border.color,
			Thickness = theme.tokens.border.hairline,
			Transparency = props.filled and 0.5 or 0,
		}),
	})
end

return TrackSegment
