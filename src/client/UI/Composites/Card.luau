--!strict
-- Card composite: surface with header band and body.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local Primitives = require(script.Parent.Parent.Primitives)

local Surface = Primitives.Surface
local Text = Primitives.Text
local Divider = Primitives.Divider

export type CardProps = {
	title: string,
	tone: string?, -- "neutral", "working", "middle", "capitalist", "state"
	children: React.ReactNode,
	size: UDim2?,
	padding: UDim?,
	layoutOrder: number?,
}

local function Card(props: CardProps)
	local tone = props.tone or "neutral"
	local headerGradient = tone ~= "neutral"
			and ("accent" .. string.sub(tone, 1, 1):upper() .. string.sub(tone, 2))
		or "surfaceHeader"

	return React.createElement(Surface, {
		gradientRole = "surfaceCard",
		size = props.size or UDim2.fromScale(1, 1),
		automaticSize = props.size and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
		layoutOrder = props.layoutOrder,
	}, {
		UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, 0),
			PaddingBottom = UDim.new(0, 0),
			PaddingLeft = UDim.new(0, 0),
			PaddingRight = UDim.new(0, 0),
		}),
		Header = React.createElement(Surface, {
			gradientRole = headerGradient,
			size = UDim2.new(1, 0, 0, 36),
		}, {
			UIPadding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			Title = React.createElement(Text, {
				text = props.title,
				tone = "neutral",
				size = "md",
				weight = "bold",
				uppercase = true,
				tracking = 1,
			}),
		}),
		Divider = React.createElement(Divider, { orientation = "Horizontal" }),
		Body = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -36),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, {
			UIPadding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			Children = props.children,
		}),
	})
end

return Card
