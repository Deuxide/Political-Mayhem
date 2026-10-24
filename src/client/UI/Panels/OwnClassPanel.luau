--!strict
-- OwnClassPanel: the viewer's own class, always bottom-left and fully
-- interactive (UI_SPEC sections 2 and 4.2). It shows the six resource chips,
-- this Day's needs against the stock, the VP criteria of the class, a summary
-- of the sticky draft, and the tab buttons that choose the dock's tab.
--
-- Everything is read from the view and the draft; the panel computes no rule.
-- The needs arrive already scaled by the difficulty (Game/Needs via the
-- PlayerViewBuilder), and the criteria are Config/Objectives data with a
-- display label per id.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Game.Types)
local StockMap = require(ReplicatedStorage.Shared.Game.StockMap)
local ConfigResources = require(ReplicatedStorage.Shared.Config.Resources)
local ConfigObjectives = require(ReplicatedStorage.Shared.Config.Objectives)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)
local Surface = require(script.Parent.Parent.Primitives.Surface)
local Text = require(script.Parent.Parent.Primitives.Text)
local Divider = require(script.Parent.Parent.Primitives.Divider)
local ResourceChip = require(script.Parent.Parent.Composites.ResourceChip)
local Tabs = require(script.Parent.Parent.Composites.Tabs)

type ActionDraft = Types.ActionDraft
type ClassId = Types.ClassId
type PlayerView = Types.PlayerView
type StockId = Types.StockId

export type OwnClassPanelProps = {
	view: PlayerView,
	draft: ActionDraft,
	activeTab: string,
	onTab: ((tab: string) -> ())?,
}

local OwnClassPanel = {}

local TABS: { { key: string, label: string } } = {
	{ key = "economy", label = "Economy" },
	{ key = "politics", label = "Politics" },
	{ key = "diplomacy", label = "Diplomacy" },
}

-- The panel's ink and geometry (a corner is 300 wide; UI_SPEC section 2).
local PAD = 12
local ROW = 18
local CHIP_ROW = 28

local function classKey(classId: ClassId): string
	return string.lower(classId)
end

-- The player-facing line of one VP criterion (Config/Objectives). An id the
-- panel does not know yet shows as itself rather than disappearing.
local function criterionLabel(objective: any): string
	local id = objective.id
	local params = objective.params or {}
	if id == "needsMet" then
		return "All needs met"
	elseif id == "employmentAtLeast" then
		return string.format("Employment %d%% or more", math.floor(params.fraction * 100))
	elseif id == "wageAtLeast" then
		return string.format("Wage level %d or higher", params.level)
	elseif id == "ownBillPassed" then
		return "A bill you proposed passed"
	elseif id == "educationStockAtLeast" then
		return string.format("Education stock %d or more", params.amount)
	elseif id == "moneyGainAtLeast" then
		return string.format("Gain %d Money or more", params.amount)
	elseif id == "ownsLinesAtLeast" then
		return string.format("Own %d lines or more", params.count)
	elseif id == "moneyGainScaled" then
		return string.format("Profit: 1 VP per %d (max %d)", params.divisor, objective.vp)
	elseif id == "taxCapitalistAtMost" then
		return string.format("Corporate tax level %d or lower", params.level)
	elseif id == "moneyNotDecreasing" then
		return "Money not decreasing"
	elseif id == "stabilityAtLeast" then
		return string.format("Stability %d or more", params.level)
	elseif id == "publicStaffingAtLeast" then
		return string.format("Public lines %d%% staffed", math.floor(params.fraction * 100))
	end
	return id
end

