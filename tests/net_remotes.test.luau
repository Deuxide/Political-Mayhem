--!nocheck
-- The Net layer of M6-T1: the remote names and payload types
-- (shared/Net/Remotes.luau) and the validation toolkit
-- (shared/Net/Validate.luau, NETWORKING section 7).
--
-- Runs the real modules through tests/loader.luau.

local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

local SEATS: { [string]: { string } } = {
	Working = { "Seat-Working" },
	Middle = { "Seat-Middle" },
	Capitalist = { "Seat-Capitalist" },
	State = { "Seat-State" },
}

function M.run()
	print("net remotes")
	local shared = Loader.mount("src/shared")
	local Remotes = Loader.require(shared.Net.Remotes)

	-- The names are a contract with the client: NETWORKING section 3.
	local CLIENT_TO_SERVER = {
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
	}
	local SERVER_TO_CLIENT = {
		"View_Snapshot",
		"View_Patch",
		"Phase_Changed",
		"Reveal_Report",
		"Trade_Incoming",
		"Trade_Result",
		"Chat_Message",
		"Notice",
		"Match_Ended",
	}

	Lib.test("the client-to-server names are exactly NETWORKING section 3", function()
		Lib.eq(#Remotes.CLIENT_TO_SERVER, #CLIENT_TO_SERVER, "count")
		for index, name in CLIENT_TO_SERVER do
			Lib.eq(Remotes.CLIENT_TO_SERVER[index], name, `name {index}`)
		end
	end)

	Lib.test("the server-to-client names are exactly NETWORKING section 3", function()
		Lib.eq(#Remotes.SERVER_TO_CLIENT, #SERVER_TO_CLIENT, "count")
		for index, name in SERVER_TO_CLIENT do
			Lib.eq(Remotes.SERVER_TO_CLIENT[index], name, `name {index}`)
		end
	end)

	Lib.test("every remote name is unique and shaped Area_Action", function()
		local seen = {}
		for _, name in Remotes.ALL do
			Lib.eq(seen[name], nil, `{name} appears twice`)
			seen[name] = true
			-- "Notice" is the one documented name without an area (NETWORKING 3.2)
			if name ~= "Notice" then
				Lib.truthy(
					string.find(name, "_", 1, true) ~= nil,
					`{name} is not shaped Area_Action`
				)
			end
		end
		Lib.eq(#Remotes.ALL, #CLIENT_TO_SERVER + #SERVER_TO_CLIENT, "ALL holds both directions")
	end)

	Lib.test("the protocol version is a number the client can compare", function()
		Lib.eq(typeof(Remotes.PROTOCOL_VERSION), "number", "type")
		Lib.truthy(Remotes.PROTOCOL_VERSION > 0, "positive")
	end)
end

return M
