--!strict
-- Stepper: a value with a minus and a plus (UI_SPEC section 4.1). It never
-- goes below its minimum or above its maximum.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Button = require(script.Parent.Parent.Primitives.Button)
local Text = require(script.Parent.Parent.Primitives.Text)

export type StepperComponent = (StepperProps) -> any

export type StepperProps = {
	value: number,
	min: number,
	max: number,
	step: number?,
	onChange: ((value: number) -> ())?,
	disabled: boolean?,
	position: UDim2?,
}

local Stepper = {}

function Stepper.render(props: StepperProps): any
	local step = props.step or 1
	local disabled = props.disabled == true

	local onChange = props.onChange
	local function move(direction: number)
		if disabled or onChange == nil then
			return
		end
		local next_ = props.value + direction * step
		if next_ < props.min then
			next_ = props.min
		end
		if next_ > props.max then
			next_ = props.max
		end
		onChange(next_)
	end

	local children: { any } = {}
	table.insert(
		children,
		React.createElement(Button.render, {
			text = "-",
			variant = "secondary",
			size = "s",
			position = UDim2.fromOffset(0, 1),
			size2 = UDim2.fromOffset(28, 26),
			disabled = disabled or props.value <= props.min,
			onClick = function()
				move(-1)
			end,
		})
	)
	table.insert(
		children,
		React.createElement(Text.render, {
			text = tostring(props.value),
			tone = if disabled then "muted" else "primary",
			size = "m",
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(32, 1),
			size2 = UDim2.fromOffset(86, 26),
		})
	)
	table.insert(
		children,
		React.createElement(Button.render, {
			text = "+",
			variant = "secondary",
			size = "s",
			position = UDim2.fromOffset(122, 1),
			size2 = UDim2.fromOffset(28, 26),
			disabled = disabled or props.value >= props.max,
			onClick = function()
				move(1)
			end,
		})
	)

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Position = props.position or UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(150, 28),
	}, children)
end

return Stepper
