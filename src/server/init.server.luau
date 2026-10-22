--!strict
-- Server entry point. The server owns the match state, the validation and
-- the resolution (M6); M0 only proved the place boots and this script runs.

local RemoteFactory = require(script.Net.RemoteFactory)

print("Server booted")

-- The remotes are the server's (NETWORKING section 3): the client waits for
-- them, so a client can never create or fire a server-only remote.
local remotes = RemoteFactory.create()
local count = 0
for _ in pairs(remotes) do
	count += 1
end
print(`[Net] {count} remotes ready in ReplicatedStorage.Shared.Net`)
