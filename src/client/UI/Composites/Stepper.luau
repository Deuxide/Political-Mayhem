--!strict
-- Stepper composite: minus/plus buttons around a value display.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local Primitives = require(script.Parent.Primitives)

local Button = Primitives.Button
local Text = Primitives.Text
local Surface = Primitives.Surface

export type StepperProps = {
	value: number,
	min: number,
	max: number,
	onChange: (newValue: number) -> (),
	size: string?, -- "sm", "md", "lg"
	layoutOrder: number?,
}

local function Stepper(props: StepperProps)
	local size = props.size or "md"
	local btnSize = size == "sm" and "sm" or size == "md" and "md" or "lg"

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = props.layoutOrder,
	}, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
		}),
		Decrement = React.createElement(Button, {
			text = "-",
			variant = "secondary",
			size = btnSize,
			disabled = props.value <= props.min,
			onClick = function() props.onChange(math.max(props.min, props.value - 1)) end,
		}),
		Value = React.createElement(Surface, {
			gradientRole = "surfaceInset",
			size = UDim2.fromOffset(size == "sm" and 40 or 60, size == "sm" and 28 or 36),
		}, {
			ValueText = React.createElement(Text, {
				text = tostring(props.value),
				size = size == "sm" and "sm" or "md",
				weight = "bold",
			}),
		}),
		Increment = React.createElement(Button, {
			text = "+",
			variant = "secondary",
			size = btnSize,
			disabled = props.value >= props.max,
			onClick = function() props.onChange(math.min(props.max, props.value + 1)) end,
		}),
	})
end

return Stepper
