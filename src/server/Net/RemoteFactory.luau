--!strict
-- Creates the RemoteEvents of NETWORKING section 3 under
-- ReplicatedStorage.Shared.Net at server boot. The client never creates a
-- remote (NETWORKING 8): it waits for the server's instances, so a client
-- cannot fire a server-only remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

export type RemoteSet = { [string]: RemoteEvent }

local RemoteFactory = {}

-- Creates every remote that is missing and returns them all by name. An
-- existing instance is reused, so a second call (a re-boot inside the same
-- server) does not duplicate the remotes.
function RemoteFactory.create(): RemoteSet
	local net = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net")
	local remotes: RemoteSet = {}
	for _, name in Remotes.ALL do
		local existing = net:FindFirstChild(name)
		local event: RemoteEvent
		if existing ~= nil and existing:IsA("RemoteEvent") then
			event = existing :: RemoteEvent
		else
			event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = net
		end
		remotes[name] = event
	end
	return remotes
end

return RemoteFactory
