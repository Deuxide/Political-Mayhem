--!strict
-- App: the shell of the match screen (UI_SPEC section 2) — the top bar, the
-- four corners, the city viewport in the middle and the action dock at the
-- bottom. The viewer's own class is always bottom-left (D-012); the other
-- three classes take the other corners in a fixed order.
--
-- The App reads the store and nothing else: the panels (M7-T3) and the tabs
-- (M7-T4) plug into the slots it provides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local ThemeContext = require(script.Parent.Theme.ThemeContext)
local Surface = require(script.Parent.Primitives.Surface)
local Text = require(script.Parent.Primitives.Text)
local TopBar = require(script.Parent.Panels.TopBar)
local Store = require(script.Parent.Parent.State.Store)

export type AppProps = {
	store: Store.Store,
	-- the panels of the four corners, in the order of the layout: top-left,
	-- top-right, bottom-right, and the viewer's own panel (bottom-left)
	corners: { any }?,
	dock: any?,
	center: any?,
}

local App = {}

function App.render(props: AppProps): any
	local theme = ThemeContext.useTheme()
	local store = props.store

	local state, setState = React.useState(store:state())
	React.useEffect(function()
		return store:subscribe(function(next)
			setState(next)
		end)
	end, {})

	local corners = props.corners or {}
	local own = corners[1]
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

	-- the four corners
	table.insert(
		children,
		React.createElement(Surface.render, {
			size = UDim2.fromOffset(theme.layout.cornerWidth, theme.layout.cornerHeight),
			position = UDim2.fromOffset(theme.spacing.l, theme.layout.topBar + theme.spacing.l),
			zIndex = 5,
		}, corners[2])
	)
	table.insert(
		children,
		React.createElement(Surface.render, {
			size = UDim2.fromOffset(theme.layout.cornerWidth, theme.layout.cornerHeight),
			position = UDim2.new(
				1,
				-(theme.layout.cornerWidth + theme.spacing.l),
				0,
				theme.layout.topBar + theme.spacing.l
			),
			zIndex = 5,
		}, corners[3])
	)
	table.insert(
		children,
		React.createElement(Surface.render, {
			size = UDim2.fromOffset(theme.layout.cornerWidth, theme.layout.cornerHeight),
			position = UDim2.new(
				1,
				-(theme.layout.cornerWidth + theme.spacing.l),
				1,
				-(theme.layout.cornerHeight + theme.spacing.l)
			),
			zIndex = 5,
		}, corners[4])
	)
	table.insert(
		children,
		React.createElement(Surface.render, {
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
