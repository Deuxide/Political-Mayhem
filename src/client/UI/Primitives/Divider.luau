--!strict
-- Divider: a hairline between two rows (UI_STYLE section 1.2: a line, not
-- shading). The width and the color come from the skin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)

export type DividerComponent = (DividerProps) -> any

export type DividerProps = {
	position: UDim2?,
	size: UDim2?,
	tone: "hairline" | "strong",
	layoutOrder: number?,
	zIndex: number?,
}

local Divider = {}

function Divider.render(props: DividerProps): any
	local theme = ThemeContext.useTheme()
	local tone = props.tone or "hairline"

	return React.createElement("Frame", {
		Position = props.position or UDim2.fromOffset(0, 0),
		Size = props.size or UDim2.new(1, 0, 0, theme.border.hairline),
		BackgroundColor3 = theme.colors["line." .. tone],
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder or 0,
		ZIndex = props.zIndex or 1,
	})
end

return Divider
