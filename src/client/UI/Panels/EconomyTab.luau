--!strict
-- EconomyTab: the economic half of the action dock (UI_SPEC section 4.2) —
-- the lines the class owns and their open slots, the Working's worker
-- assignments and strike, one build order, the market sell/buy orders and
-- the lobby Influence purchase. Every control edits the local draft; the App
-- debounces the send (NETWORKING section 4), and the header's sync indicator
-- shows whether the server has the latest copy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Game.Types)
local ConfigClasses = require(ReplicatedStorage.Shared.Config.Classes)
local ConfigLines = require(ReplicatedStorage.Shared.Config.Lines)
local ConfigMarket = require(ReplicatedStorage.Shared.Config.Market)
local ConfigResources = require(ReplicatedStorage.Shared.Config.Resources)
local StockMap = require(ReplicatedStorage.Shared.Game.StockMap)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)
local Text = require(script.Parent.Parent.Primitives.Text)
local Button = require(script.Parent.Parent.Primitives.Button)
local Stepper = require(script.Parent.Parent.Composites.Stepper)

type ClassId = Types.ClassId
type LineId = Types.LineId
type LineType = Types.LineType
type LineView = Types.LineView
type StockId = Types.StockId

export type SyncState = "clean" | "pending" | "rejected"

export type EconomyTabProps = {
	view: Types.PlayerView,
	draft: Types.ActionDraft,
	syncState: SyncState,
	onOpenSlots: (LineId, number) -> (),
	onAssign: (LineId, number) -> (),
	onStrike: (ClassId?) -> (),
	onBuild: (LineType?) -> (),
	onLobby: (number) -> (),
	onMarket: (side: "sell" | "buy", stockId: StockId, volume: number) -> (),
}

local EconomyTab = {}

local PAD = 12
local ROW = 28
local HEADER = 24
local SECTION = 20
local STEPPER = 150
local MARKET_COLUMN = 222
local WIDTH = 392

local function stockName(stockId: StockId): string
	local resourceId: Types.ResourceId = StockMap[stockId]
	return ConfigResources[resourceId].name
end

-- The other three classes in Types.CLASS_IDS order; the strike targets.
local function otherClasses(viewer: ClassId): { ClassId }
	local result: { ClassId } = {}
	for index = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[index] :: any
		if classId ~= viewer then
			table.insert(result, classId)
		end
	end
	return result
end

-- All lines in the match, sorted by id: the Working assigns workers to every
-- class's lines, not only its own (6.3). The view carries the own lines and
-- the other classes' lines (exact in every mode, 13).
local function allLines(view: Types.PlayerView): { LineView }
	local result: { LineView } = {}
	for _, line in view.ownLines do
		table.insert(result, line)
	end
	for index = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[index] :: any
		local other = view.others[classId]
		if other ~= nil then
			for _, line in other.lines do
				table.insert(result, line)
			end
		end
	end
	table.sort(result, function(a, b)
		return a.id < b.id
	end)
	return result
end

