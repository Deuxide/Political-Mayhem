--!strict
-- Report: the pure model behind the EveningReport overlay (UI_SPEC 4.2).
-- It turns the server's filtered RevealReport into the rows the player reads:
-- one row per non-zero delta of the viewer's own class, each with a one-line
-- cause, plus the Day's public log lines.
--
-- The exact cause is the first log line about that resource and the viewer
-- (the log is the story of the Day). Upkeep consumes stock without a
-- per-class line, and a transfer may move a resource without naming it, so a
-- row with no matching line falls back to the rule that owns that number
-- (D-081). The overlay itself does no game rule and reads no Roblox service.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local StockMap = require(ReplicatedStorage.Shared.Game.StockMap)
local ConfigResources = require(ReplicatedStorage.Shared.Config.Resources)

type ClassId = Types.ClassId
type ResourceId = Types.ResourceId
type RevealReport = Remotes.RevealReportPayload
type LogEntry = Types.LogEntry

export type ReportTone = "primary" | "secondary" | "muted" | "success" | "warning" | "danger"

export type DeltaRow = {
	key: string, -- "Money" | "Influence" | a stock ResourceId | "VP"
	label: string,
	amount: number,
	cause: string,
}

export type ReportEvent = {
	text: string,
	tone: ReportTone,
	actor: ClassId?,
}

export type ReportModel = {
	rows: { DeltaRow },
	events: { ReportEvent },
}

local Report = {}

local function resourceLabel(resourceId: ResourceId): string
	return (ConfigResources :: any)[resourceId].name
end

local function contains(text: string, needle: string): boolean
	return string.find(text, needle, 1, true) ~= nil
end

-- The first log line about this resource that belongs to the viewer (or to
-- everybody, when the line has no actor), or nil when the Day did not log it.
local function exactCause(events: { LogEntry }, viewer: ClassId, label: string): string?
	for _, entry in events do
		local aboutViewer = entry.actor == viewer
			or entry.actor == nil
			or contains(entry.text, viewer)
		if aboutViewer and contains(entry.text, label) then
			return entry.text
		end
	end
	return nil
end

-- A cause for a delta the log does not name. It names the rule that moves
-- that resource, never a guessed number.
local function fallbackCause(label: string, amount: number): string
	if label == "Money" then
		return if amount > 0
			then "income, sales and transfers"
			else "builds, purchases, taxes and transfers"
	elseif label == "Influence" then
		return if amount > 0 then "daily income and lobbying" else "votes and the outlawed strike"
	elseif label == "VP" then
		return "the Day's scoring criteria"
	end
	return if amount > 0 then "production and purchases" else "upkeep, sales and transfers"
end

local function row(
	events: { LogEntry },
	viewer: ClassId,
	key: string,
	label: string,
	amount: number
): DeltaRow?
	if amount == 0 then
		return nil
	end
	local cause = exactCause(events, viewer, label)
	return {
		key = key,
		label = label,
		amount = amount,
		cause = cause or fallbackCause(label, amount),
	}
end

local function eventTone(entry: LogEntry, viewer: ClassId): ReportTone
	if contains(entry.text, "broke") then
		return "danger"
	end
	if contains(entry.text, "gained") and contains(entry.text, "VP") then
		return "success"
	end
	if entry.actor == viewer then
		return "primary"
	end
	if entry.actor == nil then
		return "muted"
	end
	return "secondary"
end

-- Build the viewer's report. The server has already removed every other
-- class's delta; `rows` therefore only ever carries the viewer's numbers.
function Report.build(report: RevealReport, viewer: ClassId): ReportModel
	local delta = report.deltas[viewer]
	local rows: { DeltaRow } = {}

	if delta ~= nil then
		local money = row(report.events, viewer, "Money", "Money", delta.money)
		if money ~= nil then
			table.insert(rows, money)
		end
		local influence = row(report.events, viewer, "Influence", "Influence", delta.influence)
		if influence ~= nil then
			table.insert(rows, influence)
		end
		for index = 1, #Types.STOCK_IDS do
			local stockId: Types.StockId = Types.STOCK_IDS[index] :: any
			local resourceId: ResourceId = StockMap[stockId]
			local label = resourceLabel(resourceId)
			local stockRow =
				row(report.events, viewer, resourceId, label, delta.stock[stockId] or 0)
			if stockRow ~= nil then
				table.insert(rows, stockRow)
			end
		end
		local vp = row(report.events, viewer, "VP", "VP", delta.vp)
		if vp ~= nil then
			table.insert(rows, vp)
		end
	end

	local events: { ReportEvent } = {}
	for _, entry in report.events do
		table.insert(events, {
			text = entry.text,
			tone = eventTone(entry, viewer),
			actor = entry.actor,
		})
	end

	return {
		rows = rows,
		events = events,
	}
end

return Report
