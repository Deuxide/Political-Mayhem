--!nocheck
-- Replication (M6-T5): what the server sends to the clients. A client gets
-- the view of its own class — a snapshot on join and on every phase change,
-- patches for the live changes — and never the state of the whole match.
--
-- The test runs the real Replication with fake remotes and two players on
-- two classes, so the filtering is proven for both of them (the second
-- client of NETWORKING's done-when).

local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

function M.run()
	print("replication")
	local root = Loader.mount("src")
	local Remotes = Loader.require(root.shared.Net.Remotes)
	local LobbyService = Loader.require(root.server.Services.LobbyService)
	local Support = Loader.require(root.server.Handlers.Support)
	local Replication = Loader.require(root.server.Replication)

	local function fakeRemote(sent)
		local handlers = {}
		return {
			OnServerEvent = {
				Connect = function(_, handler)
					table.insert(handlers, handler)
				end,
			},
			FireClient = function(_self, player, payload)
				table.insert(sent, { player = player, payload = payload })
			end,
		}
	end

	-- Two humans on two classes, a match running in fog (Extreme), and the
	-- fake remotes the Replication writes to.
	local function newGame(difficulty)
		local lobby = LobbyService.new(4242)
		local ana = { UserId = 11, Name = "Ana" }
		local bo = { UserId = 22, Name = "Bo" }
		local players = { ana, bo }
		for _, seat in { { ana, "Middle" }, { bo, "Capitalist" } } do
			lobby:join(seat[1].UserId, seat[1].Name)
			lobby:setClass(seat[1].UserId, seat[2])
			lobby:setReady(seat[1].UserId, true)
		end
		lobby:configure(ana.UserId, difficulty)
		local match = lobby:start(ana.UserId)
		match:state().phaseEndsAt = 1000 + 60

		local sent = {}
		local remotes = {}
		for _, name in Remotes.ALL do
			remotes[name] = fakeRemote(sent)
		end
		local support = Support.new(remotes, lobby, function()
			return players
		end, function()
			return 1000
		end, function(text)
			return text, ""
		end)
		return {
			lobby = lobby,
			match = match,
			support = support,
			sent = sent,
			ana = ana,
			bo = bo,
			players = players,
			payloadsFor = function(player)
				local list = {}
				for _, entry in sent do
					if entry.player == player then
						table.insert(list, entry.payload)
					end
				end
				return list
			end,
		}
	end

	Lib.test("a snapshot carries the protocol, the view and the server time", function()
		local game = newGame("Normal")
		Replication.snapshot(game.support, game.ana)

		local payloads = game.payloadsFor(game.ana)
		Lib.eq(#payloads, 1, "one snapshot")
		Lib.eq(payloads[1].protocol, Remotes.PROTOCOL_VERSION, "the protocol version")
		Lib.eq(payloads[1].view.viewer, "Middle", "the view of the player's own class")
		Lib.eq(payloads[1].serverTime, 1000, "the server time")
		Lib.eq(#game.payloadsFor(game.bo), 0, "the other player got nothing")
	end)

	Lib.test("the second client sees only the fields its own class may see", function()
		local game = newGame("Extreme")
		Replication.snapshot(game.support, game.ana)
		Replication.snapshot(game.support, game.bo)

		local ana = game.payloadsFor(game.ana)[1].view
		local bo = game.payloadsFor(game.bo)[1].view

		-- fog: the other class's Money, stocks and Influence are absent
		Lib.eq(ana.others.Capitalist.money, nil, "the Capitalist's Money is hidden from Ana")
		Lib.eq(
			ana.others.Capitalist.influence,
			nil,
			"the Capitalist's Influence is hidden from Ana"
		)
		Lib.eq(
			next(ana.others.Capitalist.stock),
			nil,
			"the Capitalist's stocks are hidden from Ana"
		)
		Lib.eq(bo.others.Middle.money, nil, "the Middle's Money is hidden from Bo")
		Lib.eq(next(bo.others.Middle.stock), nil, "the Middle's stocks are hidden from Bo")

		-- but their own class is complete
		Lib.eq(ana.own.money, game.match:state().classes.Middle.money, "Ana sees her own Money")
		Lib.eq(bo.own.money, game.match:state().classes.Capitalist.money, "Bo sees his own Money")
		Lib.eq(ana.others.Capitalist.vp, 0, "the VP is public in every mode")
		Lib.eq(#ana.others.Capitalist.lines, 4, "the lines are public in every mode")
	end)

	Lib.test("a patch goes to the members of one class only", function()
		local game = newGame("Normal")
		Replication.patch(game.support, "Middle", "draft", { sequence = 3 })

		local ana = game.payloadsFor(game.ana)
		Lib.eq(#ana, 1, "Ana got the patch")
		Lib.eq(ana[1].ops[1].path, "draft", "the patch carries the path")
		Lib.eq(ana[1].ops[1].value.sequence, 3, "and the value")
		Lib.eq(#game.payloadsFor(game.bo), 0, "Bo is on another class and got nothing")
	end)

	Lib.test("a public patch goes to everybody", function()
		local game = newGame("Normal")
		Replication.patchAll(game.support, "bills", { id = "Bill-1" })
		Lib.eq(#game.payloadsFor(game.ana), 1, "Ana got it")
		Lib.eq(#game.payloadsFor(game.bo), 1, "Bo got it")
	end)

	Lib.test("the report of a Day carries the events and only the viewer's own delta", function()
		local game = newGame("Normal")
		Replication.reveal(game.support, game.ana, {
			day = 1,
			events = { { day = 1, text = "Working received 4 Money in wages" } },
			deltas = {
				Middle = { money = -2, influence = 0, stock = {}, vp = 1 },
				Capitalist = { money = 5, influence = 0, stock = {}, vp = 1 },
			},
		})

		local report = game.payloadsFor(game.ana)[1]
		Lib.eq(report.day, 1, "the Day")
		Lib.eq(#report.events, 1, "the events")
		Lib.eq(report.deltas.Middle.money, -2, "her own delta travels")
		Lib.eq(report.deltas.Capitalist, nil, "the other class's delta does not")
		Lib.eq(#game.payloadsFor(game.bo), 0, "the other client got no report")
	end)

	Lib.test("the end of the match reaches every client", function()
		local game = newGame("Normal")
		Replication.ended(
			game.support,
			{ kind = "final", winners = { "Middle" }, day = 12 },
			"the end"
		)
		Lib.eq(#game.payloadsFor(game.ana), 1, "Ana got it")
		Lib.eq(#game.payloadsFor(game.bo), 1, "Bo got it")
		Lib.eq(game.payloadsFor(game.ana)[1].result.kind, "final", "the result")
	end)

	Lib.test("a final snapshot carries the victory and the final standings", function()
		local game = newGame("Normal")
		local result = { kind = "final", winners = { "Middle" }, day = 12 }
		game.match:state().victory = result
		Replication.snapshot(game.support, game.ana)
		local view = game.payloadsFor(game.ana)[1].view
		Lib.eq(view.victory.kind, "final", "the result travels in the snapshot")
		Lib.eq(view.victory.day, 12, "the final Day")
		Lib.eq(view.own.vp, game.match:state().classes.Middle.vp, "the final own VP")
	end)
end

return M
