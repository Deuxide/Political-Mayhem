--!strict
-- RemoteEvent definitions and typed payloads. Single source of truth for networking.

local Types = require(script.Parent.Parent.Game.Types)

export type Remotes = {
	-- Client -> Server (intents)
	SubmitActions: {
		payload: Types.ActionDraft,
	},
	ProposeTrade: {
		payload: Types.TradeOffer,
	},
	RespondToTrade: {
		payload: { offerId: string, accept: boolean },
	},
	CastPolicyVote: {
		payload: { billId: string, inFavor: boolean, influenceSpent: number },
	},
	ProposeBill: {
		payload: Types.Bill,
	},
	ProposeAlliance: {
		payload: { target: Types.ClassId },
	},
	BreakAlliance: {
		payload: { target: Types.ClassId },
	},
	ProposePromise: {
		payload: Types.Promise,
	},
	SendChat: {
		payload: { channel: string, message: string },
	},
	ReadyUp: {
		payload: { ready: boolean },
	},
	ChooseClass: {
		payload: { classId: Types.ClassId },
	},

	-- Server -> Client (views & notifications)
	MatchStateSnapshot: {
		payload: Types.PlayerView,
	},
	MatchStatePatch: {
		payload: { path: string, value: any },
	},
	PhaseChanged: {
		payload: { phase: Types.Phase, round: number, timeRemaining: number },
	},
	TradeOfferReceived: {
		payload: Types.TradeOffer,
	},
	TradeOfferUpdated: {
		payload: Types.TradeOffer,
	},
	PolicyVoteUpdate: {
		payload: { billId: string, votes: { [Types.ClassId]: Types.VoteRecord } },
	},
	BillProposed: {
		payload: Types.Bill,
	},
	BillResult: {
		payload: { billId: string, passed: boolean },
	},
	AllianceProposed: {
		payload: { from: Types.ClassId, to: Types.ClassId },
	},
	AllianceFormed: {
		payload: { a: Types.ClassId, b: Types.ClassId },
	},
	AllianceBroken: {
		payload: { a: Types.ClassId, b: Types.ClassId },
	},
	PromiseProposed: {
		payload: Types.Promise,
	},
	PromiseResolved: {
		payload: { promiseId: string, kept: boolean },
	},
	ChatMessage: {
		payload: { channel: string, from: Types.ClassId, message: string, filtered: string },
	},
	ErrorNotice: {
		payload: { code: string, message: string },
	},
	MatchEnded: {
		payload: Types.VictoryResult,
	},
}

-- Remote names (must match server/client registration)
local REMOTE_NAMES = {
	SubmitActions = "SubmitActions",
	ProposeTrade = "ProposeTrade",
	RespondToTrade = "RespondToTrade",
	CastPolicyVote = "CastPolicyVote",
	ProposeBill = "ProposeBill",
	ProposeAlliance = "ProposeAlliance",
	BreakAlliance = "BreakAlliance",
	ProposePromise = "ProposePromise",
	SendChat = "SendChat",
	ReadyUp = "ReadyUp",
	ChooseClass = "ChooseClass",

	MatchStateSnapshot = "MatchStateSnapshot",
	MatchStatePatch = "MatchStatePatch",
	PhaseChanged = "PhaseChanged",
	TradeOfferReceived = "TradeOfferReceived",
	TradeOfferUpdated = "TradeOfferUpdated",
	PolicyVoteUpdate = "PolicyVoteUpdate",
	BillProposed = "BillProposed",
	BillResult = "BillResult",
	AllianceProposed = "AllianceProposed",
	AllianceFormed = "AllianceFormed",
	AllianceBroken = "AllianceBroken",
	PromiseProposed = "PromiseProposed",
	PromiseResolved = "PromiseResolved",
	ChatMessage = "ChatMessage",
	ErrorNotice = "ErrorNotice",
	MatchEnded = "MatchEnded",
}

return {
	REMOTE_NAMES = REMOTE_NAMES,
}
