--!strict
-- Lobby numbers (NETWORKING section 6): how long the server waits before a
-- bot takes over a class whose player left. Pure data.

export type LobbyConfig = {
	takeoverSeconds: number, -- the grace period after a player leaves
}

return table.freeze({
	takeoverSeconds = 20,
} :: LobbyConfig)
