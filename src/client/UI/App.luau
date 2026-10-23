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
local Store = require(script.Parent.Parent.State.Store)

export type AppProps = {
	store: Store.Store,
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
		return React.createElement(ClassCard.render, {
			classId = classId,
			view = view.others[classId],
			reputation = view.reputation[classId],
			alliance = alliance,
			alliedWithViewer = alliance ~= nil and allianceHas(alliance, view.viewer),
		})
	end

	local children: { any } = {}

	-- the top bar
	table.insert(
		children,
		React.createElement(TopBar.render, {
			day = state.match.day,
			rounds = 12,
			phase = state.match.phase,
			endsAt = state.match.endsAt,
			serverOffset = state.match.serverOffset,
			stability = state.match.view and state.match.view.stability or 0,
			policies = state.match.view and state.match.view.policies or {},
		})
	)

	-- the middle: the city viewport (M11) with the panels over it
	table.insert(
		children,
		React.createElement(Surface.render, {
			gradient = "table.background",
			position = UDim2.fromOffset(0, theme.layout.topBar + 1),
			size = UDim2.new(1, 0, 1, -(theme.layout.topBar + 1)),
			zIndex = 1,
		}, props.center)
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

	-- the action dock at the bottom
	table.insert(
		children,
		React.createElement(Surface.render, {
			gradient = "surface.header",
			position = UDim2.new(0.5, 0, 1, -(theme.layout.dock + theme.spacing.l)),
			size = UDim2.fromOffset(420, theme.layout.dock),
			anchorPoint = Vector2.new(0.5, 1),
			zIndex = 6,
		}, props.dock)
	)

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
