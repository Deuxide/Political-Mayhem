--!strict
-- OwnClassPanel: detailed panel for the player's own class.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local Card = require(script.Parent.Parent.Composites.Card)
local ResourceChip = require(script.Parent.Parent.Composites.ResourceChip)
local ClassHeader = require(script.Parent.Parent.Composites.ClassHeader)
local StatRow = require(script.Parent.Parent.Composites.StatRow)

export type OwnClassPanelProps = {
	classId: string,
	resources: { [string]: number },
	victoryPoints: number,
	maxVP: number,
	stability: number,
	influence: number,
	layoutOrder: number?,
}

local function OwnClassPanel(props: OwnClassPanelProps)
	local resourceOrder = { "Money", "Influence", "Food", "Goods", "Health", "Education" }
	local resourceChips = {}

	for _, resource in ipairs(resourceOrder) do
		table.insert(
			resourceChips,
			React.createElement(ResourceChip, {
				resource = resource,
				amount = props.resources[resource] or 0,
				tone = string.lower(props.classId),
				size = "md",
				layoutOrder = #resourceChips,
			})
		)
	end

	return React.createElement(Card, {
		title = props.classId .. " (You)",
		tone = string.lower(props.classId),
		size = UDim2.fromOffset(320, 0),
		automaticSize = Enum.AutomaticSize.Y,
		layoutOrder = props.layoutOrder,
	}, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 12),
		}),
		Header = React.createElement(ClassHeader, {
			classId = props.classId,
			victoryPoints = props.victoryPoints,
			maxVP = props.maxVP,
			stability = props.stability,
		}),
		ResourcesLabel = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 20),
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 8),
			}),
			ResourceChips = React.createElement(React.Fragment, nil, table.unpack(resourceChips)),
		}),
		Stats = React.createElement("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 4),
			}),
			Influence = React.createElement(StatRow, {
				label = "Influence",
				value = props.influence,
				tone = "neutral",
				showDivider = true,
			}),
			Stability = React.createElement(StatRow, {
				label = "Stability",
				value = props.stability .. "%",
				tone = props.stability < 30 and "danger"
					or props.stability < 60 and "warning"
					or "success",
			}),
			VP = React.createElement(StatRow, {
				label = "Victory Points",
				value = props.victoryPoints .. " / " .. props.maxVP,
				tone = "success",
			}),
		}),
	})
end

return OwnClassPanel
