--!strict
-- GalleryScreen: dev-only component gallery showing all components in all states.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local Surface = require(script.Parent.Parent.Primitives.Surface)
local Text = require(script.Parent.Parent.Primitives.Text)
local Button = require(script.Parent.Parent.Primitives.Button)
local Icon = require(script.Parent.Parent.Primitives.Icon)
local Divider = require(script.Parent.Parent.Primitives.Divider)
local TrackSegment = require(script.Parent.Parent.Primitives.TrackSegment)
local Card = require(script.Parent.Parent.Composites.Card)
local ResourceChip = require(script.Parent.Parent.Composites.ResourceChip)
local SegmentedTrack = require(script.Parent.Parent.Composites.SegmentedTrack)
local Stepper = require(script.Parent.Parent.Composites.Stepper)
local Tabs = require(script.Parent.Parent.Composites.Tabs)
local Modal = require(script.Parent.Parent.Composites.Modal)
local Toast = require(script.Parent.Parent.Composites.Toast)
local StatRow = require(script.Parent.Parent.Composites.StatRow)
local ClassHeader = require(script.Parent.Parent.Composites.ClassHeader)
local Tooltip = require(script.Parent.Parent.Composites.Tooltip)

export type GalleryScreenProps = {
	onClose: () -> (),
}

