--!strict
-- EndScreen: victory/defeat summary.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local Surface = require(script.Parent.Parent.Primitives.Surface)
local Text = require(script.Parent.Parent.Primitives.Text)
local Button = require(script.Parent.Parent.Primitives.Button)
local Card = require(script.Parent.Parent.Composites.Card)

export type EndScreenProps = {
	result: string, -- "Solo", "Shared", "None"
	winners: { string },
	finalScores: { [string]: number },
	onReturnToLobby: () -> (),
}

local function EndScreen(props: EndScreenProps)
	local resultText = props.result == "Solo" and ("Victory: " .. props.winners[1])
		or props.result == "Shared" and ("Shared Victory: " .. table.concat(props.winners, " + "))
		or "No Winner"

	local scoreCards = {}
	for classId, score in pairs(props.finalScores) do
		table.insert(
			scoreCards,
			React.createElement(Card, {
				title = classId,
				tone = string.lower(classId),
				size = UDim2.fromOffset(150, 100),
				layoutOrder = #scoreCards,
			}, {
				Score = React.createElement(Text, {
					text = "VP: " .. score,
					size = "xl",
					weight = "bold",
					tone = "success",
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
		Result = React.createElement(Text, {
			text = resultText,
			size = "display",
			weight = "bold",
			tone = props.result ~= "None" and "success" or "danger",
		}),
		Scores = React.createElement("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
		}, {
			UIGridLayout = React.createElement("UIGridLayout", {
				CellSize = UDim2.fromOffset(170, 120),
				CellPadding = UDim2.fromOffset(16, 16),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			Cards = React.createElement(React.Fragment, nil, table.unpack(scoreCards)),
		}),
		ReturnButton = React.createElement(Button, {
			text = "Return to Lobby",
			variant = "primary",
			size = "lg",
			onClick = props.onReturnToLobby,
		}),
	})
end

return EndScreen
