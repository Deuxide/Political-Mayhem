--!strict
-- Modal composite: overlay with scrim.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local Surface = require(script.Parent.Primitives.Surface)
local Text = require(script.Parent.Primitives.Text)
local Button = require(script.Parent.Primitives.Button)
local ThemeContext = require(script.Parent.Theme.ThemeContext)

export type ModalProps = {
	open: boolean,
	title: string,
	children: React.ReactNode,
	onClose: () -> (),
	size: UDim2?,
	actions: { { text: string, variant: string?, onClick: () -> () } }?,
	layoutOrder: number?,
}

local function Modal(props: ModalProps)
	if not props.open then return nil end

	local theme = ThemeContext.useTheme()

	return React.createElement(Surface, {
		gradientRole = "overlayScrim",
		size = UDim2.fromScale(1, 1),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		zIndex = 100,
	}, {
		ModalFrame = React.createElement(Surface, {
			gradientRole = "surfaceCard",
			size = props.size or UDim2.fromOffset(400, 300),
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			zIndex = 101,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
			}),
			Header = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 40),
				AutomaticSize = Enum.AutomaticSize.Y,
			}, {
				UIPadding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 16),
					PaddingRight = UDim.new(0, 16),
					PaddingTop = UDim.new(0, 12),
					PaddingBottom = UDim.new(0, 12),
				}),
				UIListLayout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				Title = React.createElement(Text, {
					text = props.title,
					size = "lg",
					weight = "bold",
				}),
				CloseButton = React.createElement(Button, {
					text = "✕",
					variant = "ghost",
					size = "sm",
					onClick = props.onClose,
				}),
			}),
			Divider = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = theme.tokens.border.color,
				BorderSizePixel = 0,
			}),
			Body = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, -40),
				AutomaticSize = Enum.AutomaticSize.Y,
			}, {
				UIPadding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 16),
					PaddingRight = UDim.new(0, 16),
					PaddingTop = UDim.new(0, 16),
					PaddingBottom = UDim.new(0, 16),
				}),
				Children = props.children,
			}),
			Actions = props.actions and #props.actions > 0 and React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 50),
			}, {
				UIPadding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 16),
					PaddingRight = UDim.new(0, 16),
					PaddingBottom = UDim.new(0, 16),
				}),
				UIListLayout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					Padding = UDim.new(0, 8),
				}),
				ActionButtons = React.createElement(
					React.Fragment,
					nil,
					(function()
						local buttons = {}
						for _, action in ipairs(props.actions) do
							table.insert(
								buttons,
								React.createElement(Button, {
									text = action.text,
									variant = action.variant or "primary",
									onClick = action.onClick,
								})
							)
						end
						return table.unpack(buttons)
					end)()
				),
			}) or nil,
		}),
	})
end

return Modal