local function GalleryScreen(props: GalleryScreenProps)
	local modalOpen, setModalOpen = React.useState(false)
	local toastVisible, setToastVisible = React.useState(false)
	local tooltipVisible, setTooltipVisible = React.useState(false)

	return React.createElement(Surface, {
		gradientRole = "tableBackground",
		size = UDim2.fromScale(1, 1),
	}, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 16),
		}),
		Header = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -32, 0, 50),
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Title = React.createElement(Text, {
				text = "COMPONENT GALLERY",
				size = "xl",
				weight = "bold",
			}),
			CloseButton = React.createElement(Button, {
				text = "Close",
				variant = "secondary",
				onClick = props.onClose,
			}),
		}),
		Content = React.createElement("ScrollingFrame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -32, 1, -66),
			CanvasSize = UDim2.new(0, 0, 0, 2000),
			ScrollBarThickness = 8,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 16),
			}),
			-- Primitives section
			PrimitivesSection = React.createElement(Card, {
				title = "Primitives",
				tone = "neutral",
				size = UDim2.new(1, 0, 0, 0),
				automaticSize = Enum.AutomaticSize.Y,
			}, {
				UIListLayout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, 12),
				}),
				Buttons = React.createElement("Frame", {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.XY,
				}, {
					UIListLayout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 8),
					}),
					Primary = React.createElement(
						Button,
						{ text = "Primary", variant = "primary", size = "md" }
					),
					Secondary = React.createElement(
						Button,
						{ text = "Secondary", variant = "secondary", size = "md" }
					),
					Danger = React.createElement(
						Button,
						{ text = "Danger", variant = "danger", size = "md" }
					),
					Ghost = React.createElement(
						Button,
						{ text = "Ghost", variant = "ghost", size = "md", tone = "working" }
					),
					Disabled = React.createElement(
						Button,
						{ text = "Disabled", variant = "primary", size = "md", disabled = true }
					),
				}),
				Texts = React.createElement("Frame", {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.XY,
				}, {
					UIListLayout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 16),
					}),
					Neutral = React.createElement(
						Text,
						{ text = "Neutral", tone = "neutral", size = "md" }
					),
					Working = React.createElement(
						Text,
						{ text = "Working", tone = "working", size = "md" }
					),
					Middle = React.createElement(
						Text,
						{ text = "Middle", tone = "middle", size = "md" }
					),
					Capitalist = React.createElement(
						Text,
						{ text = "Capitalist", tone = "capitalist", size = "md" }
					),
					State = React.createElement(
						Text,
						{ text = "State", tone = "state", size = "md" }
					),
					Success = React.createElement(
						Text,
						{ text = "Success", tone = "success", size = "md" }
					),
					Warning = React.createElement(
						Text,
						{ text = "Warning", tone = "warning", size = "md" }
					),
					Danger = React.createElement(
						Text,
						{ text = "Danger", tone = "danger", size = "md" }
					),
				}),
				TrackSegments = React.createElement("Frame", {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.XY,
				}, {
					UIListLayout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 4),
					}),
					Normal = React.createElement(
						TrackSegment,
						{ filled = true, state = "normal", size = "md" }
					),
					Warning = React.createElement(
						TrackSegment,
						{ filled = true, state = "warning", size = "md" }
					),
					Danger = React.createElement(
						TrackSegment,
						{ filled = true, state = "danger", size = "md" }
					),
					Empty = React.createElement(
						TrackSegment,
						{ filled = false, state = "normal", size = "md" }
					),
				}),
			}),
			-- Composites section
			CompositesSection = React.createElement(Card, {
				title = "Composites",
				tone = "neutral",
				size = UDim2.new(1, 0, 0, 0),
				automaticSize = Enum.AutomaticSize.Y,
			}, {
				UIListLayout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, 12),
				}),
				ResourceChips = React.createElement("Frame", {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.XY,
				}, {
					UIListLayout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 8),
					}),
					Chip1 = React.createElement(
						ResourceChip,
						{ resource = "Money", amount = 10, delta = 2, tone = "working" }
					),
					Chip2 = React.createElement(
						ResourceChip,
						{ resource = "Food", amount = 5, delta = -1, tone = "middle" }
					),
					Chip3 = React.createElement(
						ResourceChip,
						{ resource = "Goods", amount = 8, tone = "capitalist" }
					),
				}),
				SegmentedTracks = React.createElement("Frame", {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.XY,
				}, {
					UIListLayout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 16),
					}),
					Track1 = React.createElement(SegmentedTrack, {
						value = 3,
						max = 10,
						size = "md",
						warningThreshold = 7,
						dangerThreshold = 9,
					}),
					Track2 = React.createElement(SegmentedTrack, {
						value = 8,
						max = 10,
						size = "md",
						warningThreshold = 7,
						dangerThreshold = 9,
					}),
				}),
				Stepper = React.createElement(Stepper, {
					value = 5,
					min = 0,
					max = 10,
					onChange = function() end,
					size = "md",
				}),
				StatRows = React.createElement("Frame", {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.Y,
				}, {
					UIListLayout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 4),
					}),
					Row1 = React.createElement(
						StatRow,
						{ label = "Money", value = 100, tone = "working", showDivider = true }
					),
					Row2 = React.createElement(
						StatRow,
						{ label = "Influence", value = 25, tone = "neutral", showDivider = true }
					),
					Row3 = React.createElement(
						StatRow,
						{ label = "Stability", value = "75%", tone = "success" }
					),
				}),
				ClassHeader = React.createElement(ClassHeader, {
					classId = "Working",
					victoryPoints = 3,
					maxVP = 10,
					stability = 75,
				}),
			}),
			-- Interactive section
			InteractiveSection = React.createElement(Card, {
				title = "Interactive",
				tone = "neutral",
				size = UDim2.new(1, 0, 0, 0),
				automaticSize = Enum.AutomaticSize.Y,
			}, {
				UIListLayout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, 12),
				}),
				ModalButton = React.createElement(Button, {
					text = "Open Modal",
					variant = "primary",
					onClick = function() setModalOpen(true) end,
				}),
				ToastButton = React.createElement(Button, {
					text = "Show Toast",
					variant = "secondary",
					onClick = function() setToastVisible(true) end,
				}),
				TooltipHover = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(200, 40),
				}, {
					HoverButton = React.createElement(Button, {
						text = "Hover for Tooltip",
						variant = "secondary",
						size = "md",
					}),
				}),
			}),
		}),
		-- Modals/Toasts (rendered on top)
		Modal = React.createElement(Modal, {
			open = modalOpen,
			title = "Test Modal",
			onClose = function() setModalOpen(false) end,
			actions = {
				{
					text = "Cancel",
					variant = "secondary",
					onClick = function() setModalOpen(false) end,
				},
				{
					text = "Confirm",
					variant = "primary",
					onClick = function() setModalOpen(false) end,
				},
			},
		}, {
			Body = React.createElement(
				Text,
				{ text = "This is a modal dialog with actions.", size = "md" }
			),
		}),
		Toast = React.createElement(Toast, {
			message = "This is a success toast!",
			tone = "success",
			duration = 2,
			onDismiss = function() setToastVisible(false) end,
		}),
		Tooltip = React.createElement(Tooltip, {
			text = "This is a tooltip",
			visible = tooltipVisible,
			position = UDim2.fromScale(0.5, -0.1),
		}),
	})
end

return GalleryScreen
