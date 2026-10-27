--!strict
-- RevealEvents: the presentation adapter between the server's Evening Report
-- log and the city animator. It classifies the four visual event kinds the
-- roadmap names (production, strike, protest, new build) from the public log
-- text; it never decides a game rule or changes state.
--
-- The log is the contract the server already sends (LogEntry). Keeping the
-- mapping here means the City code consumes typed visual events and does not
-- parse prose. A structured log kind would be the next step if the wording
-- ever needs to change; the tests pin the current formats.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

type ClassId = Types.ClassId
type LogEntry = Types.LogEntry
type RevealReport = Remotes.RevealReportPayload

export type CityEventKind = "Production" | "Strike" | "Protest" | "NewBuild"

export type CityEvent = {
	kind: CityEventKind,
	actor: ClassId?,
	target: ClassId?, -- the class a strike idles
	lineId: string?,
	day: number,
	text: string,
}

local RevealEvents = {}

local function classOf(name: string): ClassId?
	for index = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[index] :: any
		if classId == name then
			return classId
		end
	end
	return nil
end

local function event(
	kind: CityEventKind,
	entry: LogEntry,
	actorName: string?,
	targetName: string?,
	lineId: string?
): CityEvent?
	local actor: ClassId? = if actorName ~= nil then classOf(actorName) else nil
	local target: ClassId? = if targetName ~= nil then classOf(targetName) else nil
	if (actorName ~= nil and actor == nil) or (targetName ~= nil and target == nil) then
		return nil
	end
	return {
		kind = kind,
		actor = actor,
		target = target,
		lineId = lineId,
		day = entry.day,
		text = entry.text,
	}
end

-- The four log shapes the game writes today (BuildStep, ProductionStep,
-- UpkeepStep). Order matters only in that every line is inspected once.
function RevealEvents.build(report: RevealReport?): { CityEvent }
	local events: { CityEvent } = {}
	if report == nil then
		return events
	end

	for _, entry in report.events do
		local builtBy, builtLine = string.match(entry.text, "^(%a+) built ([%w%-]+) for %d+ Money$")
		if builtBy ~= nil and builtLine ~= nil then
			local item = event("NewBuild", entry, builtBy, nil, builtLine)
			if item ~= nil then
				table.insert(events, item)
			end
			continue
		end

		local producedBy, producedLine = string.match(entry.text, "^(%a+) ([%w%-]+) produced ")
		if producedBy ~= nil and producedLine ~= nil then
			local item = event("Production", entry, producedBy, nil, producedLine)
			if item ~= nil then
				table.insert(events, item)
			end
			continue
		end

		local strikeTarget = string.match(entry.text, "^Working's strike idles (%a+):")
		if strikeTarget ~= nil then
			local item = event("Strike", entry, "Working", strikeTarget, nil)
			if item ~= nil then
				table.insert(events, item)
			end
			continue
		end

		local protestBy = string.match(entry.text, "^(%a+) could not cover ")
		if protestBy ~= nil then
			local item = event("Protest", entry, protestBy, nil, nil)
			if item ~= nil then
				table.insert(events, item)
			end
		end
	end

	return events
end

return RevealEvents
