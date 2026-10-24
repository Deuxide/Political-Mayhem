--!strict
-- Replication (NETWORKING section 3.2 and 4): what the server sends to the
-- clients. A client never gets the MatchState; it gets the PlayerView of
-- its own class, built by the PlayerViewBuilder, which hides what the info
-- mode hides (GAME_DESIGN 13).
--
-- A snapshot goes out when a player joins and on every phase change; the
-- live changes in between go out as patches. The server decides which class
-- a player is; the client never says so (NETWORKING 2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local PlayerViewBuilder =
	require(ReplicatedStorage.Shared.Game.Behaviors.InfoModes.PlayerViewBuilder)
local Support = require(script.Parent.Handlers.Support)

type ClassId = Types.ClassId
type LogEntry = Types.LogEntry
type PlayerView = Types.PlayerView
type SupportType = Support.Support

-- What one class gained or lost over a resolved Day (NETWORKING 3.2).
export type RevealDelta = {
	money: number,
	influence: number,
	stock: { [Types.StockId]: number },
	vp: number,
}
export type RevealDeltas = { [ClassId]: RevealDelta }

export type RevealReport = {
	day: number,
	events: { LogEntry },
	deltas: RevealDeltas,
}

local Replication = {}

-- The view of the player's own class, or nil when there is no match or the
-- player has no class yet.
function Replication.viewFor(support: SupportType, player: any): PlayerView?
	local seat = support.lobby:seatOf(player.UserId)
	if seat == nil or seat.classId == nil then
		return nil
	end
	local match = support.lobby:match()
	if match == nil then
		return nil
	end
	return PlayerViewBuilder.build(match:state(), match:ruleSet(), seat.classId :: any)
end

-- A full snapshot (NETWORKING 3.2): on join and on every phase change.
function Replication.snapshot(support: SupportType, player: any)
	local view = Replication.viewFor(support, player)
	if view == nil then
		return
	end
	support.remotes.View_Snapshot:FireClient(player, {
		protocol = Remotes.PROTOCOL_VERSION,
		view = view,
		serverTime = support.clock(),
	})
end

function Replication.snapshotAll(support: SupportType)
	for _, player in support.players() do
		Replication.snapshot(support, player)
	end
end

-- A patch for the members of a class.
function Replication.patch(
	support: SupportType,
	classId: ClassId,
	path: string,
	value: any,
	op: "set" | "remove" | "append"?
)
	for _, member in Support.membersOf(support, classId) do
		support.remotes.View_Patch:FireClient(member, {
			ops = { { op = op or "set", path = path, value = value } },
			serverTime = support.clock(),
		})
	end
end

-- A patch for everybody (public data, like the bills on the table).
function Replication.patchAll(
	support: SupportType,
	path: string,
	value: any,
	op: "set" | "remove" | "append"?
)
	for _, player in support.players() do
		support.remotes.View_Patch:FireClient(player, {
			ops = { { op = op or "set", path = path, value = value } },
			serverTime = support.clock(),
		})
	end
end

-- The report of a resolved Day. The events are public (the Evening Report
-- is the story of the Day), but the deltas carry Money, Influence and
-- stock, so only the viewer's own class travels (GAME_DESIGN 13).
function Replication.reveal(support: SupportType, player: any, report: RevealReport)
	local view = Replication.viewFor(support, player)
	if view == nil then
		return
	end
	local deltas: RevealDeltas = {}
	local own = report.deltas[view.viewer]
	if own ~= nil then
		deltas[view.viewer] = own
	end
	support.remotes.Reveal_Report:FireClient(player, {
		day = report.day,
		events = report.events,
		deltas = deltas,
	})
end

-- The end of the match (NETWORKING 3.2).
function Replication.ended(support: SupportType, result: Types.VictoryResult, summary: string)
	for _, player in support.players() do
		support.remotes.Match_Ended:FireClient(player, { result = result, summary = summary })
	end
end

return Replication
