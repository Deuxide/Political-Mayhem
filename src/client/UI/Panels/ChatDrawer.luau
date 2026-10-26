--!strict
-- ChatDrawer: the collapsible chat drawer above the action dock (UI_SPEC
-- sections 2 and 4.2). Three channels — Global, Team (the sender's own
-- class) and Class (a private line to one other class) — with unread badges
-- per channel. The text is filtered by the server before anybody sees it
-- (NETWORKING 3.1, D-025); the drawer only composes and displays.
--
-- The messages come from the store's chat slice (Chat_Message events); a
-- channel the drawer is showing is marked read through onRead, so a channel
-- only accumulates unread while it is closed or in the background.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Game.Types)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)
local Text = require(script.Parent.Parent.Primitives.Text)
local Button = require(script.Parent.Parent.Primitives.Button)
local Surface = require(script.Parent.Parent.Primitives.Surface)

type ChatChannel = Types.ChatChannel
type ClassId = Types.ClassId

export type ChatDrawerProps = {
	open: boolean,
	channels: { [string]: { any } },
	unread: { [string]: number },
	viewer: ClassId?,
	onToggle: () -> (),
	onSend: (channel: ChatChannel, text: string, classTo: ClassId?) -> (),
	onRead: (channel: string) -> (),
}

local ChatDrawer = {}

local WIDTH = 420 -- the dock's width, so the drawer aligns with it
local COLLAPSED = 32
local PAD = 12
local HEADER = 30 -- the channel tab row
local COMPOSER = 34 -- the text box row at the bottom
local PICKER = 30 -- the Class channel's target row
local BUTTON_W = 88
local SEND_W = 64

local CHANNELS: { ChatChannel } = { "Global", "Team", "Class" }

local function trim(text: string): string
	return (string.gsub(string.gsub(text, "^%s+", ""), "%s+$", ""))
end

