--!strict
-- Remote definitions (NETWORKING section 3): the name of every RemoteEvent
-- and the payload it carries. This module is data only — the server creates
-- the instances (server/Net/RemoteFactory.luau) and the client waits for
-- them, so a client can never create or fire a server-only remote
-- (NETWORKING 8).
--
-- `src/shared/Net/Remotes.luau` is the code form of NETWORKING.md; the two
-- must match. Adding a remote means adding it to both.

local Types = require(script.Parent.Parent.Game.Types)

export type ActionDraft = Types.ActionDraft
export type ChatChannel = Types.ChatChannel
export type ClassId = Types.ClassId
export type Difficulty = Types.Difficulty
export type LogEntry = Types.LogEntry
export type Phase = Types.Phase
export type PlayerView = Types.PlayerView
export type PolicyId = Types.PolicyId
export type PromiseSpec = Types.PromiseSpec
export type ResourceBag = Types.ResourceBag
export type Role = Types.Role
export type StockId = Types.StockId
export type TradeOffer = Types.TradeOffer
export type VictoryResult = Types.VictoryResult

-- Bumped whenever a payload shape changes; a client that sends a different
-- protocol version is answered with Notice { code = "VersionMismatch" }
-- (NETWORKING 1.6).
local PROTOCOL_VERSION = 1

-- ===== Client to server (intents only, NETWORKING 1.1) =====

export type SetClassPayload = { class: ClassId }
export type SetReadyPayload = { ready: boolean }
export type ConfigurePayload = { difficulty: Difficulty }
export type StartPayload = {}
export type DraftUpdatePayload = { seq: number, draft: ActionDraft }
export type DraftLockInPayload = { locked: boolean }
export type TradeProposePayload = {
	requestId: string,
	to: ClassId,
	give: ResourceBag,
	want: ResourceBag,
	promises: { PromiseSpec },
}
export type TradeRespondPayload = { offerId: string, accept: boolean }
export type TradeCancelPayload = { offerId: string }
export type AllianceProposePayload = { to: ClassId }
export type AllianceRespondPayload = { from: ClassId, accept: boolean }
export type AllianceBreakPayload = {}
export type BillProposePayload = { requestId: string, policyId: PolicyId, level: number }
export type ChatSendPayload = { channel: ChatChannel, classTo: ClassId?, text: string }
export type TeamSetRolePayload = { player: number, role: Role } -- player = UserId

-- ===== Server to client (filtered views, NETWORKING 1.4) =====

-- One change inside a view: set, remove, or append at a path.
export type PatchOp = { op: "set" | "remove" | "append", path: string, value: any }

export type ViewSnapshotPayload = { protocol: number, view: PlayerView, serverTime: number }
export type ViewPatchPayload = { ops: { PatchOp }, serverTime: number }
export type PhaseChangedPayload = { phase: Phase, day: number, endsAt: number }

-- What one class gained or lost over the resolved Day. The server filters
-- these per viewer like any other view field (GAME_DESIGN 13).
export type RevealDelta = {
	money: number,
	influence: number,
	stock: { [StockId]: number },
	vp: number,
}
export type RevealDeltas = { [ClassId]: RevealDelta }
export type RevealReportPayload = { day: number, events: { LogEntry }, deltas: RevealDeltas }

export type TradeIncomingPayload = { offer: TradeOffer }
export type TradeResultPayload = {
	requestId: string?,
	offerId: string,
	status: "accepted" | "declined" | "failed" | "expired",
	reason: string?,
}
export type ChatMessagePayload = {
	channel: ChatChannel,
	fromClass: ClassId,
	fromName: string,
	text: string,
	t: number,
}
export type NoticePayload = { code: string, message: string, requestId: string? }
export type MatchEndedPayload = { result: VictoryResult, summary: string }

-- ===== The names =====

local CLIENT_TO_SERVER = table.freeze({
	"Lobby_SetClass",
	"Lobby_SetReady",
	"Lobby_Configure",
	"Lobby_Start",
	"Draft_Update",
	"Draft_LockIn",
	"Trade_Propose",
	"Trade_Respond",
	"Trade_Cancel",
	"Alliance_Propose",
	"Alliance_Respond",
	"Alliance_Break",
	"Bill_Propose",
	"Chat_Send",
	"Team_SetRole",
})

local SERVER_TO_CLIENT = table.freeze({
	"View_Snapshot",
	"View_Patch",
	"Phase_Changed",
	"Reveal_Report",
	"Trade_Incoming",
	"Trade_Result",
	"Chat_Message",
	"Notice",
	"Match_Ended",
})

local ALL = table.freeze({
	"Lobby_SetClass",
	"Lobby_SetReady",
	"Lobby_Configure",
	"Lobby_Start",
	"Draft_Update",
	"Draft_LockIn",
	"Trade_Propose",
	"Trade_Respond",
	"Trade_Cancel",
	"Alliance_Propose",
	"Alliance_Respond",
	"Alliance_Break",
	"Bill_Propose",
	"Chat_Send",
	"Team_SetRole",
	"View_Snapshot",
	"View_Patch",
	"Phase_Changed",
	"Reveal_Report",
	"Trade_Incoming",
	"Trade_Result",
	"Chat_Message",
	"Notice",
	"Match_Ended",
})

return table.freeze({
	PROTOCOL_VERSION = PROTOCOL_VERSION,
	CLIENT_TO_SERVER = CLIENT_TO_SERVER,
	SERVER_TO_CLIENT = SERVER_TO_CLIENT,
	ALL = ALL,
})
