--!strict
-- SegmentedTrack composite: multiple TrackSegments in a row.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local Primitives = require(script.Parent.Primitives)

local TrackSegment = Primitives.TrackSegment
local Text = Primitives.Text

export type SegmentedTrackProps = {
	value: number, -- current value (0 to max)
	max: number, -- number of segments
	size: string?, -- "sm", "md", "lg"
	showLabels: boolean?,
	warningThreshold: number?, -- segment index where warning starts
	dangerThreshold: number?, -- segment index where danger starts
	layoutOrder: number?,
}

local function SegmentedTrack(props: SegmentedTrackProps)
	local size = props.size or "md"
	local segments = {}

	for i = 1, props.max do
		local filled = i <= props.value
		local state = "normal"
		if props.dangerThreshold and i >= props.dangerThreshold then
			state = "danger"
		elseif props.warningThreshold and i >= props.warningThreshold then
			state = "warning"
		end

		table.insert(
			segments,
			React.createElement(TrackSegment, {
				filled = filled,
				state = state,
				size = size,
				layoutOrder = i,
			})
		)
	end

	local children = {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 2),
		}),
	}

	for _, seg in ipairs(segments) do
		table.insert(children, seg)
	end

	if props.showLabels then
		table.insert(
			children,
			React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 16),
				LayoutOrder = 100,
			}, {
				UIListLayout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, 2),
				}),
				Labels = React.createElement(Text, {
					text = props.value .. " / " .. props.max,
					size = "xs",
					tone = "neutral",
				}),
			})
		)
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = props.layoutOrder,
	}, children)
end

return SegmentedTrack
