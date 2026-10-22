--!strict
-- Icon: a square token (UI_STYLE section 1.1). There are no image assets
-- yet, so an icon is a flat square in a tone with a one-letter mark — the
-- shape that later carries the icon set of the tokens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)
local Surface = require(script.Parent.Surface)
local Text = require(script.Parent.Text)

export type IconSize = "small" | "medium" | "large"
export type IconTone =
	"neutral"
	| "working"
	| "middle"
	| "capitalist"
	| "state"
	| "success"
	| "warning"
	| "danger"

export type IconComponent = (IconProps) -> any

export type IconProps = {
	mark: string?, -- the one-letter mark inside the token
	tone: IconTone?,
	size: IconSize?,
	position: UDim2?,
	size2: UDim2?,
	anchorPoint: Vector2?,
	zIndex: number?,
	visible: boolean?,
	layoutOrder: number?,
}

local Icon = {}

function Icon.render(props: IconProps): any
	local theme = ThemeContext.useTheme()
	local tone = props.tone or "neutral"
	local size = props.size or "medium"
	local side = theme.icon[size]
	local role = if tone == "neutral" then "surface.raised" else "accent." .. tone

	local mark = props.mark
	local children: { any } = {}
	if mark ~= nil then
		table.insert(
			children,
			React.createElement(Text.render, {
				text = mark,
				tone = "onAccent",
				size = "xs",
				align = Enum.TextXAlignment.Center,
				size2 = UDim2.fromScale(1, 1),
			})
		)
	end

	return React.createElement(Surface.render, {
		gradient = role,
		position = props.position,
		size = props.size2 or UDim2.fromOffset(side, side),
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex,
		visible = props.visible,
		layoutOrder = props.layoutOrder,
	}, children)
end

return Icon
