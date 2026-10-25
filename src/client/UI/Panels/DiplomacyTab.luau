--!strict
-- DiplomacyTab: the diplomatic half of the action dock (UI_SPEC 4.2,
-- GAME_DESIGN 8.2 and 8.3). It shows the live trade offers in both
-- directions, the trade composer and the public promise ledger.
--
-- The offers are not part of the PlayerView: the server sends them as
-- Trade_Incoming / Trade_Result events and the store keeps the inbox/outbox
-- (Store.TradeEntry). The ledger is the view's public promises, patched in
-- when an accepted trade creates a promise record.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Game.Types)
local ConfigResources = require(ReplicatedStorage.Shared.Config.Resources)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)
local Text = require(script.Parent.Parent.Primitives.Text)
local Button = require(script.Parent.Parent.Primitives.Button)
local Card = require(script.Parent.Parent.Composites.Card)
local PromiseBuilder = require(script.Parent.PromiseBuilder)
local TradeComposer = require(script.Parent.TradeComposer)
local Store = require(script.Parent.Parent.Parent.State.Store)

type ClassId = Types.ClassId
type Phase = Types.Phase
type PlayerView = Types.PlayerView
type PromiseSpec = Types.PromiseSpec
type ResourceBag = Types.ResourceBag
type ResourceId = Types.ResourceId
type TradeEntry = Store.TradeEntry

export type DiplomacyTabProps = {
	view: PlayerView,
	phase: Phase,
	offers: { TradeEntry },
	notices: { any },
	onPropose: (
		requestId: string,
		to: ClassId,
		give: ResourceBag,
		want: ResourceBag,
		promises: { PromiseSpec }
	) -> (),
	onRespond: (offerId: string, accept: boolean) -> (),
	onCancel: (offerId: string) -> (),
}

local DiplomacyTab = {}

local PAD = 12
local WIDTH = 392
local HEADER = 24
local SECTION = 20
local CARD_HEIGHT = 136
local LEDGER_ROW = 44
local EMPTY = 28

local function describeBag(bag: ResourceBag): string
	local parts: { string } = {}
	for _, rawResourceId in Types.RESOURCE_IDS do
		local resourceId: ResourceId = rawResourceId :: any
		local amount = bag[resourceId]
		if amount ~= nil and amount > 0 then
			table.insert(
				parts,
				string.format("%d %s", amount, (ConfigResources :: any)[resourceId].name)
			)
		end
	end
	if #parts == 0 then
		return "nothing"
	end
	return table.concat(parts, ", ")
end

local function describePromises(specs: { PromiseSpec }, promisee: ClassId): string
	if #specs == 0 then
		return "No promise"
	end
	local parts: { string } = {}
	for _, spec in specs do
		table.insert(parts, PromiseBuilder.describeSpec(spec, promisee))
	end
	return "Promise: " .. table.concat(parts, "; ")
end

local function statusLabel(entry: TradeEntry): string
	if entry.pendingAck == true then
		return "sending..."
	end
	if entry.reason ~= nil and entry.reason ~= "" then
		return string.format("%s: %s", entry.status, entry.reason)
	end
	return entry.status
end

local function statusTone(entry: TradeEntry): string
	if entry.pendingAck == true then
		return "warning"
	end
	if entry.status == "accepted" then
		return "success"
	end
	if entry.status == "failed" then
		return "danger"
	end
	if entry.status == "pending" then
		return "secondary"
	end
	return "muted"
end

