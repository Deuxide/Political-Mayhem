--!strict
-- Button: a Surface with a label and a click. The variant and the tone are
-- meaning, never colors; the hover and pressed states shift the gradient
-- (UI_STYLE section 2) — they never add a shadow or a bounce.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Surface = require(script.Parent.Surface)
local Text = require(script.Parent.Text)

export type ButtonVariant = "primary" | "secondary" | "ghost" | "danger"
export type ButtonSize = "s" | "m" | "l"

export type ButtonComponent = (ButtonProps) -> any

export type ButtonProps = {
	text: string,
	onClick: (() -> ())?,
	variant: ButtonVariant?,
	size: ButtonSize?,
	disabled: boolean?,
	uppercase: boolean?,
	position: UDim2?,
	size2: UDim2?,
	anchorPoint: Vector2?,
	zIndex: number?,
	visible: boolean?,
	layoutOrder: number?,
}

local Button = {}

local function gradientRole(variant: ButtonVariant): string
	if variant == "danger" then
		return "button.danger"
	end
	if variant == "primary" then
		return "button.primary"
	end
	return "button.secondary"
end

function Button.render(props: ButtonProps): any
	local variant: ButtonVariant = (props.variant or "secondary") :: any
	local size = props.size or "m"
	local disabled = props.disabled == true

	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)

	local height = if size == "l" then 44 elseif size == "s" then 26 else 34
	local role = if disabled then "button.disabled" else gradientRole(variant)

	local label = React.createElement(Text.render, {
		text = props.text,
		tone = if disabled then "muted" else "primary",
		size = if size == "l" then "m" else "s",
		uppercase = props.uppercase == true,
		align = Enum.TextXAlignment.Center,
		size2 = UDim2.fromScale(1, 1),
	})

	local face = React.createElement(Surface.render, {
		gradient = role,
		size = UDim2.fromScale(1, 1),
		hovered = hovered,
		pressed = pressed,
	}, label)

	local onClick = props.onClick
	local function activate()
		if disabled or onClick == nil then
			return
		end
		onClick()
	end

	local buttonProps: { [any]: any } = {
		Position = props.position or UDim2.fromOffset(0, 0),
		Size = props.size2 or UDim2.fromOffset(120, height),
		AnchorPoint = props.anchorPoint or Vector2.new(0, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Visible = props.visible ~= false,
		LayoutOrder = props.layoutOrder or 0,
		[React.Event.Activated] = activate,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
			setPressed(false)
		end,
		[React.Event.MouseButton1Down] = function()
			setPressed(true)
		end,
		[React.Event.MouseButton1Up] = function()
			setPressed(false)
		end,
	}

	return React.createElement("TextButton", buttonProps, face)
end

return Button
