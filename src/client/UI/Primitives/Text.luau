--!strict
-- Text: the only primitive that puts words on the screen. The text always
-- travels in the `Text` prop — Roblox has no text nodes, so a string child
-- is a bug (react-lua issue #42).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)

export type TextTone =
	"primary"
	| "secondary"
	| "muted"
	| "success"
	| "warning"
	| "danger"
	| "onAccent"
export type TextSize = "xs" | "s" | "m" | "l" | "xl" | "display"

export type TextComponent = (TextProps) -> any

export type TextProps = {
	text: string,
	tone: TextTone?,
	size: TextSize?,
	uppercase: boolean?,
	align: Enum.TextXAlignment?,
	truncate: boolean?,
	position: UDim2?,
	size2: UDim2?,
	anchorPoint: Vector2?,
	zIndex: number?,
	visible: boolean?,
	layoutOrder: number?,
}

local Text = {}

function Text.render(props: TextProps): any
	local theme = ThemeContext.useTheme()
	local tone = props.tone or "primary"
	local size = props.size or "m"

	local labelProps: { [any]: any } = {
		Text = if props.uppercase == true then string.upper(props.text) else props.text,
		Font = theme.font.family,
		TextSize = theme.type[size],
		TextColor3 = theme.colors["text." .. tone],
		TextXAlignment = props.align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = props.truncate == true and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None,
		BackgroundTransparency = 1,
		Position = props.position or UDim2.fromOffset(0, 0),
		Size = props.size2 or UDim2.fromScale(1, 0),
		ZIndex = props.zIndex or 1,
		Visible = props.visible ~= false,
	}
	if props.anchorPoint ~= nil then
		labelProps.AnchorPoint = props.anchorPoint
	end
	if props.layoutOrder ~= nil then
		labelProps.LayoutOrder = props.layoutOrder
	end
	return React.createElement("TextLabel", labelProps)
end

return Text
