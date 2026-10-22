--!strict
-- Card: the basic container of the board-game look (UI_STYLE section 1.1) —
-- a flat body, a header band carrying the title and the class gradient, and
-- a body area.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)
local Surface = require(script.Parent.Parent.Primitives.Surface)
local Text = require(script.Parent.Parent.Primitives.Text)

export type CardTone = "neutral" | "working" | "middle" | "capitalist" | "state"

export type CardComponent = (CardProps) -> any

export type CardProps = {
	title: string,
	tone: CardTone?,
	subtitle: string?,
	children: any?,
	position: UDim2?,
	size: UDim2?,
	anchorPoint: Vector2?,
	zIndex: number?,
	visible: boolean?,
	layoutOrder: number?,
}

local Card = {}

function Card.render(props: CardProps): any
	local theme = ThemeContext.useTheme()
	local tone = props.tone or "neutral"

	local header: { any } = {}
	table.insert(
		header,
		React.createElement(
			Surface.render,
			{
				gradient = if tone == "neutral" then "surface.header" else "accent." .. tone,
				size = UDim2.new(1, 0, 0, 28),
			},
			React.createElement(Text.render, {
				text = props.title,
				tone = "primary",
				size = "s",
				uppercase = true,
				size2 = UDim2.new(1, -theme.spacing.l, 1, 0),
				position = UDim2.fromOffset(theme.spacing.l, 0),
			})
		)
	)
	if props.subtitle ~= nil then
		table.insert(
			header,
			React.createElement(Text.render, {
				text = props.subtitle,
				tone = "muted",
				size = "xs",
				position = UDim2.new(1, -theme.spacing.l, 1, 0),
				anchorPoint = Vector2.new(1, 0),
			})
		)
	end

	local body: { any } = {}
	if props.children ~= nil then
		table.insert(body, props.children)
	end

	local content: { any } = {}
	table.insert(
		content,
		React.createElement(Surface.render, {
			size = UDim2.new(1, 0, 0, 28),
		}, header)
	)
	table.insert(
		content,
		React.createElement(Surface.render, {
			gradient = "surface.card",
			size = UDim2.new(1, 0, 1, -28),
		}, body)
	)

	return React.createElement(Surface.render, {
		size = props.size or UDim2.fromScale(1, 1),
		position = props.position,
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex,
		visible = props.visible,
		layoutOrder = props.layoutOrder,
	}, content)
end

return Card
