--!strict
-- ClassHeader composite: class icon + name + VP track.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local Primitives = require(script.Parent.Parent.Primitives)
local SegmentedTrack = require(script.Parent.SegmentedTrack)

local Surface = Primitives.Surface
local Text = Primitives.Text
local Icon = Primitives.Icon

export type ClassHeaderProps = {
	classId: string, -- "Working", "Middle", "Capitalist", "State"
	victoryPoints: number,
	maxVP: number,
	stability: number,
	layoutOrder: number?,
}

local function ClassHeader(props: ClassHeaderProps)
	local classId = props.classId
	local tone = string.lower(classId)

	return React.createElement(Surface, {
		gradientRole = "surfaceCard",
		size = UDim2.new(1, 0, 0, 80),
		layoutOrder = props.layoutOrder,
	}, {
		UIPadding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}),
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 4),
		}),
		TopRow = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 28),
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
			}),
			ClassIcon = React.createElement(Icon, {
				image = "rbxassetid://0",
				size = "lg",
				tone = tone,
			}),
			ClassName = React.createElement(Text, {
				text = classId,
				tone = tone,
				size = "lg",
				weight = "bold",
				uppercase = true,
			}),
			VPLabel = React.createElement(Text, {
				text = "VP",
				tone = "neutral",
				size = "xs",
			}),
			VPTrack = React.createElement(SegmentedTrack, {
				value = props.victoryPoints,
				max = props.maxVP,
				size = "sm",
			}),
		}),
		BottomRow = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 24),
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 16),
			}),
			StabilityLabel = React.createElement(Text, {
				text = "Stability",
				tone = "neutral",
				size = "sm",
			}),
			StabilityTrack = React.createElement(SegmentedTrack, {
				value = math.floor(props.stability / 10),
				max = 10,
				size = "sm",
			}),
			StabilityValue = React.createElement(Text, {
				text = tostring(props.stability) .. "%",
				tone = props.stability < 30 and "danger"
					or props.stability < 60 and "warning"
					or "success",
				size = "sm",
				weight = "bold",
			}),
		}),
	})
end

return ClassHeader