local function offerCard(
	entry: TradeEntry,
	phase: Phase,
	onRespond: (offerId: string, accept: boolean) -> (),
	onCancel: (offerId: string) -> (),
	position: UDim2
): any
	local offer = entry.offer
	local incoming = entry.direction == "in"
	local counterparty = if incoming then offer.from else offer.to
	local title = if incoming then "Incoming: " .. counterparty else "Outgoing: " .. counterparty
	local subtitle = if entry.pendingAck == true then "sending" else offer.id
	local giveLabel = if incoming then "They give: " else "You give: "
	local wantLabel = if incoming then "They want: " else "You want: "

	local body: { any } = {}
	table.insert(
		body,
		React.createElement(Text.render, {
			text = giveLabel .. describeBag(offer.give),
			tone = "secondary",
			size = "xs",
			truncate = true,
			position = UDim2.fromOffset(PAD, 8),
			size2 = UDim2.fromOffset(WIDTH - PAD * 2, 16),
		})
	)
	table.insert(
		body,
		React.createElement(Text.render, {
			text = wantLabel .. describeBag(offer.want),
			tone = "secondary",
			size = "xs",
			truncate = true,
			position = UDim2.fromOffset(PAD, 26),
			size2 = UDim2.fromOffset(WIDTH - PAD * 2, 16),
		})
	)
	table.insert(
		body,
		React.createElement(Text.render, {
			text = describePromises(offer.promises, offer.to),
			tone = "muted",
			size = "xs",
			truncate = true,
			position = UDim2.fromOffset(PAD, 44),
			size2 = UDim2.fromOffset(WIDTH - PAD * 2, 16),
		})
	)
	table.insert(
		body,
		React.createElement(Text.render, {
			text = statusLabel(entry),
			tone = statusTone(entry),
			size = "xs",
			truncate = true,
			position = UDim2.fromOffset(PAD, 62),
			size2 = UDim2.fromOffset(WIDTH - PAD * 2, 16),
		})
	)

	if entry.status == "pending" and phase == "Window" then
		if incoming then
			table.insert(
				body,
				React.createElement(Button.render, {
					text = "Accept",
					variant = "primary",
					size = "s",
					position = UDim2.fromOffset(PAD, 82),
					size2 = UDim2.fromOffset(82, 26),
					onClick = function()
						onRespond(offer.id, true)
					end,
				})
			)
			table.insert(
				body,
				React.createElement(Button.render, {
					text = "Decline",
					variant = "secondary",
					size = "s",
					position = UDim2.fromOffset(PAD + 90, 82),
					size2 = UDim2.fromOffset(82, 26),
					onClick = function()
						onRespond(offer.id, false)
					end,
				})
			)
		else
			table.insert(
				body,
				React.createElement(Button.render, {
					text = "Cancel",
					variant = "danger",
					size = "s",
					disabled = entry.pendingAck == true,
					position = UDim2.fromOffset(PAD, 82),
					size2 = UDim2.fromOffset(82, 26),
					onClick = function()
						onCancel(offer.id)
					end,
				})
			)
		end
	end

	return React.createElement(Card.render, {
		title = title,
		subtitle = subtitle,
		tone = string.lower(counterparty) :: any,
		size = UDim2.fromOffset(WIDTH, CARD_HEIGHT),
		position = position,
	}, React.createElement(React.Fragment, nil, body))
end

