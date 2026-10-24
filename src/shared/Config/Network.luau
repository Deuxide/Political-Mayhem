--!strict
-- Network payload caps and rate limits (NETWORKING section 3.1 and 7): how
-- large an untrusted payload may be, and how often a client may send each
-- remote. Pure data — the limiter itself lives in the server runtime.

export type RateLimit = {
	limit: number, -- sends per period
	periodSeconds: number, -- the length of the period, in seconds
}

export type NetworkConfig = {
	maxChatLength: number, -- characters in one chat message (NETWORKING 3.1)
	maxNameLength: number, -- characters in a display name
	maxRequestIdLength: number, -- characters in a request id
	maxTableEntries: number, -- entries in one payload table (NETWORKING 7)
	maxTableDepth: number, -- nesting depth of a payload table (NETWORKING 7)
	maxSequence: number, -- highest draft sequence number accepted
	maxSlotCount: number, -- highest slot/worker count in one draft field
	maxResourceAmount: number, -- highest amount in one bag or lobby order
	draftDebounceSeconds: number, -- wait after the last draft edit (NETWORKING 4)
	rateLimits: { [string]: RateLimit },
}

return table.freeze({
	maxChatLength = 200,
	maxNameLength = 64,
	maxRequestIdLength = 64,
	maxTableEntries = 200,
	maxTableDepth = 4,
	maxSequence = 1000000000,
	maxSlotCount = 1000,
	maxResourceAmount = 1000000,
	draftDebounceSeconds = 0.3, -- NETWORKING 4: 300 ms after the last edit
	-- The limits of NETWORKING section 3.1: "n/s" is n sends per second,
	-- except the chat, which gets one message per 0.7 s. The period is in
	-- seconds, the unit the server clock uses.
	rateLimits = {
		Lobby_SetClass = { limit = 2, periodSeconds = 1 },
		Lobby_SetReady = { limit = 2, periodSeconds = 1 },
		Lobby_Configure = { limit = 1, periodSeconds = 1 },
		Lobby_Start = { limit = 1, periodSeconds = 1 },
		Draft_Update = { limit = 5, periodSeconds = 1 },
		Draft_LockIn = { limit = 2, periodSeconds = 1 },
		Trade_Propose = { limit = 2, periodSeconds = 1 },
		Trade_Respond = { limit = 4, periodSeconds = 1 },
		Trade_Cancel = { limit = 4, periodSeconds = 1 },
		Alliance_Propose = { limit = 1, periodSeconds = 1 },
		Alliance_Respond = { limit = 2, periodSeconds = 1 },
		Alliance_Break = { limit = 1, periodSeconds = 1 },
		Bill_Propose = { limit = 1, periodSeconds = 1 },
		Chat_Send = { limit = 1, periodSeconds = 0.7 },
		Team_SetRole = { limit = 1, periodSeconds = 1 },
	},
} :: NetworkConfig)
