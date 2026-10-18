--!strict
-- Icon primitive: simple image label with theme sizing.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)

export type IconProps = {
	image: string, -- rbxassetid://...
	size: string?, -- "xs", "sm", "md", "lg"
	tone: string?, -- "neutral", "working", etc. (for color tint)
	layoutOrder: number?,
}

local function Icon(props: IconProps)
	local theme = ThemeContext.useTheme()
	local tokens = theme.tokens
	local sizeKey = props.size or "md"
	local iconSize = tokens.typography.sizes[sizeKey] * 1.5

	return React.createElement("ImageLabel", {
		Image = props.image,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(iconSize, iconSize),
		ImageColor3 = props.tone and tokens.color[props.tone][500] or tokens.color.neutral[100],
		LayoutOrder = props.layoutOrder,
	})
end

return Icon
