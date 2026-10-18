--!strict
-- LobbyScreen: class selection and ready up.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local Surface = require(script.Parent.Parent.Primitives.Surface)
local Text = require(script.Parent.Parent.Primitives.Text)
local Button = require(script.Parent.Parent.Primitives.Button)
local Card = require(script.Parent.Parent.Composites.Card)

export type LobbyScreenProps = {
	availableClasses: { string },
	selectedClass: string?,
	onClassSelect: (classId: string) -> (),
	ready: boolean,
	onReadyToggle: () -> (),
	canStart: boolean,
	onStart: () -> (),
}

local function LobbyScreen(props: LobbyScreenProps)
	local classCards = {}
	for _, classId in ipairs(props.availableClasses) do
		table.insert(
			classCards,
			React.createElement(Card, {
				title = classId,
				tone = string.lower(classId),
				size = UDim2.fromOffset(150, 200),
				layoutOrder = #classCards,
			}, {
				UIPadding = React.createElement("UIPadding", {
					PaddingTop = UDim.new(0, 20),
					PaddingBottom = UDim.new(0, 20),
				}),
				SelectButton = React.createElement(Button, {
					text = props.selectedClass == classId and "Selected" or "Choose",
					variant = props.selectedClass == classId and "primary" or "secondary",
					size = "md",
					onClick = function() props.onClassSelect(classId) end,
				}),
			})
		)
	end

	return React.createElement(Surface, {
		gradientRole = "tableBackground",
		size = UDim2.fromScale(1, 1),
	}, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 24),
		}),
		Title = React.createElement(Text, {
			text = "POLITICAL MAYHEM",
			size = "display",
			weight = "bold",
			tone = "neutral",
		}),
		Subtitle = React.createElement(Text, {
			text = "Choose your class and ready up",
			size = "lg",
			tone = "neutral",
		}),
		ClassGrid = React.createElement("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
		}, {
			UIGridLayout = React.createElement("UIGridLayout", {
				CellSize = UDim2.fromOffset(170, 220),
				CellPadding = UDim2.fromOffset(16, 16),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			Cards = React.createElement(React.Fragment, nil, table.unpack(classCards)),
		}),
		ReadyButton = React.createElement(Button, {
			text = props.ready and "Ready ✓" or "Ready",
			variant = props.ready and "success" or "primary",
			size = "lg",
			onClick = props.onReadyToggle,
			disabled = not props.selectedClass,
		}),
		StartButton = props.canStart and React.createElement(Button, {
			text = "Start Match",
			variant = "primary",
			size = "lg",
			onClick = props.onStart,
		}) or nil,
	})
end

return LobbyScreen
