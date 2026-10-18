--!strict
-- ClassCard: simplified panel for other classes (hidden info based on view).

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local Card = require(script.Parent.Parent.Composites.Card)
local ClassHeader = require(script.Parent.Parent.Composites.ClassHeader)
local ResourceChip = require(script.Parent.Parent.Composites.ResourceChip)
local StatRow = require(script.Parent.Parent.Composites.StatRow)

export type ClassCardProps = {
	classId: string,
	resources: { [string]: number }?, -- nil if hidden
	victoryPoints: number?,
	maxVP: number,
	stability: number,
	alliance: boolean?,
	layoutOrder: number?,
}

local function ClassCard(props: ClassCardProps)
	local hasResources = props.resources ~= nil
	local tone = string.lower(props.classId)

	local resourceChips = {}
	if hasResources then
		local resourceOrder = { "Money", "Influence", "Food", "Goods", "Health", "Education" }
		for _, resource in ipairs(resourceOrder) do
			table.insert(
				resourceChips,
				React.createElement(ResourceChip, {
					resource = resource,
					amount = props.resources[resource] or 0,
					tone = tone,
					size = "sm",
					layoutOrder = #resourceChips,
				})
			)
		end
	end

	return React.createElement(Card, {
		title = props.classId .. (props.alliance and " 🤝" or ""),
		tone = tone,
		size = UDim2.fromOffset(200, 0),
		automaticSize = Enum.AutomaticSize.Y,
		layoutOrder = props.layoutOrder,
	}, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 8),
		}),
		Header = React.createElement(ClassHeader, {
			classId = props.classId,
			victoryPoints = props.victoryPoints or 0,
			maxVP = props.maxVP,
			stability = props.stability,
		}),
		Resources = hasResources and React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 4),
			}),
			Chips = React.createElement(React.Fragment, nil, table.unpack(resourceChips)),
		}) or React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
		}, {
			Hidden = React.createElement("TextLabel", {
				Text = "?",
				Font = Enum.Font.GothamBold,
				TextSize = 24,
				TextColor3 = Color3.fromRGB(100, 100, 100),
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				TextScaled = true,
			}),
		}),
	})
end

return ClassCard
