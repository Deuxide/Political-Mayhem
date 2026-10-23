--!strict
-- ClassCard: one of the other three classes, in the corners around the city
-- (UI_SPEC sections 2 and 4.2). The card is the view, not the state: Money,
-- stocks and Influence show as the info mode allows (exact, a tier, or a
-- question mark), while VP, lines and reputation are public in every mode.
--
-- The trade and alliance actions belong to M8; the buttons exist and are
-- disabled until the composer lands.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Game.Types)
local StockMap = require(ReplicatedStorage.Shared.Game.StockMap)
local Reputation = require(ReplicatedStorage.Shared.Game.Ops.Reputation)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)
local Surface = require(script.Parent.Parent.Primitives.Surface)
local Text = require(script.Parent.Parent.Primitives.Text)
local Button = require(script.Parent.Parent.Primitives.Button)
local ResourceChip = require(script.Parent.Parent.Composites.ResourceChip)

type ClassId = Types.ClassId
type ClassView = Types.ClassView
type Tiered = Types.Tiered

export type ClassCardProps = {
	classId: ClassId,
	view: ClassView?, -- nil until the first snapshot
	reputation: Types.Reputation?,
	alliance: Types.Alliance?, -- the alliance the class belongs to (public)
	alliedWithViewer: boolean?,
}

local ClassCard = {}

local PAD = 12
local STARS = 5

local function classKey(classId: ClassId): string
	return string.lower(classId)
end

-- One chip of a field the view may hide or tier: absent is `?`, a PowerTier
-- shows its word, a number shows the number.
local function chip(resourceId: Types.ResourceId, value: Tiered, tone: string): any
	local hidden = value == nil
	local text = if type(value) == "string" then value else nil
	local amount = if type(value) == "number" then value else 0
	return React.createElement(ResourceChip.render, {
		resource = resourceId,
		amount = amount,
		text = text,
		tone = tone :: any,
		hidden = hidden,
	})
end

function ClassCard.render(props: ClassCardProps): any
	local theme = ThemeContext.useTheme()
	local view = props.view
	local tone = classKey(props.classId)
	local width = theme.layout.cornerWidth

	local children: { any } = {}

	-- the header band: the class name and its (always exact) VP
	table.insert(
		children,
		React.createElement(Surface.render, {
			gradient = "accent." .. tone,
			size = UDim2.new(1, 0, 0, 28),
		}, {
			React.createElement(Text.render, {
				text = props.classId,
				tone = "onAccent",
				size = "s",
				uppercase = true,
				position = UDim2.fromOffset(PAD, 0),
				size2 = UDim2.new(1, -PAD * 2, 1, 0),
			}),
			React.createElement(Text.render, {
				text = if view ~= nil then string.format("VP %d", view.vp) else "VP ?",
				tone = "onAccent",
				size = "s",
				align = Enum.TextXAlignment.Right,
				position = UDim2.new(1, -PAD, 0, 0),
				anchorPoint = Vector2.new(1, 0),
				size2 = UDim2.fromOffset(80, 28),
			}),
		})
	)

	local body: { any } = {}

	-- reputation: 0 to 5 stars (8.3), public in every mode
	local starsText = "?"
	if props.reputation ~= nil then
		local filled = math.clamp(math.floor(Reputation.stars(props.reputation) + 0.5), 0, STARS)
		starsText = string.rep("★", filled) .. string.rep("☆", STARS - filled)
	end
	table.insert(
		body,
		React.createElement(Text.render, {
			text = "Reputation",
			tone = "muted",
			size = "xs",
			uppercase = true,
			position = UDim2.fromOffset(PAD, 8),
			size2 = UDim2.fromOffset(120, 18),
		})
	)
	table.insert(
		body,
		React.createElement(Text.render, {
			text = starsText,
			tone = "secondary",
			size = "s",
			align = Enum.TextXAlignment.Right,
			position = UDim2.new(1, -PAD, 0, 8),
			anchorPoint = Vector2.new(1, 0),
			size2 = UDim2.fromOffset(120, 18),
		})
	)

	-- alliance badge: public, and marked when it is the viewer's own alliance
	if props.alliance ~= nil then
		local allied = props.alliedWithViewer == true
		table.insert(
			body,
			React.createElement(
				Surface.render,
				{
					gradient = if allied then "meter.fill" else "surface.raised",
					position = UDim2.fromOffset(PAD, 28),
					size = UDim2.fromOffset(96, 18),
				},
				React.createElement(Text.render, {
					text = if allied then "Allied" else "Alliance",
					tone = if allied then "onAccent" else "muted",
					size = "xs",
					uppercase = true,
					align = Enum.TextXAlignment.Center,
					size2 = UDim2.fromScale(1, 1),
				})
			)
		)
	end

	-- the six resources as the view allows: numbers, tiers, or ?
	local money: Tiered = if view ~= nil then view.money else nil
	local influence: Tiered = if view ~= nil then view.influence else nil
	local values: { [string]: Tiered } = {
		Money = money,
		Influence = influence,
	}
	for index = 1, #Types.STOCK_IDS do
		local stockId: Types.StockId = Types.STOCK_IDS[index] :: any
		local resourceId: Types.ResourceId = StockMap[stockId]
		local stockValue: Tiered = if view ~= nil then view.stock[stockId] else nil
		values[resourceId] = stockValue
	end

	local chips = Types.RESOURCE_IDS
	for index = 1, #chips do
		local resourceId: Types.ResourceId = chips[index] :: any
		local column = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		table.insert(
			body,
			React.createElement("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(
					if column == 0 then PAD else width - PAD - 120,
					52 + row * 28
				),
				Size = UDim2.fromOffset(120, 24),
			}, chip(resourceId, values[resourceId], tone))
		)
	end

	-- the actions of M8: present, visibly not available yet
	table.insert(
		body,
		React.createElement(Button.render, {
			text = "Offer trade",
			variant = "secondary",
			size = "s",
			disabled = true,
			position = UDim2.fromOffset(PAD, 148),
			size2 = UDim2.fromOffset(120, 26),
		})
	)
	table.insert(
		body,
		React.createElement(Button.render, {
			text = "Propose alliance",
			variant = "secondary",
			size = "s",
			disabled = true,
			position = UDim2.fromOffset(140, 148),
			size2 = UDim2.fromOffset(140, 26),
		})
	)

	table.insert(
		children,
		React.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.new(1, 0, 1, -28),
		}, body)
	)

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, children)
end

return ClassCard