-- The sticky-draft summary: what is set, in the order the draft groups it.
local function draftLines(draft: ActionDraft): { string }
	local slots = 0
	for _, amount in draft.openSlots do
		if amount > 0 then
			slots += 1
		end
	end
	local assigned = 0
	for _, amount in draft.assign do
		assigned += amount
	end
	local votes = 0
	for _ in draft.votes do
		votes += 1
	end
	local sell = 0
	for _, amount in draft.market.sell do
		sell += amount
	end
	local buy = 0
	for _, amount in draft.market.buy do
		buy += amount
	end

	local top: { string } = {}
	if slots > 0 then
		table.insert(top, string.format("slots on %d lines", slots))
	end
	if assigned > 0 then
		table.insert(top, string.format("assigned %d", assigned))
	end
	if draft.strike ~= nil then
		table.insert(top, "strike " .. draft.strike.target)
	end
	if draft.build ~= nil then
		table.insert(top, "build " .. draft.build.lineType)
	end

	local bottom: { string } = {}
	if sell > 0 then
		table.insert(bottom, string.format("sell %d", sell))
	end
	if buy > 0 then
		table.insert(bottom, string.format("buy %d", buy))
	end
	if draft.lobby ~= nil then
		table.insert(bottom, string.format("lobby %d", draft.lobby.amount))
	end
	if votes > 0 then
		table.insert(bottom, string.format("%d votes", votes))
	end
	table.insert(bottom, if draft.locked then "locked" else "open")

	local lines: { string } = {}
	if #top > 0 then
		table.insert(lines, table.concat(top, " / "))
	end
	if #bottom > 1 or #top > 0 then
		table.insert(lines, table.concat(bottom, " / "))
	end
	if #lines == 0 then
		table.insert(lines, "no changes - last Day carries over")
	end
	return lines
end

