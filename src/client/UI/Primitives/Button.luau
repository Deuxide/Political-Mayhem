--!strict
-- Button primitive: uses Surface for gradient, Text for label.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local Surface = require(script.Parent.Surface)
local Text = require(script.Parent.Text)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)

export type ButtonProps = {
	text: string,
	variant: string?, -- "primary", "secondary", "danger", "ghost"
	size: string?, -- "sm", "md", "lg"
	tone: string?, -- for ghost variant
	disabled: boolean?,
	onClick: (() -> ())?,
	layoutOrder: number?,
	sizeOverride: UDim2?,
}

local function Button(props: ButtonProps)
	local theme = ThemeContext.useTheme()
	local variant = props.variant or "primary"
	local size = props.size or "md"
	local disabled = props.disabled or false

	local gradientRole = variant == "primary" and "buttonPrimary"
		or variant == "secondary" and "buttonSecondary"
		or variant == "danger" and "buttonDanger"
		or "buttonDisabled"

	local padding = size == "sm" and UDim.new(0, 8)
		or size == "md" and UDim.new(0, 12)
		or UDim.new(0, 16)

	local textSize = size == "sm" and "sm" or size == "md" and "md" or "lg"

	return React.createElement(Surface, {
		gradientRole = disabled and "buttonDisabled" or gradientRole,
		size = props.sizeOverride or UDim2.fromOffset(0, 0),
		automaticSize = Enum.AutomaticSize.XY,
	}, {
		UIPadding = React.createElement("UIPadding", {
			PaddingLeft = padding,
			PaddingRight = padding,
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		}),
		Text = React.createElement(Text, {
			text = props.text,
			tone = variant == "ghost" and (props.tone or "neutral") or "neutral",
			size = textSize,
			weight = "medium",
			sizeOverride = UDim2.fromOffset(0, 0),
			automaticSize = Enum.AutomaticSize.XY,
		}),
		Button = React.createElement("TextButton", {
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			AutoButtonColor = false,
			Active = not disabled,
			[React.Event.Activated] = function()
				if not disabled and props.onClick then props.onClick() end
			end,
		}),
	})
end

return Button
