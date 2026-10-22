--!strict
-- Toast: a small message that slides in (UI_SPEC section 5: a server Notice
-- becomes a Toast). The tone carries the meaning; the colors come from the
-- skin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)
local Surface = require(script.Parent.Parent.Primitives.Surface)
local Text = require(script.Parent.Parent.Primitives.Text)
local Button = require(script.Parent.Parent.Primitives.Button)

export type ToastTone = "info" | "success" | "warning" | "danger"

export type ToastComponent = (ToastProps) -> any

export type ToastProps = {
	message: string,
	tone: ToastTone?,
	onDismiss: (() -> ())?,
}

local Toast = {}

function Toast.render(props: ToastProps): any
	local theme = ThemeContext.useTheme()
	local tone = props.tone or "info"

	local children: { any } = {}
	table.insert(
		children,
		React.createElement(Text.render, {
			text = props.message,
			tone = if tone == "info" then "primary" else tone :: any,
			size = "s",
			size2 = UDim2.new(1, -theme.spacing.l, 1, 0),
			position = UDim2.fromOffset(theme.spacing.l, 0),
		})
	)
	if props.onDismiss ~= nil then
		local onDismiss = props.onDismiss
		table.insert(
			children,
			React.createElement(Button.render, {
				text = "x",
				variant = "ghost",
				size = "s",
				position = UDim2.new(1, -theme.spacing.s, 0, 0),
				anchorPoint = Vector2.new(1, 0),
				onClick = function()
					onDismiss()
				end,
			})
		)
	end

	return React.createElement(Surface.render, {
		gradient = if tone == "info" then "surface.raised" else "button." .. (tone :: any),
		size = UDim2.fromOffset(320, 40),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -theme.spacing.l, 0, theme.spacing.l),
		ZIndex = 60,
	}, children)
end

return Toast
