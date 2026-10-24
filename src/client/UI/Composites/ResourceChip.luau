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
	text: string?, -- shown instead of the amount (a tier label; hidden wins)
	delta: number?,
	tone: ChipTone?,
	hidden: boolean?, -- a hidden value shows as a question mark
}

local ResourceChip = {}

function ResourceChip.render(props: ResourceChipProps): any
	local theme = ThemeContext.useTheme()
	local mark = theme.icons[props.resource] or "?"

	-- the chip is 120 x 24: the mark, then the amount (or its tier / ?), then
	-- the delta. Absolute positions, so a row of chips never overlaps.
	local label = if props.hidden == true
		then "?"
		elseif props.text ~= nil then props.text
		else tostring(props.amount)
	local valueX = theme.spacing.l

	local children: { any } = {}
	table.insert(
		children,
		React.createElement(Icon.render, {
			mark = mark,
			tone = props.tone or "neutral",
			size = "small",
			position = UDim2.fromOffset(0, (24 - theme.icon.small) / 2),
		})
	)
	table.insert(
		children,
		React.createElement(Text.render, {
			text = label,
			tone = if props.hidden == true then "muted" else "primary",
			size = "m",
			position = UDim2.fromOffset(valueX, 0),
			size2 = UDim2.fromOffset(52, 24),
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
				position = UDim2.fromOffset(valueX + 52 + theme.spacing.xs, 0),
				size2 = UDim2.fromOffset(48, 24),
			})
		)
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(120, 24),
	}, children)
end

return ResourceChip
