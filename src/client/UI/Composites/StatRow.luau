--!strict
-- StatRow composite: label + value row for stats display.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local Primitives = require(script.Parent.Primitives)

local Text = Primitives.Text
local Divider = Primitives.Divider

export type StatRowProps = {
	label: string,
	value: string | number,
	tone: string?, -- for value
	showDivider: boolean?,
	layoutOrder: number?,
}

local function StatRow(props: StatRowProps)
	local tone = props.tone or "neutral"

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = props.layoutOrder,
	}, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Label = React.createElement(Text, {
			text = props.label,
			tone = "neutral",
			size = "sm",
		}),
		Value = React.createElement(Text, {
			text = tostring(props.value),
			tone = tone,
			size = "sm",
			weight = "bold",
		}),
		Divider = props.showDivider
				and React.createElement(Divider, { orientation = "Horizontal", layoutOrder = 100 })
			or nil,
	})
end

return StatRow
