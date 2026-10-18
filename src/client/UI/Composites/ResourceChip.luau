--!strict
-- ResourceChip composite: icon + number + delta.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local Primitives = require(script.Parent.Primitives)

local Surface = Primitives.Surface
local Text = Primitives.Text
local Icon = Primitives.Icon

export type ResourceChipProps = {
	resource: string,
	amount: number,
	delta: number?, -- +n or -n change
	tone: string?, -- class tone for accent
	size: string?, -- "sm", "md", "lg"
	layoutOrder: number?,
}

local function ResourceChip(props: ResourceChipProps)
	local tone = props.tone or "neutral"
	local size = props.size or "md"
	local iconSize = size == "sm" and 16 or size == "md" and 24 or 32
	local textSize = size == "sm" and "xs" or size == "md" and "sm" or "md"

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = props.layoutOrder,
	}, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
		}),
		Chip = React.createElement(Surface, {
			gradientRole = "surfaceRaised",
			size = UDim2.fromOffset(iconSize + 16, iconSize + 8),
		}, {
			UIPadding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 4),
			}),
			Icon = React.createElement(Icon, {
				image = "rbxassetid://0", -- placeholder
				size = size,
				tone = tone,
			}),
			Amount = React.createElement(Text, {
				text = tostring(props.amount),
				tone = tone,
				size = textSize,
				weight = "bold",
			}),
		}),
		Delta = props.delta and props.delta ~= 0 and React.createElement(Text, {
			text = (props.delta > 0 and "+" or "") .. tostring(props.delta),
			tone = props.delta > 0 and "success" or "danger",
			size = textSize,
			weight = "bold",
		}) or nil,
	})
end

return ResourceChip
