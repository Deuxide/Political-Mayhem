--!strict
-- EveningReport: the Reveal overlay (UI_SPEC sections 2, 4.2 and 5). It is
-- open only while the server says the phase is Reveal, so it closes by itself
-- when the next Market Hours begins; the player never dismisses it.
--
-- The own-class section lists every non-zero delta the server sent with its
-- one-line cause (the Day's log), then the whole public log. Other classes
-- show their public VP and reputation only: their Money, Influence and stock
-- never travel (GAME_DESIGN 13). The overlay is built from the store and
-- contains no game rule.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Reputation = require(ReplicatedStorage.Shared.Game.Ops.Reputation)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)
local Surface = require(script.Parent.Parent.Primitives.Surface)
local Text = require(script.Parent.Parent.Primitives.Text)
local Report = require(script.Parent.Parent.Parent.State.Report)

type ClassId = Types.ClassId
type PlayerView = Types.PlayerView
type RevealReport = Remotes.RevealReportPayload

export type EveningReportProps = {
	report: RevealReport,
	view: PlayerView,
}

local EveningReport = {}

local WIDTH = 680
local PAD = 16
local HEADER = 36
local STARS = 5

local function classKey(classId: ClassId): string
	return string.lower(classId)
end

local function stars(reputation: Types.Reputation?): string
	if reputation == nil then
		return "?"
	end
	local filled = math.clamp(math.floor(Reputation.stars(reputation) + 0.5), 0, STARS)
	return string.rep("★", filled) .. string.rep("☆", STARS - filled)
end

local function sectionHeading(text: string): any
	return React.createElement(Text.render, {
		text = text,
		tone = "muted",
		size = "xs",
		uppercase = true,
		size2 = UDim2.new(1, 0, 0, 18),
	})
end