function DiplomacyTab.render(props: DiplomacyTabProps): any
	local theme = ThemeContext.useTheme()
	local view = props.view
	local children: { any } = {}

	local pending = 0
	for _, entry in props.offers do
		if entry.status == "pending" then
			pending += 1
		end
	end
	local liveText = if pending == 0 then "no live offers" else string.format("%d live", pending)

	table.insert(
		children,
		React.createElement(Text.render, {
			text = "Diplomacy",
			tone = "muted",
			size = "xs",
			uppercase = true,
			position = UDim2.fromOffset(PAD, 0),
			size2 = UDim2.fromOffset(120, HEADER),
		})
	)
	table.insert(
		children,
		React.createElement(Text.render, {
			text = liveText,
			tone = "muted",
			size = "xs",
			align = Enum.TextXAlignment.Right,
			position = UDim2.new(1, -PAD, 0, 0),
			anchorPoint = Vector2.new(1, 0),
			size2 = UDim2.fromOffset(120, HEADER),
		})
	)

	local body: { any } = {}
	local y = 0

	table.insert(
		body,
		React.createElement(Text.render, {
			text = "Incoming offers",
			tone = "muted",
			size = "xs",
			uppercase = true,
			position = UDim2.fromOffset(0, y),
			size2 = UDim2.fromOffset(WIDTH, SECTION),
		})
	)
	y += SECTION
	local incomingCount = 0
	for _, entry in props.offers do
		if entry.direction == "in" then
			incomingCount += 1
			table.insert(
				body,
				offerCard(
					entry,
					props.phase,
					props.onRespond,
					props.onCancel,
					UDim2.fromOffset(0, y)
				)
			)
			y += CARD_HEIGHT + 8
		end
	end
	if incomingCount == 0 then
		table.insert(
			body,
			React.createElement(Text.render, {
				text = "No incoming offers",
				tone = "muted",
				size = "xs",
				position = UDim2.fromOffset(0, y),
				size2 = UDim2.fromOffset(WIDTH, EMPTY),
			})
		)
		y += EMPTY
	end

	table.insert(
		body,
		React.createElement(Text.render, {
			text = "Outgoing offers",
			tone = "muted",
			size = "xs",
			uppercase = true,
			position = UDim2.fromOffset(0, y),
			size2 = UDim2.fromOffset(WIDTH, SECTION),
		})
	)
	y += SECTION
	local outgoingCount = 0
	for _, entry in props.offers do
		if entry.direction == "out" then
			outgoingCount += 1
			table.insert(
				body,
				offerCard(
					entry,
					props.phase,
					props.onRespond,
					props.onCancel,
					UDim2.fromOffset(0, y)
				)
			)
			y += CARD_HEIGHT + 8
		end
	end
	if outgoingCount == 0 then
		table.insert(
			body,
			React.createElement(Text.render, {
				text = "No outgoing offers",
				tone = "muted",
				size = "xs",
				position = UDim2.fromOffset(0, y),
				size2 = UDim2.fromOffset(WIDTH, EMPTY),
			})
		)
		y += EMPTY
	end

	table.insert(
		body,
		React.createElement(TradeComposer.render, {
			view = view,
			phase = props.phase,
			notices = props.notices,
			offers = props.offers,
			onPropose = props.onPropose,
			position = UDim2.fromOffset(0, y),
		})
	)
	y += TradeComposer.HEIGHT + 8

	table.insert(
		body,
		React.createElement(Text.render, {
			text = "Promise ledger",
			tone = "muted",
			size = "xs",
			uppercase = true,
			position = UDim2.fromOffset(0, y),
			size2 = UDim2.fromOffset(WIDTH, SECTION),
		})
	)
	y += SECTION

	if #view.promises == 0 then
		table.insert(
			body,
			React.createElement(Text.render, {
				text = "No promises yet. A promise travels with a trade offer.",
				tone = "muted",
				size = "xs",
				position = UDim2.fromOffset(0, y),
				size2 = UDim2.fromOffset(WIDTH, EMPTY),
			})
		)
		y += EMPTY
	else
		local promises = table.clone(view.promises)
		table.sort(promises, function(a, b)
			return a.id < b.id
		end)
		for _, promise in promises do
			local tone = if promise.status == "kept"
				then "success"
				elseif promise.status == "broken" then "danger"
				else "muted"
			table.insert(
				body,
				React.createElement(Text.render, {
					text = string.format(
						"%s to %s: %s",
						promise.from,
						promise.to,
						PromiseBuilder.describeSpec(promise.spec, promise.to)
					),
					tone = "secondary",
					size = "xs",
					truncate = true,
					position = UDim2.fromOffset(0, y),
					size2 = UDim2.fromOffset(WIDTH - 96, 16),
				})
			)
			table.insert(
				body,
				React.createElement(Text.render, {
					text = promise.status,
					tone = tone,
					size = "xs",
					align = Enum.TextXAlignment.Right,
					position = UDim2.fromOffset(WIDTH - 92, y),
					size2 = UDim2.fromOffset(92, 16),
				})
			)
			local audit = PromiseBuilder.auditText(promise.spec)
			if promise.spec.kind == "Deliver" then
				audit = string.format(
					"%s - delivered %d of %d",
					audit,
					promise.progress.delivered or 0,
					promise.spec.amount
				)
			end
			table.insert(
				body,
				React.createElement(Text.render, {
					text = audit,
					tone = "muted",
					size = "xs",
					truncate = true,
					position = UDim2.fromOffset(0, y + 18),
					size2 = UDim2.fromOffset(WIDTH, 16),
				})
			)
			y += LEDGER_ROW
		end
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

return DiplomacyTab
