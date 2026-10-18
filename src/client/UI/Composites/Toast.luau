--!strict
-- Toast composite: transient notification.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local Primitives = require(script.Parent.Parent.Primitives)

local Surface = Primitives.Surface
local Text = Primitives.Text
local Icon = Primitives.Icon

export type ToastProps = {
	message: string,
	tone: string?, -- "success", "warning", "danger", "neutral"
	duration: number?,
	onDismiss: () -> (),
	layoutOrder: number?,
}

local function Toast(props: ToastProps)
	local tone = props.tone or "neutral"
	local gradientRole = tone == "success" and "meterFill"
		or tone == "warning" and "meterWarning"
		or tone == "danger" and "meterDanger"
		or "surfaceRaised"

	React.useEffect(function()
		local duration = props.duration or 3
		local thread = task.delay(duration, function() props.onDismiss() end)
		return function() task.cancel(thread) end
	end, { props.duration })

	return React.createElement(Surface, {
		gradientRole = gradientRole,
		size = UDim2.fromOffset(300, 0),
		automaticSize = Enum.AutomaticSize.Y,
		layoutOrder = props.layoutOrder,
		zIndex = 50,
	}, {
		UIPadding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		}),
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
		}),
		Icon = React.createElement(Icon, {
			image = "rbxassetid://0",
			size = "md",
			tone = tone,
		}),
		Message = React.createElement(Text, {
			text = props.message,
			tone = "neutral",
			size = "md",
		}),
	})
end

return Toast
