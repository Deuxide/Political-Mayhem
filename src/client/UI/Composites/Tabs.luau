--!strict
-- Tabs: a row of buttons, one active (UI_SPEC section 4.1). The active tab
-- uses the raised surface, the others the inset one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Button = require(script.Parent.Parent.Primitives.Button)
local Surface = require(script.Parent.Parent.Primitives.Surface)

export type TabSpec = { key: string, label: string, disabled: boolean? }

export type TabsComponent = (TabsProps) -> any

export type TabsProps = {
	tabs: { TabSpec },
	active: string,
	onSelect: ((key: string) -> ())?,
}

local Tabs = {}

function Tabs.render(props: TabsProps): any
	local onSelect = props.onSelect

	local children: { any } = {}
	for index, tab in props.tabs do
		local active = tab.key == props.active
		table.insert(
			children,
			React.createElement(
				Surface,
				{
					gradient = if active then "surface.raised" else "surface.inset",
					size = UDim2.fromOffset(96, 30),
					position = UDim2.fromOffset((index - 1) * 100, 0),
				},
				React.createElement(Button.render, {
					text = tab.label,
					variant = "ghost",
					size = "s",
					uppercase = true,
					disabled = tab.disabled == true,
					onClick = function()
						if onSelect ~= nil then
							onSelect(tab.key)
						end
					end,
				})
			)
		)
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(#props.tabs * 100, 30),
	}, children)
end

return Tabs
