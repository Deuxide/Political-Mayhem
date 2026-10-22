--!strict
-- Modal: a scrim with a card on it (UI_SPEC section 3). It floats over the
-- city and never blocks the top bar or the own panel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)
local Surface = require(script.Parent.Parent.Primitives.Surface)
local Text = require(script.Parent.Parent.Primitives.Text)
local Button = require(script.Parent.Parent.Primitives.Button)

export type ModalComponent = (ModalProps) -> any

export type ModalProps = {
	title: string,
	children: any?,
	onClose: (() -> ())?,
	width: number?,
}

local Modal = {}

function Modal.render(props: ModalProps): any
	local theme = ThemeContext.useTheme()
	local width = props.width or 420

	local header: { any } = {}
	table.insert(
		header,
		React.createElement(Text.render, {
			text = props.title,
			tone = "primary",
			size = "m",
			uppercase = true,
			size2 = UDim2.new(1, -theme.spacing.l, 1, 0),
			position = UDim2.fromOffset(theme.spacing.l, 0),
		})
	)
	if props.onClose ~= nil then
		local onClose = props.onClose
		table.insert(
			header,
			React.createElement(Button.render, {
				text = "x",
				variant = "ghost",
				size = "s",
				position = UDim2.new(1, -theme.spacing.l, 0, 0),
				anchorPoint = Vector2.new(1, 0),
				onClick = function()
					onClose()
				end,
			})
		)
	end

	local body: { any } = {}
	if props.children ~= nil then
		table.insert(body, props.children)
	end

	local card: { any } = {}
	table.insert(
		card,
		React.createElement(Surface.render, {
			gradient = "surface.header",
			size = UDim2.new(1, 0, 0, 36),
		}, header)
	)
	table.insert(
		card,
		React.createElement(Surface.render, {
			gradient = "surface.card",
			size = UDim2.new(1, 0, 1, -36),
		}, body)
	)

	return React.createElement(
		"Frame",
		{
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 50,
		},
		React.createElement(
			Surface,
			{
				gradient = "overlay.scrim",
				size = UDim2.fromScale(1, 1),
				ZIndex = 50,
			},
			React.createElement(Surface.render, {
				gradient = "surface.card",
				size = UDim2.fromOffset(width, 260),
				position = UDim2.fromScale(0.5, 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 51,
			}, card)
		)
	)
end

return Modal
