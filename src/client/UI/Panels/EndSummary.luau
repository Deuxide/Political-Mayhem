--!strict
-- EndSummary: the end screen (UI_SPEC 3 and 4.2). It shows the result from
-- Match_Ended and, when the final snapshot has arrived, the final VP and
-- reputation table. The final snapshot is sent by the server before
-- Match_Ended, so the table is the state after the last resolution, not the
-- stale Resolve view.
--
-- The screen is deliberately final: there is no close button and no local
-- state to hide it. It covers the HUD because the match is over.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Reputation = require(ReplicatedStorage.Shared.Game.Ops.Reputation)
local Surface = require(script.Parent.Parent.Primitives.Surface)
local Text = require(script.Parent.Parent.Primitives.Text)
local Divider = require(script.Parent.Parent.Primitives.Divider)

type ClassId = Types.ClassId
type PlayerView = Types.PlayerView
type VictoryResult = Types.VictoryResult

export type EndSummaryProps = {
	result: VictoryResult,
	view: PlayerView?,
	summary: string?,
}

local EndSummary = {}

local WIDTH = 620
local HEIGHT = 420
local PAD = 20
local HEADER = 40
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

local function title(result: VictoryResult): string
	if result.kind == "collapse" then
		return "The world collapsed"
	end
	if #result.winners == 0 then
		return "No winner"
	end
	if #result.winners == 1 then
		if result.kind == "final" then
			return result.winners[1] .. " wins the final count"
		end
		return result.winners[1] .. " wins"
	end
	return table.concat(result.winners, " and ") .. " win together"
end

local function gradient(result: VictoryResult): string
	if result.kind == "collapse" then
		return "meter.danger"
	end
	if #result.winners == 1 then
		return "accent." .. classKey(result.winners[1])
	end
	return "highlight.strip"
end

-- The final standings, highest VP first; ties follow CLASS_IDS so the screen
-- never depends on table iteration order.
local function standings(view: PlayerView?): {
	{
		classId: ClassId,
		vp: number,
		reputation: Types.Reputation?,
		order: number,
	}
}
	local rows = {}
	if view == nil then
		return rows
	end
	for index, classId in Types.CLASS_IDS do
		local id: ClassId = classId :: any
		local vp = if id == view.viewer
			then view.own.vp
			else (view.others[id] and view.others[id].vp or 0)
		table.insert(rows, {
			classId = id,
			vp = vp,
			reputation = view.reputation[id],
			order = index,
		})
	end
	table.sort(rows, function(a, b)
		if a.vp ~= b.vp then
			return a.vp > b.vp
		end
		return a.order < b.order
	end)
	return rows
end

function EndSummary.render(props: EndSummaryProps): any
	local result = props.result
	local rows = standings(props.view)

	local body: { any } = {
		React.createElement(Text.render, {
			text = title(result),
			tone = "primary",
			size = "xl",
			wrapped = true,
			size2 = UDim2.new(1, 0, 0, 48),
		}),
		React.createElement(Text.render, {
			text = string.format("Day %d of the match", result.day),
			tone = "secondary",
			size = "s",
			position = UDim2.fromOffset(0, 52),
			size2 = UDim2.new(1, 0, 0, 20),
		}),
	}

	if props.summary ~= nil and props.summary ~= "" then
		table.insert(
			body,
			React.createElement(Text.render, {
				text = props.summary,
				tone = "muted",
				size = "xs",
				position = UDim2.fromOffset(0, 78),
				size2 = UDim2.new(1, 0, 0, 20),
			})
		)
	end

	table.insert(
		body,
		React.createElement(Divider.render, {
			position = UDim2.fromOffset(0, 110),
			size = UDim2.new(1, 0, 0, 1),
		})
	)
	table.insert(
		body,
		React.createElement(Text.render, {
			text = "Final standings",
			tone = "muted",
			size = "xs",
			uppercase = true,
			position = UDim2.fromOffset(0, 124),
			size2 = UDim2.new(1, 0, 0, 18),
		})
	)

	if #rows == 0 then
		table.insert(
			body,
			React.createElement(Text.render, {
				text = "Final standings are unavailable.",
				tone = "muted",
				size = "s",
				position = UDim2.fromOffset(0, 150),
				size2 = UDim2.new(1, 0, 0, 20),
			})
		)
	else
		for index, row in rows do
			local y = 150 + (index - 1) * 40
			local reputation = row.reputation
			local tally = if reputation ~= nil
				then string.format("%d kept / %d broken", reputation.kept, reputation.broken)
				else "no promises"
			table.insert(
				body,
				React.createElement("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, y),
					Size = UDim2.new(1, 0, 0, 34),
				}, {
					React.createElement(Text.render, {
						text = row.classId,
						tone = "secondary",
						size = "s",
						position = UDim2.fromOffset(0, 0),
						size2 = UDim2.new(1, -300, 0, 18),
					}),
					React.createElement(Text.render, {
						text = string.format("VP %d", row.vp),
						tone = "primary",
						size = "s",
						position = UDim2.new(1, -290, 0, 0),
						size2 = UDim2.fromOffset(80, 18),
					}),
					React.createElement(Text.render, {
						text = stars(reputation),
						tone = "secondary",
						size = "s",
						position = UDim2.new(1, -200, 0, 0),
						size2 = UDim2.fromOffset(200, 18),
					}),
					React.createElement(Text.render, {
						text = tally,
						tone = "muted",
						size = "xs",
						position = UDim2.fromOffset(0, 18),
						size2 = UDim2.new(1, 0, 0, 16),
					}),
				})
			)
		end
	end

	local card = React.createElement(Surface.render, {
		gradient = "surface.card",
		size = UDim2.fromOffset(WIDTH, HEIGHT),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		zIndex = 61,
	}, {
		React.createElement(Surface.render, {
			gradient = gradient(result),
			size = UDim2.new(1, 0, 0, HEADER),
		}, {
			React.createElement(Text.render, {
				text = "Match over",
				tone = "onAccent",
				size = "m",
				uppercase = true,
				position = UDim2.fromOffset(PAD, 0),
				size2 = UDim2.new(1, -PAD * 2, 1, 0),
			}),
			React.createElement(Text.render, {
				text = string.upper(result.kind),
				tone = "onAccent",
				size = "s",
				align = Enum.TextXAlignment.Right,
				position = UDim2.new(1, -PAD, 0, 0),
				anchorPoint = Vector2.new(1, 0),
				size2 = UDim2.fromOffset(120, HEADER),
			}),
		}),
		React.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(PAD, HEADER + 16),
			Size = UDim2.new(1, -PAD * 2, 1, -(HEADER + 16)),
		}, body),
	})

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 60,
	}, {
		React.createElement(Surface.render, {
			gradient = "overlay.scrim",
			size = UDim2.fromScale(1, 1),
			zIndex = 60,
		}),
		card,
	})
end

return EndSummary
