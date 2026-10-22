--!strict
-- Network payload caps (NETWORKING section 7): how large an untrusted payload
-- may be before the server rejects it instead of coercing it. Pure data — the
-- per-remote rate limits arrive with the handlers (M6-T4).

export type NetworkConfig = {
	maxChatLength: number, -- characters in one chat message (NETWORKING 3.1)
	maxNameLength: number, -- characters in a display name
	maxRequestIdLength: number, -- characters in a request id
	maxTableEntries: number, -- entries in one payload table (NETWORKING 7)
	maxTableDepth: number, -- nesting depth of a payload table (NETWORKING 7)
	maxSequence: number, -- highest draft sequence number accepted
	maxSlotCount: number, -- highest slot/worker count in one draft field
	maxResourceAmount: number, -- highest amount in one bag or lobby order
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
} :: NetworkConfig)
