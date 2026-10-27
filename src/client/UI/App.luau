--!strict
-- App: the shell of the match screen (UI_SPEC section 2) — the top bar, the
-- four corners, the city viewport in the middle and the action dock at the
-- bottom. The viewer's own class is always bottom-left (D-012); the other
-- three classes take the other corners in a fixed order relative to the
-- viewer: the next classes in the Working -> Middle -> Capitalist -> State
-- order, clockwise from top-left.
--
-- The App reads the store and nothing else. The panels of M7-T3 are built
-- here from the view and the draft; the tabs of M7-T4 plug into the dock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Game.Types)
local ThemeContext = require(script.Parent.Theme.ThemeContext)
local Surface = require(script.Parent.Primitives.Surface)
local Text = require(script.Parent.Primitives.Text)
local TopBar = require(script.Parent.Panels.TopBar)
local OwnClassPanel = require(script.Parent.Panels.OwnClassPanel)
local ClassCard = require(script.Parent.Panels.ClassCard)
local EconomyTab = require(script.Parent.Panels.EconomyTab)
local PoliticsTab = require(script.Parent.Panels.PoliticsTab)
local DiplomacyTab = require(script.Parent.Panels.DiplomacyTab)
local ChatDrawer = require(script.Parent.Panels.ChatDrawer)
local EveningReport = require(script.Parent.Panels.EveningReport)
local EndSummary = require(script.Parent.Panels.EndSummary)
local CityViewport = require(script.Parent.City.CityViewport)
local Store = require(script.Parent.Parent.State.Store)

export type AppProps = {
	store: Store.Store,
	-- the debounced draft sender (NETWORKING 4); nil in a bare render
	onDraft: ((Types.ActionDraft) -> ())?,
	-- the live bill proposal (NETWORKING 3.1); nil in a bare render
	onProposeBill: ((requestId: string, policyId: Types.PolicyId, level: number) -> ())?,
	-- the live trade intents (NETWORKING 3.1); nil in a bare render
	onProposeTrade: ((
		requestId: string,
		to: Types.ClassId,
		give: Types.ResourceBag,
		want: Types.ResourceBag,
		promises: { Types.PromiseSpec }
	) -> ())?,
	onRespondTrade: ((offerId: string, accept: boolean) -> ())?,
	onCancelTrade: ((offerId: string) -> ())?,
	-- the live alliance intents (NETWORKING 3.1); nil in a bare render
	onProposeAlliance: ((to: Types.ClassId) -> ())?,
	onRespondAlliance: ((from: Types.ClassId, accept: boolean) -> ())?,
	onBreakAlliance: (() -> ())?,
	-- the live chat intent (NETWORKING 3.1); nil in a bare render
	onSendChat: ((channel: Types.ChatChannel, text: string, classTo: Types.ClassId?) -> ())?,
	-- overrides for the four corners, in the order of the layout: [1] the
	-- viewer's own panel (bottom-left), [2] top-left, [3] top-right, [4]
	-- bottom-right. Absent slots are built from the view.
	corners: { any }?,
	dock: any?,
	center: any?,
}

local App = {}

