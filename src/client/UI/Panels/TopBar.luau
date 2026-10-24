--!strict
-- TopBar: the Day, the themed phase with the clock, the Stability meter and
-- the policy ticker (UI_SPEC section 4.2). The phase shows its player-facing
-- name (GAME_DESIGN 3.1) — never "Window" or "turn".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)
local Surface = require(script.Parent.Parent.Primitives.Surface)
local Text = require(script.Parent.Parent.Primitives.Text)
local Divider = require(script.Parent.Parent.Primitives.Divider)
local SegmentedTrack = require(script.Parent.Parent.Composites.SegmentedTrack)
local Countdown = require(script.Parent.Parent.Composites.Countdown)

export type TopBarProps = {
	day: number,
	rounds: number?, -- nil until the first view; the top bar then shows the Day alone
	phase: string,
	endsAt: number,
	serverOffset: number,
	stability: number,
	policies: { [string]: number },
}

local TopBar = {}

-- The player-facing names of the phases (GAME_DESIGN 3.1).
local PHASE_NAMES: { [string]: string } = {
	Window = "Market Hours",
	Resolve = "Closing Bell",
	Reveal = "Evening Report",
}

function TopBar.render(props: TopBarProps): any
	local theme = ThemeContext.useTheme()

	-- The top row: Day, phase and clock, left to right. The Stability block
	-- sits at the top-right; the ticker runs along the bottom of the bar.
	local topRow: { any } = {
		React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, theme.spacing.s),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		React.createElement(Text.render, {
			text = if props.rounds ~= nil
				then string.format("Day %d of %d", props.day, props.rounds)
				else string.format("Day %d", props.day),
			tone = "primary",
			size = "m",
			size2 = UDim2.fromOffset(140, 24),
			layoutOrder = 1,
		}),
		React.createElement(Text.render, {
			text = PHASE_NAMES[props.phase] or props.phase,
			tone = "secondary",
			size = "s",
			uppercase = true,
			size2 = UDim2.fromOffset(150, 24),
			layoutOrder = 2,
		}),
		React.createElement(Countdown.render, {
			endsAt = props.endsAt,
			serverOffset = props.serverOffset,
			layoutOrder = 3,
		}),
	}

	local stability: { any } = {
		React.createElement("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, theme.spacing.xs),
		}),
		React.createElement(Text.render, {
			text = "Stability",
			tone = "muted",
			size = "xs",
			uppercase = true,
			size2 = UDim2.fromOffset(90, 16),
			layoutOrder = 1,
		}),
		React.createElement(SegmentedTrack.render, {
			value = props.stability,
			max = 100,
			segments = 10,
			size = "m",
			layoutOrder = 2,
		}),
	}

	-- the policy ticker: the level of every track that is on
	local ticker: { any } = {
		React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, theme.spacing.m),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	local tickerOrder = 0
	for _, name in
		{
			"Wage",
			"TaxWorking",
			"TaxMiddle",
			"TaxCapitalist",
			"PublicServices",
			"Tariff",
			"StrikeRights",
		}
	do
		local level = props.policies[name]
		if level ~= nil and level > 0 then
			tickerOrder += 1
			table.insert(
				ticker,
				React.createElement(Text.render, {
					text = string.format("%s %d", name, level),
					tone = "muted",
					size = "xs",
					size2 = UDim2.fromOffset(120, 16),
					layoutOrder = tickerOrder,
				})
			)
		end
	end

	local children: { any } = {}
	table.insert(
		children,
		React.createElement(
			Surface.render,
			{
				gradient = "surface.header",
				size = UDim2.new(1, 0, 0, theme.layout.topBar),
			},
			React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -theme.spacing.l * 2, 1, 0),
				Position = UDim2.fromOffset(theme.spacing.l, 0),
			}, {
				React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 24),
				}, topRow),
				React.createElement("Frame", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(200, 32),
				}, stability),
				React.createElement("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 40),
					Size = UDim2.new(1, 0, 0, 16),
				}, ticker),
			})
		)
	)

	table.insert(
		children,
		React.createElement(Divider.render, {
			size = UDim2.new(1, 0, 0, 1),
		})
	)

	return React.createElement(Surface.render, {
		size = UDim2.new(1, 0, 0, theme.layout.topBar + 1),
		zIndex = 10,
	}, children)
end

return TopBar
