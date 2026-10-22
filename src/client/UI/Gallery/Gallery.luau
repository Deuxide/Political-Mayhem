--!strict
-- Gallery: the dev-only screen that shows every component in every state
-- (UI_STYLE section 4.1). It is how a redesign is checked: switch the skin
-- and every component must still work.
--
-- The Gallery is the only place that knows about the components directly;
-- the components know nothing about it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)
local DefaultSkin = require(script.Parent.Parent.Theme.Skins.Default)
local ContrastSkin = require(script.Parent.Parent.Theme.Skins.Contrast)
local Text = require(script.Parent.Parent.Primitives.Text)
local Button = require(script.Parent.Parent.Primitives.Button)
local Icon = require(script.Parent.Parent.Primitives.Icon)
local Divider = require(script.Parent.Parent.Primitives.Divider)
local Card = require(script.Parent.Parent.Composites.Card)
local ResourceChip = require(script.Parent.Parent.Composites.ResourceChip)
local SegmentedTrack = require(script.Parent.Parent.Composites.SegmentedTrack)
local Stepper = require(script.Parent.Parent.Composites.Stepper)
local Tabs = require(script.Parent.Parent.Composites.Tabs)
local Modal = require(script.Parent.Parent.Composites.Modal)
local Toast = require(script.Parent.Parent.Composites.Toast)

local Gallery = {}

-- A titled section of the gallery.
local function section(title: string, children: { any }): any
	return React.createElement(
		Card,
		{
			title = title,
			size = UDim2.new(1, -32, 0, 0),
		},
		React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -32, 0, 0),
			Position = UDim2.fromOffset(16, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, children)
	)
end

-- A row of examples.
local function row(children: { any }): any
	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, children)
end