function ChatDrawer.render(props: ChatDrawerProps): any
	local theme = ThemeContext.useTheme()
	local open = props.open == true

	local activeChannelState, setActiveChannel = React.useState("Global" :: ChatChannel)
	local activeChannel: ChatChannel = activeChannelState :: any
	local pickedClassState, setPickedClass = React.useState(nil :: ClassId?)
	local pickedClass: ClassId? = pickedClassState :: any
	local draftText, setDraftText = React.useState("")

	-- The Class channel's targets: every class but the viewer's own.
	local targets: { ClassId } = {}
	for _, classId in Types.CLASS_IDS do
		local targetId: ClassId = classId :: any
		if targetId ~= props.viewer then
			table.insert(targets, targetId)
		end
	end
	-- The picked target is derived, so a viewer change can never leave a
	-- stale own-class target on the wire.
	local target: ClassId? = pickedClass
	if target == nil or target == props.viewer then
		target = targets[1]
	end

	local messages: { any } = props.channels[activeChannel] or {}

	-- A channel the drawer shows is read: on open, on a tab switch and when
	-- another message arrives while it is open. The unread badge only counts
	-- what the player has not had on screen.
	React.useEffect(function()
		if open then
			props.onRead(activeChannel)
		end
	end, { open, activeChannel, #messages } :: { any })

	-- New messages are read oldest first; the list follows the newest one.
	local scrollRef = React.useRef(nil :: any)
	React.useEffect(function()
		local frame = scrollRef.current
		if frame ~= nil then
			frame.CanvasPosition = Vector2.new(0, frame.AbsoluteCanvasSize.Y)
		end
	end, { activeChannel, #messages } :: { any })

	local function send()
		local text = trim(draftText)
		if text == "" then
			return
		end
		props.onSend(activeChannel, text, if activeChannel == "Class" then target else nil)
		setDraftText("")
	end

	-- ===== The collapsed bar =====
	if not open then
		local unreadTotal = 0
		for _, count in props.unread do
			unreadTotal += count
		end
		local label = if unreadTotal > 0
			then string.format("Chat (%d unread)", unreadTotal)
			else "Chat"
		return React.createElement(
			Surface.render,
			{
				gradient = "surface.header",
				size = UDim2.fromOffset(WIDTH, COLLAPSED),
				position = UDim2.new(
					0.5,
					0,
					1,
					-(theme.spacing.l + theme.layout.dock + theme.spacing.s)
				),
				anchorPoint = Vector2.new(0.5, 1),
				zIndex = 7,
			},
			React.createElement(Button.render, {
				text = label,
				variant = "secondary",
				uppercase = true,
				size2 = UDim2.fromScale(1, 1),
				onClick = props.onToggle,
			})
		)
	end

	-- ===== The open drawer =====
	local pickerHeight = if activeChannel == "Class" then PICKER else 0
	local drawerHeight = theme.layout.chat
	local messagesHeight = drawerHeight - HEADER - pickerHeight - COMPOSER

	local children: { any } = {}

	-- the channel tabs with their unread badges, and the hide button
	for index, channel in CHANNELS do
		table.insert(
			children,
			React.createElement(Button.render, {
				text = string.format("%s (%d)", channel, props.unread[channel] or 0),
				variant = if channel == activeChannel then "primary" else "secondary",
				size = "s",
				position = UDim2.fromOffset(PAD + (index - 1) * (BUTTON_W + 8), 2),
				size2 = UDim2.fromOffset(BUTTON_W, 26),
				onClick = function()
					setActiveChannel(channel)
				end,
			})
		)
	end
	table.insert(
		children,
		React.createElement(Button.render, {
			text = "Hide",
			variant = "ghost",
			size = "s",
			position = UDim2.new(1, -(PAD + 56), 0, 2),
			size2 = UDim2.fromOffset(56, 26),
			onClick = props.onToggle,
		})
	)

	-- the Class channel picks the class the line goes to
	if activeChannel == "Class" then
		table.insert(
			children,
			React.createElement(Text.render, {
				text = "To:",
				tone = "muted",
				size = "xs",
				position = UDim2.fromOffset(PAD, HEADER + 2),
				size2 = UDim2.fromOffset(24, 26),
			})
		)
		for index, classId in targets do
			table.insert(
				children,
				React.createElement(Button.render, {
					text = classId,
					variant = if classId == target then "primary" else "secondary",
					size = "s",
					position = UDim2.fromOffset(
						PAD + 28 + (index - 1) * (BUTTON_W + 8),
						HEADER + 2
					),
					size2 = UDim2.fromOffset(BUTTON_W, 26),
					onClick = function()
						setPickedClass(classId)
					end,
				})
			)
		end
	end

	-- the messages of the active channel, oldest first, the list growing
	-- with its content
	local rows: { any } = {
		React.createElement("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	if #messages == 0 then
		table.insert(
			rows,
			React.createElement(Text.render, {
				text = "No messages in " .. activeChannel .. " yet",
				tone = "muted",
				size = "xs",
				layoutOrder = 0,
			})
		)
	end
	for index, message in messages do
		table.insert(
			rows,
			React.createElement(Text.render, {
				text = string.format("%s: %s", message.fromName, message.text),
				tone = if message.fromClass == props.viewer then "secondary" else "primary",
				size = "xs",
				wrapped = true,
				automatic = true,
				layoutOrder = index,
				size2 = UDim2.new(1, -8, 0, 0),
			})
		)
	end
	table.insert(
		children,
		React.createElement("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(PAD, HEADER + pickerHeight),
			Size = UDim2.new(1, -PAD * 2, 0, messagesHeight),
			CanvasSize = UDim2.fromScale(1, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = theme.colors["line.strong"],
			ref = scrollRef,
		}, React.createElement(React.Fragment, nil, rows))
	)

	-- the composer: the text box and the send button
	local composerY = drawerHeight - COMPOSER
	table.insert(
		children,
		React.createElement("TextBox", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(PAD, composerY + 4),
			Size = UDim2.new(1, -(PAD * 2 + SEND_W + 8), 0, 26),
			Text = draftText,
			PlaceholderText = "Message " .. activeChannel .. (if activeChannel == "Class"
				then " (" .. (target or "") .. ")"
				else ""),
			PlaceholderColor3 = theme.colors["text.muted"],
			TextColor3 = theme.colors["text.primary"],
			TextSize = theme.type.s,
			Font = theme.font.family,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			ClearTextOnFocus = false,
			ClipsDescendants = true,
			[React.Change.Text] = function(rbx: any)
				setDraftText(rbx.Text)
			end,
			[React.Event.FocusLost] = function(enterPressed: boolean)
				if enterPressed then
					send()
				end
			end,
		})
	)
	table.insert(
		children,
		React.createElement(Button.render, {
			text = "Send",
			variant = "primary",
			size = "s",
			disabled = trim(draftText) == "",
			position = UDim2.new(1, -(PAD + SEND_W), 0, composerY + 4),
			size2 = UDim2.fromOffset(SEND_W, 26),
			onClick = send,
		})
	)

	return React.createElement(Surface.render, {
		gradient = "surface.card",
		size = UDim2.fromOffset(WIDTH, drawerHeight),
		position = UDim2.new(0.5, 0, 1, -(theme.spacing.l + theme.layout.dock + theme.spacing.s)),
		anchorPoint = Vector2.new(0.5, 1),
		zIndex = 7,
	}, React.createElement(React.Fragment, nil, children))
end

return ChatDrawer