function OwnClassPanel.render(props: OwnClassPanelProps): any
	local theme = ThemeContext.useTheme()
	local view = props.view
	local own = view.own
	local tone = classKey(own.id)
	local width = theme.layout.cornerWidth
	local height = theme.layout.cornerHeight

	local children: { any } = {}

	-- the header band: the class name and its VP
	table.insert(
		children,
		React.createElement(Surface.render, {
			gradient = "accent." .. tone,
			size = UDim2.new(1, 0, 0, 28),
		}, {
			React.createElement(Text.render, {
				text = own.id,
				tone = "onAccent",
				size = "s",
				uppercase = true,
				position = UDim2.fromOffset(PAD, 0),
				size2 = UDim2.new(1, -PAD * 2, 1, 0),
			}),
			React.createElement(Text.render, {
				text = string.format("VP %d", own.vp),
				tone = "onAccent",
				size = "s",
				align = Enum.TextXAlignment.Right,
				position = UDim2.new(1, -PAD, 0, 0),
				anchorPoint = Vector2.new(1, 0),
				size2 = UDim2.fromOffset(80, 28),
			}),
		})
	)

	-- the body: resources, needs, criteria and the draft, then the tabs
	local body: { any } = {}
	local y = 0

	local function heading(text: string, atY: number)
		table.insert(
			body,
			React.createElement(Text.render, {
				text = text,
				tone = "muted",
				size = "xs",
				uppercase = true,
				position = UDim2.fromOffset(PAD, atY),
				size2 = UDim2.fromOffset(width - PAD, ROW),
			})
		)
	end

	-- 1. the six resource chips: Money, Influence, Food, Goods, Health, Education
	heading("Resources", y)
	y += ROW
	local chips = Types.RESOURCE_IDS
	for index = 1, #chips do
		local resourceId: Types.ResourceId = chips[index] :: any
		local column = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		local amount = 0
		local stockKey = (ConfigResources :: any)[resourceId].stockKey
		if resourceId == "Money" then
			amount = own.money
		elseif resourceId == "Influence" then
			amount = own.influence
		elseif stockKey ~= nil then
			amount = own.stock[stockKey] or 0
		end
		table.insert(
			body,
			React.createElement(
				"Frame",
				{
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(
						if column == 0 then PAD else width - PAD - 120,
						row * CHIP_ROW + y
					),
					Size = UDim2.fromOffset(120, 24),
				},
				React.createElement(ResourceChip.render, {
					resource = resourceId,
					amount = amount,
					tone = tone :: any,
				})
			)
		)
	end
	y += CHIP_ROW * 3

	-- 2. the Day's needs against the stock
	heading("Needs this Day", y + 4)
	y += ROW + 4
	local needRows = 0
	for index = 1, #Types.STOCK_IDS do
		local stockId: StockId = Types.STOCK_IDS[index] :: any
		local required = view.needs[stockId] or 0
		if required > 0 then
			local held = own.stock[stockId] or 0
			local short = held < required
			local resourceId: Types.ResourceId = StockMap[stockId]
			local name = (ConfigResources :: any)[resourceId].name
			table.insert(
				body,
				React.createElement(Text.render, {
					text = name,
					tone = "secondary",
					size = "s",
					position = UDim2.fromOffset(PAD, y),
					size2 = UDim2.fromOffset(120, ROW),
				})
			)
			table.insert(
				body,
				React.createElement(Text.render, {
					text = string.format("%d / %d", held, required),
					tone = if short then "danger" else "success",
					size = "s",
					align = Enum.TextXAlignment.Right,
					position = UDim2.new(1, -PAD, 0, y),
					anchorPoint = Vector2.new(1, 0),
					size2 = UDim2.fromOffset(120, ROW),
				})
			)
			y += ROW
			needRows += 1
		end
	end
	if needRows == 0 then
		table.insert(
			body,
			React.createElement(Text.render, {
				text = "None - no needs this Day",
				tone = "muted",
				size = "s",
				position = UDim2.fromOffset(PAD, y),
				size2 = UDim2.fromOffset(width - PAD, ROW),
			})
		)
		y += ROW
	end

	-- 3. the VP criteria of the class (Config/Objectives)
	y += 6
	table.insert(
		body,
		React.createElement(Divider.render, {
			position = UDim2.fromOffset(PAD, y),
			size = UDim2.new(1, -PAD * 2, 0, theme.border.hairline),
		})
	)
	y += 10
	heading("Victory criteria", y)
	y += ROW
	local objectives = (ConfigObjectives :: any)[own.id]
	for _, objective in objectives do
		table.insert(
			body,
			React.createElement(Text.render, {
				text = criterionLabel(objective),
				tone = "secondary",
				size = "xs",
				position = UDim2.fromOffset(PAD, y),
				size2 = UDim2.new(1, -PAD * 2 - 40, 0, ROW),
			})
		)
		local vp = objective.vp or 1
		table.insert(
			body,
			React.createElement(Text.render, {
				text = string.format("%d VP", vp),
				tone = "muted",
				size = "xs",
				align = Enum.TextXAlignment.Right,
				position = UDim2.new(1, -PAD, 0, y),
				anchorPoint = Vector2.new(1, 0),
				size2 = UDim2.fromOffset(40, ROW),
			})
		)
		y += ROW
	end

	-- 4. the sticky draft, then the tab strip
	y += 6
	table.insert(
		body,
		React.createElement(Divider.render, {
			position = UDim2.fromOffset(PAD, y),
			size = UDim2.new(1, -PAD * 2, 0, theme.border.hairline),
		})
	)
	y += 10
	heading("Draft", y)
	y += ROW
	for _, line in draftLines(props.draft) do
		table.insert(
			body,
			React.createElement(Text.render, {
				text = line,
				tone = "secondary",
				size = "xs",
				position = UDim2.fromOffset(PAD, y),
				size2 = UDim2.new(1, -PAD * 2, 0, ROW),
			})
		)
		y += ROW
	end

	local bodyHeight = height - 28 - 30
	local bodyChildren: { any } = {
		React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(width, y + PAD),
		}, body),
	}

	table.insert(
		children,
		React.createElement("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.new(1, 0, 0, bodyHeight),
			CanvasSize = UDim2.new(1, 0, 0, y + PAD),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = theme.colors["line.strong"],
		}, bodyChildren)
	)

	table.insert(
		children,
		React.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 1, -30),
			Size = UDim2.new(1, 0, 0, 30),
		}, {
			React.createElement(Tabs.render, {
				tabs = TABS,
				active = props.activeTab,
				onSelect = props.onTab,
			}),
		})
	)

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, children)
end

return OwnClassPanel
