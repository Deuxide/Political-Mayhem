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

	local left: { any } = {}
	table.insert(
		left,
		React.createElement(Text.render, {
			text = if props.rounds ~= nil
				then string.format("Day %d of %d", props.day, props.rounds)
				else string.format("Day %d", props.day),
			tone = "primary",
			size = "m",
			size2 = UDim2.fromOffset(140, 24),
		})
	)

	local middle: { any } = {}
	table.insert(
		middle,
		React.createElement(Text.render, {
			text = PHASE_NAMES[props.phase] or props.phase,
			tone = "secondary",
			size = "s",
			uppercase = true,
			size2 = UDim2.fromOffset(150, 24),
		})
	)
	table.insert(
		middle,
		React.createElement(Countdown.render, {
			endsAt = props.endsAt,
			serverOffset = props.serverOffset,
		})
	)

	local right: { any } = {}
	table.insert(
		right,
		React.createElement(Text.render, {
			text = "Stability",
			tone = "muted",
			size = "xs",
			uppercase = true,
			size2 = UDim2.fromOffset(90, 16),
		})
	)
	table.insert(
		right,
		React.createElement(SegmentedTrack.render, {
			value = props.stability,
			max = 100,
			segments = 10,
			size = "m",
		})
	)

	-- the policy ticker: the level of every track that is on
	local ticker: { any } = {}
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
			table.insert(
				ticker,
				React.createElement(Text.render, {
					text = string.format("%s %d", name, level),
					tone = "muted",
					size = "xs",
					size2 = UDim2.fromOffset(120, 16),
				})
			)
		end
	end

	-- one list of children: a raw table must never sit next to another child
	local header: { any } = {}
	for _, list in { left, middle, right, ticker } do
		for _, element in list do
			table.insert(header, element)
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
			}, header)
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
