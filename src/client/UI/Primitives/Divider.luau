--!strict
-- Divider primitive: thin line using border token.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)

export type DividerProps = {
	orientation: "Horizontal" | "Vertical"?,
	layoutOrder: number?,
}

local function Divider(props: DividerProps)
	local theme = ThemeContext.useTheme()
	local tokens = theme.tokens
	local orientation = props.orientation or "Horizontal"

	return React.createElement("Frame", {
		Size = orientation == "Horizontal" and UDim2.new(1, 0, 0, tokens.border.hairline)
			or UDim2.new(0, tokens.border.hairline, 1, 0),
		BackgroundColor3 = tokens.border.color,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
	})
end

return Divider