function EveningReport.render(props: EveningReportProps): any
	local theme = ThemeContext.useTheme()
	local view = props.view
	local report = props.report
	local model = Report.build(report, view.viewer)

	local content: { any } = {
		React.createElement("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	-- The own class header: the class band carries the same accent as the
	-- corner panel, so the report reads as that class's page.
	table.insert(
		content,
		React.createElement(Surface.render, {
			gradient = "accent." .. classKey(view.viewer),
			size = UDim2.new(1, 0, 0, 28),
		}, {
			React.createElement(Text.render, {
				text = view.viewer,
				tone = "onAccent",
				size = "s",
				uppercase = true,
				position = UDim2.fromOffset(PAD, 0),
				size2 = UDim2.new(1, -PAD * 2, 1, 0),
			}),
			React.createElement(Text.render, {
				text = string.format("VP %d", view.own.vp),
				tone = "onAccent",
				size = "s",
				align = Enum.TextXAlignment.Right,
				position = UDim2.new(1, -PAD, 0, 0),
				anchorPoint = Vector2.new(1, 0),
				size2 = UDim2.fromOffset(100, 28),
			}),
		})
	)

	-- Every non-zero delta of the viewer's own class, with its cause.
	table.insert(content, sectionHeading("Your changes"))
	if #model.rows == 0 then
		table.insert(
			content,
			React.createElement(Text.render, {
				text = "No resource changes this Day.",
				tone = "muted",
				size = "xs",
				size2 = UDim2.new(1, 0, 0, 18),
			})
		)
	else
		for _, row in model.rows do
			table.insert(
				content,
				React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 34),
				}, {
					React.createElement(Text.render, {
						text = row.label,
						tone = "secondary",
						size = "s",
						position = UDim2.fromOffset(0, 0),
						size2 = UDim2.new(1, -120, 0, 16),
					}),
					React.createElement(Text.render, {
						text = string.format("%+d", row.amount),
						tone = if row.amount > 0 then "success" else "danger",
						size = "s",
						align = Enum.TextXAlignment.Right,
						position = UDim2.new(1, -100, 0, 0),
						size2 = UDim2.fromOffset(100, 16),
					}),
					React.createElement(Text.render, {
						text = row.cause,
						tone = "muted",
						size = "xs",
						position = UDim2.fromOffset(0, 16),
						size2 = UDim2.new(1, 0, 0, 16),
						truncate = true,
					}),
				})
			)
		end
	end

	-- The public story of the Day. A broken promise is danger, a VP gain is
	-- success; every line names its class when it has one.
	table.insert(content, sectionHeading("The Day's causes"))
	if #model.events == 0 then
		table.insert(
			content,
			React.createElement(Text.render, {
				text = "No events recorded.",
				tone = "muted",
				size = "xs",
				size2 = UDim2.new(1, 0, 0, 18),
			})
		)
	else
		for _, event in model.events do
			table.insert(
				content,
				React.createElement(Text.render, {
					text = "• " .. event.text,
					tone = event.tone,
					size = "xs",
					wrapped = true,
					automatic = true,
					size2 = UDim2.fromScale(1, 0),
				})
			)
		end
	end

	-- The other classes: VP and reputation are public in every info mode;
	-- their resource deltas are not in the viewer's report.
	table.insert(content, sectionHeading("Other classes"))
	for _, classId in Types.CLASS_IDS do
		local otherId: ClassId = classId :: any
		if otherId ~= view.viewer then
			local other = view.others[otherId]
			table.insert(
				content,
				React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 20),
				}, {
					React.createElement(Text.render, {
						text = otherId,
						tone = "secondary",
						size = "s",
						position = UDim2.fromOffset(0, 0),
						size2 = UDim2.new(1, -260, 0, 20),
					}),
					React.createElement(Text.render, {
						text = string.format("VP %d", if other ~= nil then other.vp else 0),
						tone = "primary",
						size = "s",
						position = UDim2.new(1, -250, 0, 0),
						size2 = UDim2.fromOffset(90, 20),
					}),
					React.createElement(Text.render, {
						text = stars(view.reputation[otherId]),
						tone = "secondary",
						size = "s",
						align = Enum.TextXAlignment.Right,
						position = UDim2.new(1, -140, 0, 0),
						size2 = UDim2.fromOffset(140, 20),
					}),
				})
			)
		end
	end

	table.insert(
		content,
		React.createElement(Text.render, {
			text = "This report closes when Market Hours begins.",
			tone = "muted",
			size = "xs",
			size2 = UDim2.new(1, 0, 0, 18),
		})
	)

	local body = React.createElement(
		"ScrollingFrame",
		{
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, HEADER),
			Size = UDim2.new(1, 0, 1, -HEADER),
			CanvasSize = UDim2.fromScale(1, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = theme.colors["line.strong"],
		},
		React.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(PAD, PAD),
			Size = UDim2.new(1, -PAD * 2, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, content)
	)

	local card = React.createElement(Surface.render, {
		gradient = "surface.card",
		position = UDim2.new(0.5, 0, 0, theme.layout.topBar + theme.spacing.l),
		anchorPoint = Vector2.new(0.5, 0),
		size = UDim2.new(
			0,
			WIDTH,
			1,
			-(theme.layout.topBar + theme.layout.dock + theme.spacing.l * 3)
		),
		zIndex = 8,
	}, {
		React.createElement(Surface.render, {
			gradient = "surface.header",
			size = UDim2.new(1, 0, 0, HEADER),
		}, {
			React.createElement(Text.render, {
				text = string.format("Day %d Evening Report", report.day),
				tone = "primary",
				size = "m",
				uppercase = true,
				position = UDim2.fromOffset(PAD, 0),
				size2 = UDim2.new(1, -PAD * 2, 1, 0),
			}),
		}),
		body,
	})

	-- No full-screen scrim: the report floats over the city and leaves the
	-- top bar and the own panel visible (UI_SPEC section 2).
	return card
end

return EveningReport