function Gallery.render(): any
	local skin, setSkin = React.useState(DefaultSkin)
	local showModal, setShowModal = React.useState(false)
	local step, setStep = React.useState(2)
	local tab, setTab = React.useState("economy")

	local children: { any } = {}

	-- the skin switcher: a second skin must restyle everything (UI_STYLE 4.2)
	table.insert(
		children,
		React.createElement(Button.render, {
			text = "skin: " .. skin.name,
			variant = "primary",
			size = "m",
			onClick = function()
				if skin.name == DefaultSkin.name then
					setSkin(ContrastSkin)
				else
					setSkin(DefaultSkin)
				end
			end,
		})
	)

	table.insert(children, React.createElement(Divider.render, { size = UDim2.new(1, -32, 0, 1) }))

	-- Text: every tone and every size
	local textRow: { any } = {}
	for _, tone in { "primary", "secondary", "muted", "success", "warning", "danger" } do
		table.insert(
			textRow,
			React.createElement(Text.render, {
				text = tone,
				tone = tone :: any,
				size = "m",
				size2 = UDim2.fromOffset(120, 24),
			})
		)
	end
	table.insert(children, section("Text", { row(textRow) }))
	local sizeRow: { any } = {}
	for _, size in { "xs", "s", "m", "l", "xl", "display" } do
		table.insert(
			sizeRow,
			React.createElement(Text.render, {
				text = size,
				size = size :: any,
				size2 = UDim2.fromOffset(140, 40),
			})
		)
	end
	table.insert(children, section("Text sizes", { row(sizeRow) }))

	-- Button: every variant, every size, disabled
	local buttonRow: { any } = {}
	for _, variant in { "primary", "secondary", "ghost", "danger" } do
		table.insert(
			buttonRow,
			React.createElement(Button.render, {
				text = variant,
				variant = variant :: any,
				size = "m",
				onClick = function()
					setStep(step + 1)
				end,
			})
		)
	end
	table.insert(children, section("Button", { row(buttonRow) }))
	table.insert(
		children,
		section("Button states", {
			row({
				React.createElement(
					Button.render,
					{ text = "default", variant = "primary", size = "m" }
				),
				React.createElement(
					Button,
					{ text = "disabled", variant = "primary", size = "m", disabled = true }
				),
				React.createElement(
					Button.render,
					{ text = "small", variant = "secondary", size = "s" }
				),
				React.createElement(
					Button.render,
					{ text = "large", variant = "secondary", size = "l" }
				),
			}),
		})
	)

	-- Icon: every tone and every size
	local iconRow: { any } = {}
	for _, size in { "small", "medium", "large" } do
		table.insert(iconRow, React.createElement(Icon.render, { mark = "M", size = size :: any }))
	end
	table.insert(children, section("Icon", { row(iconRow) }))

	-- Divider
	table.insert(
		children,
		section("Divider", {
			row({
				React.createElement(Divider.render, { size = UDim2.new(1, -32, 0, 1) }),
				React.createElement(
					Divider.render,
					{ size = UDim2.new(1, -32, 0, 1), tone = "strong" }
				),
			}),
		})
	)

	-- Card: every class tone
	local cardRow: { any } = {}
	for _, tone in { "neutral", "working", "middle", "capitalist", "state" } do
		table.insert(
			cardRow,
			React.createElement(Card.render, {
				title = tone,
				tone = tone :: any,
				subtitle = "subtitle",
				size = UDim2.fromOffset(200, 120),
			})
		)
	end
	table.insert(children, section("Card", { row(cardRow) }))

	-- ResourceChip: the resources, a delta, and a hidden value
	local chipRow: { any } = {}
	for _, resource in { "Money", "Influence", "Food", "Goods", "Health", "Education" } do
		table.insert(
			chipRow,
			React.createElement(ResourceChip.render, { resource = resource, amount = 12 })
		)
	end
	table.insert(children, section("ResourceChip", { row(chipRow) }))
	table.insert(
		children,
		section("ResourceChip states", {
			row({
				React.createElement(ResourceChip.render, { resource = "Money", amount = 12 }),
				React.createElement(
					ResourceChip.render,
					{ resource = "Money", amount = 12, delta = 3 }
				),
				React.createElement(
					ResourceChip.render,
					{ resource = "Money", amount = 12, delta = -4 }
				),
				React.createElement(
					ResourceChip,
					{ resource = "Money", amount = 12, hidden = true }
				),
			}),
		})
	)

	-- SegmentedTrack: every tone and a few values
	local trackRow: { any } = {}
	for _, tone in { "fill", "warning", "danger" } do
		table.insert(
			trackRow,
			React.createElement(SegmentedTrack.render, {
				value = 6,
				max = 10,
				tone = tone :: any,
				size = "m",
			})
		)
	end
	table.insert(children, section("SegmentedTrack", { row(trackRow) }))

	-- Stepper
	table.insert(
		children,
		section("Stepper", {
			row({
				React.createElement(Stepper.render, {
					value = step,
					min = 0,
					max = 6,
					onChange = function(value)
						setStep(value)
					end,
				}),
				React.createElement(
					Stepper.render,
					{ value = 0, min = 0, max = 6, disabled = true }
				),
			}),
		})
	)

	-- Tabs
	table.insert(
		children,
		section("Tabs", {
			row({
				React.createElement(Tabs.render, {
					tabs = {
						{ key = "economy", label = "Economy" },
						{ key = "politics", label = "Politics" },
						{ key = "diplomacy", label = "Diplomacy" },
					},
					active = tab,
					onSelect = function(key)
						setTab(key)
					end,
				}),
			}),
		})
	)

	-- Toast
	local toastRow: { any } = {}
	for _, tone in { "info", "success", "warning", "danger" } do
		table.insert(
			toastRow,
			React.createElement(Toast.render, { message = tone, tone = tone :: any })
		)
	end
	table.insert(children, section("Toast", { row(toastRow) }))

	-- Modal
	table.insert(
		children,
		section("Modal", {
			row({
				React.createElement(Button.render, {
					text = "open the modal",
					variant = "primary",
					onClick = function()
						setShowModal(true)
					end,
				}),
			}),
		})
	)
	if showModal then
		table.insert(
			children,
			React.createElement(
				Modal,
				{
					title = "A modal",
					onClose = function()
						setShowModal(false)
					end,
				},
				React.createElement(Text.render, {
					text = "The body of the modal.",
					tone = "secondary",
					size = "s",
				})
			)
		)
	end

	return React.createElement(
		ThemeContext.provider,
		{
			value = skin,
		},
		React.createElement(
			"ScrollingFrame",
			{
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromOffset(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				ScrollBarThickness = 6,
			},
			React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -32, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Position = UDim2.fromOffset(16, 16),
			}, children)
		)
	)
end

return Gallery
