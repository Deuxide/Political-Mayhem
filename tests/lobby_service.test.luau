--!nocheck
-- LobbyService (M6-T2): the lobby flow — join, class choice, ready, host
-- start — and the bots that fill the classes no human took.
--
-- Runs the real server module through tests/loader.luau (the loader hands
-- server modules their ReplicatedStorage.Shared path).

local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

function M.run()
	print("lobby service")
	local root = Loader.mount("src")
	local LobbyService = Loader.require(root.server.Services.LobbyService)
	local Seats = Loader.require(root.shared.Net.Seats)

	local function newLobby()
		return LobbyService.new(4242)
	end

	Lib.test("a player joins and the first joiner hosts", function()
		local lobby = newLobby()
		local seat = lobby:join(11, "Ana")
		Lib.eq(seat.id, "Seat-11", "seat id")
		Lib.eq(seat.kind, "Human", "kind")
		Lib.eq(seat.classId, nil, "no class yet")
		Lib.eq(seat.ready, false, "not ready yet")
		Lib.eq(#seat.roles, 3, "one player holds every role (GAME_DESIGN 14)")
		Lib.truthy(lobby:isHost(11), "the first joiner hosts")
		Lib.eq(lobby:seatOf(11).id, "Seat-11", "the seat is found by user id")
		Lib.eq(lobby:seatOf(99), nil, "an unknown user has no seat")
	end)

	Lib.test("joining again returns the same seat", function()
		local lobby = newLobby()
		local first = lobby:join(11, "Ana")
		local second = lobby:join(11, "Ana")
		Lib.eq(second.id, first.id, "the same seat")
		Lib.eq(#lobby:seats(), 1, "one seat only")
	end)

	Lib.test("a class is taken by one human at a time (NETWORKING 3.1)", function()
		local lobby = newLobby()
		lobby:join(11, "Ana")
		lobby:join(22, "Bo")
		local ok = lobby:setClass(11, "Middle")
		Lib.truthy(ok, "the first player takes the class")
		local refused, reason = lobby:setClass(22, "Middle")
		Lib.eq(refused, false, "the second player is refused")
		Lib.contains(reason, "already has a human player", "with the reason")
		Lib.eq(lobby:seatOf(22).classId, nil, "the refused choice changed nothing")
		-- the other class is still free
		Lib.truthy(lobby:setClass(22, "Capitalist"), "another class is free")
	end)

	Lib.test("only the host configures the match", function()
		local lobby = newLobby()
		lobby:join(11, "Ana")
		lobby:join(22, "Bo")
		local refused, reason = lobby:configure(22, "Hard")
		Lib.eq(refused, false, "a non-host cannot configure")
		Lib.contains(reason, "only the host", "with the reason")
		Lib.truthy(lobby:configure(11, "Hard"), "the host configures")
		Lib.eq(lobby:difficulty(), "Hard", "the difficulty is set")
	end)

	Lib.test("the host starts only when every human is ready and has a class", function()
		local lobby = newLobby()
		lobby:join(11, "Ana")
		lobby:join(22, "Bo")
		lobby:setClass(11, "Middle")
		lobby:setClass(22, "Capitalist")
		lobby:setReady(11, true)

		local refused, reason = lobby:start(11)
		Lib.eq(refused, nil, "the match does not start")
		Lib.contains(reason, "is not ready", "the player who is not ready is named")

		lobby:setReady(22, true)
		Lib.truthy(lobby:start(11) ~= nil, "the match starts")
	end)

	Lib.test("a non-host cannot start the match", function()
		local lobby = newLobby()
		lobby:join(11, "Ana")
		lobby:join(22, "Bo")
		lobby:setClass(11, "Middle")
		lobby:setClass(22, "Capitalist")
		lobby:setReady(11, true)
		lobby:setReady(22, true)
		local match, reason = lobby:start(22)
		Lib.eq(match, nil, "the match does not start")
		Lib.contains(reason, "only the host", "with the reason")
	end)

	Lib.test("one human and three bots fill the four classes", function()
		local lobby = newLobby()
		lobby:join(11, "Ana")
		lobby:setClass(11, "Middle")
		lobby:setReady(11, true)
		local match = lobby:start(11)
		Lib.truthy(match ~= nil, "the match starts")

		local map = lobby:seatMap()
		Lib.eq(#map.Middle, 1, "the Middle has one seat")
		Lib.eq(map.Middle[1], "Seat-11", "the human seat")
		Lib.eq(#map.Working, 1, "the Working has one seat")
		Lib.eq(map.Working[1], "Bot-Working", "the bot seat")
		Lib.eq(#map.Capitalist, 1, "the Capitalist has one seat")
		Lib.eq(map.Capitalist[1], "Bot-Capitalist", "the bot seat")
		Lib.eq(#map.State, 1, "the State has one seat")
		Lib.eq(map.State[1], "Bot-State", "the bot seat")

		local state = match:state()
		Lib.eq(state.classes.Middle.seats[1], "Seat-11", "the Middle is played by the human")
		Lib.eq(state.classes.Working.seats[1], "Bot-Working", "the Working is played by a bot")
		Lib.eq(state.difficulty, "Normal", "the default difficulty")
		Lib.eq(state.seed, 4242, "the server's seed")
		Lib.eq(state.id, "mayhem-4242", "the match id follows the seed")
	end)

	Lib.test("the started match cannot be started again", function()
		local lobby = newLobby()
		lobby:join(11, "Ana")
		lobby:setClass(11, "Middle")
		lobby:setReady(11, true)
		Lib.truthy(lobby:start(11) ~= nil, "the match starts")
		local again, reason = lobby:start(11)
		Lib.eq(again, nil, "no second match")
		Lib.contains(reason, "already started", "with the reason")
		-- and the lobby refuses further changes
		Lib.eq(lobby:setReady(11, false), false, "no more ready changes")
		Lib.eq(lobby:setClass(11, "Working"), false, "no more class changes")
	end)

	Lib.test("the start signal carries the new match", function()
		local lobby = newLobby()
		local seen = nil
		lobby:onStart(function(match)
			seen = match
		end)
		lobby:join(11, "Ana")
		lobby:setClass(11, "Middle")
		lobby:setReady(11, true)
		local match = lobby:start(11)
		Lib.truthy(seen ~= nil, "the signal fired")
		Lib.eq(seen, match, "with the match that was created")
	end)

	Lib.test("the role split follows GAME_DESIGN section 14", function()
		Lib.eq(#Seats.rolesFor(1)[1], 3, "one player holds every role")
		Lib.eq(#Seats.rolesFor(2), 2, "two players")
		Lib.eq(#Seats.rolesFor(2)[1], 2, "the first holds Economy and Diplomacy")
		Lib.eq(#Seats.rolesFor(2)[2], 1, "the second holds Politics")
		Lib.eq(#Seats.rolesFor(3), 3, "three players")
		Lib.eq(#Seats.rolesFor(4), 4, "a fourth player joins")
		Lib.eq(Seats.rolesFor(4)[4][1], "Advisor", "as an advisor")
	end)

	Lib.test(
		"a player who leaves keeps the seat, and a bot takes over after the grace period",
		function()
			local lobby = newLobby()
			lobby:join(11, "Ana")
			lobby:setClass(11, "Middle")
			lobby:setReady(11, true)

			Lib.truthy(lobby:disconnect(11), "the player left")
			Lib.eq(lobby:seatOf(11).connected, false, "the seat knows the player is away")
			Lib.eq(lobby:seatOf(11).botControlled, false, "nobody plays the class yet")

			Lib.truthy(lobby:takeover(11), "the bot takes over")
			Lib.eq(lobby:seatOf(11).botControlled, true, "the class is played by a bot")
			Lib.eq(lobby:takeover(11), false, "the takeover happens once")
		end
	)

	Lib.test("a player who comes back in time keeps the class", function()
		local lobby = newLobby()
		lobby:join(11, "Ana")
		lobby:disconnect(11)
		Lib.truthy(lobby:reconnect(11), "the player came back")
		Lib.eq(lobby:seatOf(11).connected, true, "the seat is connected again")
		Lib.eq(lobby:takeover(11), false, "no bot takes over a class that is back")
		Lib.eq(lobby:seatOf(11).botControlled, false, "the class is the player's again")
	end)

	Lib.test("a player who comes back after the takeover gets the class back", function()
		local lobby = newLobby()
		lobby:join(11, "Ana")
		lobby:disconnect(11)
		lobby:takeover(11)
		lobby:reconnect(11)
		Lib.eq(lobby:seatOf(11).botControlled, false, "the class is the player's again")
		Lib.eq(lobby:seatOf(11).connected, true, "and the seat is connected")
	end)
end

return M
