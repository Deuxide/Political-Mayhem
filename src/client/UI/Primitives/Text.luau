--!strict
-- Text primitive: uses theme fonts and colors via tone.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)

export type TextProps = {
	text: string,
	tone: string?, -- "neutral", "working", "middle", "capitalist", "state", "success", "warning", "danger"
	size: string?, -- "xs", "sm", "md", "lg", "xl", "display"
	weight: string?, -- "regular", "medium", "bold"
	uppercase: boolean?,
	tracking: number?,
	sizeOverride: UDim2?,
	textXAlignment: Enum.TextXAlignment?,
	textYAlignment: Enum.TextYAlignment?,
	layoutOrder: number?,
}

local function Text(props: TextProps)
	local theme = ThemeContext.useTheme()
	local tokens = theme.tokens
	local tone = props.tone or "neutral"
	local sizeKey = props.size or "md"
	local weightKey = props.weight or "regular"

	return React.createElement("TextLabel", {
		Text = props.uppercase and string.upper(props.text) or props.text,
		FontFace = Font.new(
			tokens.typography.font.Name,
			tokens.typography.weights[weightKey],
			Enum.FontStyle.Normal
		),
		TextSize = tokens.typography.sizes[sizeKey],
		TextColor3 = tokens.color[tone][500] or tokens.color.neutral[100],
		BackgroundTransparency = 1,
		TextXAlignment = props.textXAlignment or Enum.TextXAlignment.Left,
		TextYAlignment = props.textYAlignment or Enum.TextYAlignment.Center,
		Size = props.sizeOverride or UDim2.fromScale(1, 1),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = props.layoutOrder,
		TextWrapped = true,
		RichText = false,
	}, {
		UITextSizeConstraint = React.createElement("UITextSizeConstraint", {
			MaxTextSize = tokens.typography.sizes[sizeKey],
		}),
	})
end

return Text