-- The other three classes in their fixed order relative to the viewer.
local function otherClasses(viewer: Types.ClassId): { Types.ClassId }
	local ids = Types.CLASS_IDS
	local start = 1
	for index = 1, #ids do
		if (ids[index] :: any) == viewer then
			start = index
			break
		end
	end
	local result: { Types.ClassId } = {}
	for offset = 1, 3 do
		local index = ((start - 1 + offset) % #ids) + 1
		table.insert(result, ids[index] :: any)
	end
	return result
end

local function allianceOf(view: Types.PlayerView, classId: Types.ClassId): Types.Alliance?
	for _, alliance in view.alliances do
		for _, member in alliance.members do
			if member == classId then
				return alliance
			end
		end
	end
	return nil
end

local function allianceHas(alliance: Types.Alliance, classId: Types.ClassId): boolean
	for _, member in alliance.members do
		if member == classId then
			return true
		end
	end
	return false
end

function App.render(props: AppProps): any
	local theme = ThemeContext.useTheme()
	local store = props.store

	local state, setState = React.useState(store:state())
	React.useEffect(function()
		return store:subscribe(function(next)
			setState(next)
		end)
	end, {})

	local view = state.match.view
	local overrides = props.corners or {}

	local function selectTab(tab: string)
		store:set(Store.applyActiveTab(store:state(), tab))
	end

	local own = overrides[1]
	if own == nil and view ~= nil then
		own = React.createElement(OwnClassPanel.render, {
			view = view,
			draft = state.draft.current,
			activeTab = state.ui.activeTab,
			onTab = selectTab,
		})
	end
	own = own
		or React.createElement(
			Surface.render,
			{
				gradient = "surface.card",
				size = UDim2.fromScale(1, 1),
			},
			React.createElement(Text.render, {
				text = "Your class",
				tone = "muted",
				size = "s",
			})
		)

	local classes = if view ~= nil then otherClasses(view.viewer) else {}

	-- The alliance controls: the viewer may propose only while free and with
	-- no live proposal; a class already in an alliance is not a target.
	local ownAlliance = if view ~= nil then allianceOf(view, view.viewer) else nil
	local ownProposal = false
	if view ~= nil then
		for _, proposal in view.allianceProposals do
			if proposal.from == view.viewer or proposal.to == view.viewer then
				ownProposal = true
				break
			end
		end
	end

	local function card(index: number): any
		local override = overrides[index]
		if override ~= nil then
			return override
		end
		if view == nil then
			return nil
		end
		local classId = classes[index - 1]
		local alliance = allianceOf(view, classId)
		local canPropose = state.match.phase == "Window"
			and ownAlliance == nil
			and not ownProposal
			and alliance == nil
			and props.onProposeAlliance ~= nil
		return React.createElement(ClassCard.render, {
			classId = classId,
			view = view.others[classId],
			reputation = view.reputation[classId],
			alliance = alliance,
			alliedWithViewer = alliance ~= nil and allianceHas(alliance, view.viewer),
			onProposeAlliance = if canPropose
				then function()
					if props.onProposeAlliance ~= nil then
						props.onProposeAlliance(classId)
					end
				end
				else nil,
		})
	end

	local children: { any } = {}

	-- the top bar
	table.insert(
		children,
		React.createElement(TopBar.render, {
			day = state.match.day,
			rounds = if view ~= nil then view.rounds else nil,
			phase = state.match.phase,
			endsAt = state.match.endsAt,
			serverOffset = state.match.serverOffset,
			stability = state.match.view and state.match.view.stability or 0,
			policies = state.match.view and state.match.view.policies or {},
		})
	)

	-- the middle: the city viewport (M11) with the panels over it. The center
	-- override is for the dev gallery and bare renders; the match screen gets
	-- the city, which reads only the view.
	local center = props.center
	if center == nil then
		center = React.createElement(CityViewport.render, {
			view = view,
			reveal = state.reveal,
			phase = state.match.phase,
			matchEnded = state.match.result ~= nil,
		})
	end
	table.insert(
		children,
		React.createElement(Surface.render, {
			gradient = "table.background",
			position = UDim2.fromOffset(0, theme.layout.topBar + 1),
			size = UDim2.new(1, 0, 1, -(theme.layout.topBar + 1)),
			zIndex = 1,
		}, center)
	)

	-- the four corners: the viewer's own panel bottom-left, the other three
	-- classes top-left, top-right and bottom-right
	table.insert(
		children,
		React.createElement(Surface.render, {
			gradient = "surface.card",
			size = UDim2.fromOffset(theme.layout.cornerWidth, theme.layout.cornerHeight),
			position = UDim2.fromOffset(theme.spacing.l, theme.layout.topBar + theme.spacing.l),
			zIndex = 5,
		}, card(2))
	)
	table.insert(
		children,
		React.createElement(Surface.render, {
			gradient = "surface.card",
			size = UDim2.fromOffset(theme.layout.cornerWidth, theme.layout.cornerHeight),
			position = UDim2.new(
				1,
				-(theme.layout.cornerWidth + theme.spacing.l),
				0,
				theme.layout.topBar + theme.spacing.l
			),
			zIndex = 5,
		}, card(3))
	)
	table.insert(
		children,
		React.createElement(Surface.render, {
			gradient = "surface.card",
			size = UDim2.fromOffset(theme.layout.cornerWidth, theme.layout.cornerHeight),
			position = UDim2.new(
				1,
				-(theme.layout.cornerWidth + theme.spacing.l),
				1,
				-(theme.layout.cornerHeight + theme.spacing.l)
			),
			zIndex = 5,
		}, card(4))
	)
	table.insert(
		children,
		React.createElement(Surface.render, {
			gradient = "surface.card",
			size = UDim2.fromOffset(theme.layout.cornerWidth, theme.layout.cornerHeight),
			position = UDim2.new(
				0,
				theme.spacing.l,
				1,
				-(theme.layout.cornerHeight + theme.spacing.l)
			),
			zIndex = 5,
		}, own)
	)

	-- the action dock at the bottom: the active tab's panel. The controls edit
	-- the local draft through the pure store reducers; onDraft debounces the
	-- send. Economy, Politics and Diplomacy are live (M8).
	local dock = props.dock
	if dock == nil and view ~= nil then
		local function applyDraft(nextState: Store.StoreState)
			store:set(nextState)
			if props.onDraft ~= nil then
				props.onDraft(nextState.draft.current)
			end
		end

		if state.ui.activeTab == "economy" then
			dock = React.createElement(EconomyTab.render, {
				view = view,
				draft = state.draft.current,
				syncState = state.draft.syncState,
				onOpenSlots = function(lineId, count)
					applyDraft(Store.setOpenSlots(store:state(), lineId, count))
				end,
				onAssign = function(lineId, count)
					applyDraft(Store.setAssign(store:state(), lineId, count))
				end,
				onStrike = function(target)
					applyDraft(Store.setStrike(store:state(), target))
				end,
				onBuild = function(lineType)
					applyDraft(Store.setBuild(store:state(), lineType))
				end,
				onLobby = function(amount)
					applyDraft(Store.setLobby(store:state(), amount))
				end,
				onMarket = function(side, stockId, volume)
					applyDraft(Store.setMarket(store:state(), side, stockId, volume))
				end,
			})
		elseif state.ui.activeTab == "politics" then
			dock = React.createElement(PoliticsTab.render, {
				view = view,
				draft = state.draft.current,
				syncState = state.draft.syncState,
				phase = state.match.phase,
				endsAt = state.match.endsAt,
				serverOffset = state.match.serverOffset,
				notices = state.inbox.notices,
				onVote = function(billId, side, influence)
					applyDraft(Store.setVote(store:state(), billId, side, influence))
				end,
				onProposeBill = props.onProposeBill,
				onProposeAlliance = props.onProposeAlliance,
				onRespondAlliance = props.onRespondAlliance,
				onBreakAlliance = props.onBreakAlliance,
			})
		elseif state.ui.activeTab == "diplomacy" then
			local function proposeTrade(
				requestId: string,
				to: Types.ClassId,
				give: Types.ResourceBag,
				want: Types.ResourceBag,
				promises: { Types.PromiseSpec }
			)
				local current = store:state()
				local currentView = current.match.view
				if currentView == nil then
					return
				end
				-- The local outbox entry exists before the server answers; the
				-- ack gives it the real offer id (Store.applyTradeResult).
				local offer: Types.TradeOffer = {
					id = "pending-" .. requestId,
					from = currentView.viewer,
					to = to,
					give = give,
					want = want,
					promises = promises,
					expiresAt = current.match.endsAt,
				}
				store:set(Store.addOutgoingOffer(current, offer, requestId))
				if props.onProposeTrade ~= nil then
					props.onProposeTrade(requestId, to, give, want, promises)
				end
			end

			dock = React.createElement(DiplomacyTab.render, {
				view = view,
				phase = state.match.phase,
				offers = state.inbox.offers,
				notices = state.inbox.notices,
				onPropose = proposeTrade,
				onRespond = function(offerId, accept)
					if props.onRespondTrade ~= nil then
						props.onRespondTrade(offerId, accept)
					end
				end,
				onCancel = function(offerId)
					if props.onCancelTrade ~= nil then
						props.onCancelTrade(offerId)
					end
				end,
			})
		else
			dock = React.createElement(Text.render, {
				text = "Diplomacy: coming soon",
				tone = "muted",
				size = "xs",
				position = UDim2.fromOffset(theme.spacing.m, theme.spacing.m),
				size2 = UDim2.new(1, -theme.spacing.m * 2, 0, 24),
			})
		end
	end

	table.insert(
		children,
		React.createElement(Surface.render, {
			gradient = "surface.header",
			position = UDim2.new(0.5, 0, 1, -theme.spacing.l),
			size = UDim2.fromOffset(420, theme.layout.dock),
			anchorPoint = Vector2.new(0.5, 1),
			zIndex = 6,
		}, dock)
	)

	-- the chat drawer above the dock (UI_SPEC 2): collapsed by default, with
	-- the unread badges of the channels. The text is filtered server-side;
	-- the drawer only sends the intent.
	if view ~= nil then
		table.insert(
			children,
			React.createElement(ChatDrawer.render, {
				open = state.ui.drawerOpen,
				channels = state.chat.channels,
				unread = state.chat.unread,
				viewer = view.viewer,
				onToggle = function()
					local current = store:state()
					store:set(Store.applyDrawerOpen(current, not current.ui.drawerOpen))
				end,
				onSend = function(channel, text, classTo)
					if props.onSendChat ~= nil then
						props.onSendChat(channel, text, classTo)
					end
				end,
				onRead = function(channel)
					store:set(Store.applyChatRead(store:state(), channel))
				end,
			})
		)
	end

	-- The end screen wins over the report: a match that ends during the
	-- Closing Bell has no Reveal phase, and its final snapshot carries the
	-- final standings. The report is only open while the server says Reveal,
	-- so it disappears by itself when the next Market Hours begins.
	if view ~= nil and state.match.result ~= nil then
		table.insert(
			children,
			React.createElement(EndSummary.render, {
				result = state.match.result,
				view = view,
				summary = state.match.endSummary,
			})
		)
	elseif view ~= nil and state.match.phase == "Reveal" and state.reveal ~= nil then
		table.insert(
			children,
			React.createElement(EveningReport.render, {
				report = state.reveal,
				view = view,
			})
		)
	end

	return React.createElement(
		ThemeContext.provider,
		{
			value = theme,
		},
		React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
		}, children)
	)
end

return App