function EconomyTab.render(props: EconomyTabProps): any
	local theme = ThemeContext.useTheme()
	local view = props.view
	local draft = props.draft
	local viewer: ClassId = view.viewer :: any
	local entry = ConfigClasses.entries[viewer]
	local lobbyConfig = entry.lobby

	local children: { any } = {}

	-- the header: the tab name and the sync state (NETWORKING 4)
	table.insert(
		children,
		React.createElement(Text.render, {
			text = "Economy",
			tone = "muted",
			size = "xs",
			uppercase = true,
			position = UDim2.fromOffset(PAD, 0),
			size2 = UDim2.fromOffset(120, HEADER),
		})
	)

	local syncText = "saved"
	local syncTone: any = "success"
	if props.syncState == "pending" then
		syncText = "saving"
		syncTone = "warning"
	elseif props.syncState == "rejected" then
		syncText = "rejected"
		syncTone = "danger"
	end
	table.insert(
		children,
		React.createElement(Text.render, {
			text = syncText,
			tone = syncTone,
			size = "xs",
			align = Enum.TextXAlignment.Right,
			position = UDim2.new(1, -PAD, 0, 0),
			anchorPoint = Vector2.new(1, 0),
			size2 = UDim2.fromOffset(100, HEADER),
		})
	)

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
				position = UDim2.fromOffset(0, atY),
				size2 = UDim2.fromOffset(WIDTH, SECTION),
			})
		)
	end

	local function label(text: string, x: number, atY: number, width: number, tone: any?)
		table.insert(
			body,
			React.createElement(Text.render, {
				text = text,
				tone = tone or "secondary",
				size = "xs",
				position = UDim2.fromOffset(x, atY),
				size2 = UDim2.fromOffset(width, ROW),
			})
		)
	end

	local function stepper(
		value: number,
		min: number,
		max: number,
		x: number,
		atY: number,
		onChange: (number) -> ()
	)
		table.insert(
			body,
			React.createElement(Stepper.render, {
				value = value,
				min = min,
				max = max,
				position = UDim2.fromOffset(x, atY),
				onChange = onChange,
			})
		)
	end

	if viewer == "Working" then
		-- The Working owns the worker pool and assigns it across every line
		-- (6.3); the open slots belong to the line owners.
		heading("Assign workers", y)
		y += SECTION
		local totalAssigned = 0
		for _, volume in draft.assign do
			totalAssigned += volume
		end
		for _, line in allLines(view) do
			local open = draft.openSlots[line.id] or line.openSlots
			local current = draft.assign[line.id] or 0
			local room = math.max(0, view.own.workers - (totalAssigned - current))
			local max = math.min(open, room)
			label(line.id, 0, y, 64)
			label(theme.icons[line.owner] or "?", 66, y, 20, "muted")
			label(string.format("open %d", open), 88, y, 60, "muted")
			stepper(current, 0, max, 150, y, function(value)
				props.onAssign(line.id, value)
			end)
			y += ROW
		end
	else
		-- The line owner sets how many slots are open; sticky across Days (6.1).
		heading("Lines", y)
		y += SECTION
		if #view.ownLines == 0 then
			label("no lines", 0, y, 200, "muted")
			y += ROW
		end
		for _, line in view.ownLines do
			local current = draft.openSlots[line.id] or line.openSlots
			local max = ConfigLines[line.type].slotsMax
			label(line.id, 0, y, 120)
			label("open slots", 120, y, 80, "muted")
			stepper(current, 0, max, 200, y, function(value)
				props.onOpenSlots(line.id, value)
			end)
			y += ROW
		end
	end

	if viewer == "Working" then
		-- One strike target this Day (6.5); clicking the active target clears it.
		heading("Strike", y)
		y += SECTION
		local targets = otherClasses(viewer)
		for index, rawTarget in targets do
			local classId: ClassId = rawTarget :: any
			local active = draft.strike ~= nil and draft.strike.target == classId
			table.insert(
				body,
				React.createElement(Button.render, {
					text = classId,
					variant = if active then "primary" else "secondary",
					size = "s",
					position = UDim2.fromOffset((index - 1) * 100, y),
					size2 = UDim2.fromOffset(96, 26),
					onClick = function()
						props.onStrike(if active then nil else classId)
					end,
				})
			)
		end
		y += ROW
	end

	if #entry.canBuild > 0 then
		-- One build order per Day, paid at Closing Bell (6.2); clicking the
		-- active type clears it. An unaffordable type is shown disabled.
		heading("Build", y)
		y += SECTION
		for index, rawLineType in entry.canBuild do
			local lineType: LineType = rawLineType :: any
			local cost = ConfigLines[lineType].buildCost
			local active = draft.build ~= nil and draft.build.lineType == lineType
			table.insert(
				body,
				React.createElement(Button.render, {
					text = string.format("%s %d", lineType, cost),
					variant = if active then "primary" else "secondary",
					size = "s",
					position = UDim2.fromOffset((index - 1) * 110, y),
					size2 = UDim2.fromOffset(104, 26),
					disabled = not active and view.own.money < cost,
					onClick = function()
						props.onBuild(if active then nil else lineType)
					end,
				})
			)
		end
		y += ROW
	end

	-- Market (6.6): at most ConfigMarket.volumeCap units per side, sells and
	-- buys separately (D-048). The steppers cap each side's running total.
	heading("Market", y)
	y += SECTION
	label("stock", 0, y, 60, "muted")
	label("sell", 68, y, STEPPER, "muted")
	label("buy", MARKET_COLUMN, y, STEPPER, "muted")
	y += SECTION
	local sellTotal = 0
	for _, volume in draft.market.sell do
		sellTotal += volume
	end
	local buyTotal = 0
	for _, volume in draft.market.buy do
		buyTotal += volume
	end
	for index = 1, #Types.STOCK_IDS do
		local stockId: StockId = Types.STOCK_IDS[index] :: any
		local sellCurrent = draft.market.sell[stockId] or 0
		local buyCurrent = draft.market.buy[stockId] or 0
		local sellMax = math.max(0, ConfigMarket.volumeCap - (sellTotal - sellCurrent))
		local buyMax = math.max(0, ConfigMarket.volumeCap - (buyTotal - buyCurrent))
		label(stockName(stockId), 0, y, 64)
		stepper(sellCurrent, 0, sellMax, 68, y, function(value)
			props.onMarket("sell", stockId, value)
		end)
		stepper(buyCurrent, 0, buyMax, MARKET_COLUMN, y, function(value)
			props.onMarket("buy", stockId, value)
		end)
		y += ROW
	end

	if lobbyConfig ~= nil then
		-- Middle and Capitalist buy Influence with Money at R2 (7.1); the
		-- request may not pass the shared Influence cap (D-055).
		heading("Lobby", y)
		y += SECTION
		local current = if draft.lobby ~= nil then draft.lobby.amount else 0
		local affordable = math.floor(view.own.money / lobbyConfig.moneyPerInfluence)
		local room = ConfigClasses.influenceCap - view.own.influence
		local max = math.max(0, math.min(lobbyConfig.maxInfluence, affordable, room))
		label("Influence", 0, y, 64)
		stepper(current, 0, max, 68, y, function(value)
			props.onLobby(value)
		end)
		label(
			string.format(
				"%d Money each, max %d",
				lobbyConfig.moneyPerInfluence,
				lobbyConfig.maxInfluence
			),
			MARKET_COLUMN,
			y,
			170,
			"muted"
		)
		y += ROW
	end

	local contentHeight = y + PAD
	local bodyChildren: { any } = {
		React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, contentHeight),
		}, body),
	}

	table.insert(
		children,
		React.createElement("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(PAD, HEADER),
			Size = UDim2.new(1, -PAD * 2, 1, -(HEADER + PAD)),
			CanvasSize = UDim2.new(1, 0, 0, contentHeight),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = theme.colors["line.strong"],
		}, bodyChildren)
	)

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, children)
end

return EconomyTab
