--!strict
-- Tabs composite: tab bar with content panels.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local Primitives = require(script.Parent.Parent.Primitives)

local Button = Primitives.Button
local Surface = Primitives.Surface

export type Tab = {
	id: string,
	label: string,
	content: React.ReactNode,
}

export type TabsProps = {
	tabs: { Tab },
	defaultTab: string?,
	onChange: (tabId: string) -> (),
	layoutOrder: number?,
}

local function Tabs(props: TabsProps)
	local defaultTab = props.defaultTab or (props.tabs[1] and props.tabs[1].id) or ""
	local selectedTab, setSelectedTab = React.useState(defaultTab)

	local tabButtons = {}
	for _, tab in ipairs(props.tabs) do
		table.insert(
			tabButtons,
			React.createElement(Button, {
				text = tab.label,
				variant = selectedTab == tab.id and "primary" or "secondary",
				size = "sm",
				onClick = function()
					setSelectedTab(tab.id)
					props.onChange(tab.id)
				end,
				layoutOrder = #tabButtons,
			})
		)
	end

	local selectedContent = nil
	for _, tab in ipairs(props.tabs) do
		if tab.id == selectedTab then
			selectedContent = tab.content
			break
		end
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		LayoutOrder = props.layoutOrder,
	}, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 8),
		}),
		TabBar = React.createElement("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 4),
			}),
			Buttons = React.createElement(React.Fragment, nil, table.unpack(tabButtons)),
		}),
		Content = React.createElement(Surface, {
			gradientRole = "surfaceCard",
			size = UDim2.new(1, 0, 1, -40),
		}, {
			SelectedContent = selectedContent,
		}),
	})
end

return Tabs
