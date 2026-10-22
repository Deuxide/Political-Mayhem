--!strict
-- SegmentedTrack: a discrete track, like a score track on a board
-- (UI_STYLE section 1.1). Stability, VP, Influence and the Day progress all
-- use it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)
local Surface = require(script.Parent.Parent.Primitives.Surface)

export type TrackTone = "fill" | "warning" | "danger"
export type TrackSize = "s" | "m"

export type SegmentedTrackComponent = (SegmentedTrackProps) -> any

export type SegmentedTrackProps = {
	value: number,
	max: number,
	segments: number?,
	tone: TrackTone?,
	size: TrackSize?,
}

local SegmentedTrack = {}

function SegmentedTrack.render(props: SegmentedTrackProps): any
	local theme = ThemeContext.useTheme()
	local max = if props.max > 0 then props.max else 1
	local segments = props.segments or 10
	local filled = math.clamp(math.floor((props.value / max) * segments), 0, segments)
	local height = if props.size == "s" then 6 else 10
	local gap = theme.spacing.xs
	local width = (100 - gap * (segments - 1)) / segments

	local cells: { any } = {}
	for index = 1, segments do
		local on = index <= filled
		table.insert(
			cells,
			React.createElement(Surface.render, {
				gradient = if on then "meter." .. (props.tone or "fill") else "surface.inset",
				size = UDim2.fromScale(width / 100, 1),
				position = UDim2.fromScale(((index - 1) * (width + gap)) / 100, 0),
			})
		)
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
	}, cells)
end

return SegmentedTrack
