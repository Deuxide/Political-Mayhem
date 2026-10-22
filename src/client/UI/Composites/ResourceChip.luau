--!strict
-- ResourceChip: a square token with the amount, like a punched cardboard
-- token (UI_STYLE section 1.1). A gain or a loss shows as +n or -n beside
-- the number.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)
local Icon = require(script.Parent.Parent.Primitives.Icon)
local Text = require(script.Parent.Parent.Primitives.Text)

export type ChipTone =
	"neutral"
	| "working"
	| "middle"
	| "capitalist"
	| "state"
	| "success"
	| "warning"
	| "danger"

export type ResourceChipComponent = (ResourceChipProps) -> any

export type ResourceChipProps = {
	resource: string, -- the resource name: its mark comes from the icon set
	amount: number,
	delta: number?,
	tone: ChipTone?,
	hidden: boolean?, -- a hidden value shows as a question mark
}

local ResourceChip = {}

function ResourceChip.render(props: ResourceChipProps): any
	local theme = ThemeContext.useTheme()
	local mark = theme.icons[props.resource] or "?"

	local children: { any } = {}
	table.insert(
		children,
		React.createElement(Icon.render, {
			mark = mark,
			tone = props.tone or "neutral",
			size = "small",
		})
	)
	table.insert(
		children,
		React.createElement(Text.render, {
			text = if props.hidden == true then "?" else tostring(props.amount),
			tone = if props.hidden == true then "muted" else "primary",
			size = "m",
			size2 = UDim2.fromOffset(46, 20),
		})
	)
	if props.delta ~= nil and props.delta ~= 0 and props.hidden ~= true then
		table.insert(
			children,
			React.createElement(Text.render, {
				text = if props.delta > 0
					then "+" .. tostring(props.delta)
					else tostring(props.delta),
				tone = if props.delta > 0 then "success" else "danger",
				size = "xs",
				size2 = UDim2.fromOffset(40, 20),
			})
		)
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(120, 24),
	}, children)
end

return ResourceChip
