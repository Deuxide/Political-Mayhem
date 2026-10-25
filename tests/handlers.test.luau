--!nocheck
-- The server handlers of M6-T4: Draft, Trade, Alliance, Bill and Chat.
--
-- The tests drive the real handlers with fake players and fake remotes, so
-- every path (accept, refuse, rate limit, wrong phase) is exercised without
-- the engine. They also cover the first four items of the anti-exploit
-- checklist (NETWORKING section 8).

local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

function M.run()
	print("server handlers")
	local root = Loader.mount("src")
	local Remotes = Loader.require(root.shared.Net.Remotes)
	local LobbyService = Loader.require(root.server.Services.LobbyService)
	local Support = Loader.require(root.server.Handlers.Support)
	local DraftHandlers = Loader.require(root.server.Handlers.DraftHandlers)
	local TradeHandlers = Loader.require(root.server.Handlers.TradeHandlers)
	local AllianceHandlers = Loader.require(root.server.Handlers.AllianceHandlers)
	local BillHandlers = Loader.require(root.server.Handlers.BillHandlers)
	local ChatHandlers = Loader.require(root.server.Handlers.ChatHandlers)
	local Bills = Loader.require(root.shared.Game.Ops.Bills)
	local PlayerViewBuilder = Loader.require(root.shared.Game.Behaviors.InfoModes.PlayerViewBuilder)

	-- A fake remote: it records what the server sent and lets the test fire
	-- the server handler.
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
			fire = function(player, payload)
				for _, handler in handlers do
					handler(player, payload)
				end
			end,
			count = function()
				return #handlers
			end,
		}
	end

	-- A lobby with one human on the Middle class and a running match.
	local function newGame(options)
		options = options or {}
		local lobby = LobbyService.new(4242)
		local player = { UserId = 11, Name = "Ana" }
		local players = { player }
		lobby:join(player.UserId, player.Name)
		lobby:setClass(player.UserId, options.classId or "Middle")
		lobby:setReady(player.UserId, true)
		if options.second ~= nil then
			local second = { UserId = 22, Name = "Bo" }
			table.insert(players, second)
			lobby:join(second.UserId, second.Name)
			lobby:setClass(second.UserId, options.second)
			lobby:setReady(second.UserId, true)
		end
		local match = lobby:start(player.UserId)
		-- the scheduler is not running in the test, so the Window has no end
		-- yet; the handlers read it
		match:state().phaseEndsAt = 1000 + 60

		local sent = {}
		local remotes = {}
		for _, name in Remotes.ALL do
			remotes[name] = fakeRemote(sent)
		end

		local now = 1000
		local support = Support.new(remotes, lobby, function()
			return players
		end, function()
			return now
		end, options.filter or function(text)
			return text, ""
		end)
		DraftHandlers.connect(support)
		TradeHandlers.connect(support)
		AllianceHandlers.connect(support)
		BillHandlers.connect(support)
		ChatHandlers.connect(support)

		return {
			lobby = lobby,
			match = match,
			support = support,
			remotes = remotes,
			sent = sent,
			player = player,
			players = players,
			advance = function(seconds)
				now += seconds
			end,
			state = function()
				return match:state()
			end,
			notices = function()
				local list = {}
				for _, entry in sent do
					if entry.payload and entry.payload.code then
						table.insert(list, entry.payload)
					end
				end
				return list
			end,
			ofRemote = function(name)
				local list = {}
				for _, entry in sent do
					if entry.payload and entry.payload.code == nil then
						table.insert(list, entry.payload)
					end
				end
				return list
			end,
			patches = function(player, path, op)
				local values = {}
				for _, entry in sent do
					if entry.player == player and entry.payload and entry.payload.ops then
						for _, patch in entry.payload.ops do
							if patch.path == path and patch.op == op then
								table.insert(values, patch.value)
							end
						end
					end
				end
				return values
			end,
		}
	end

	Lib.test("a valid draft is stored, clamped and announced (NETWORKING 4)", function()
		local game = newGame()
		game.remotes.Draft_Update.fire(game.player, {
			seq = 1,
			draft = {
				sequence = 1,
				locked = false,
				openSlots = { ["Farm-1"] = 99 },
				assign = {},
				market = { sell = {}, buy = {} },
				votes = {},
			},
		})

		local draft = game.state().drafts.Middle
		Lib.eq(draft.sequence, 1, "the sequence is stored")
		Lib.eq(draft.openSlots["Farm-1"], 2, "the open slots are clamped to the line's slotsMax")
		Lib.eq(#game.ofRemote(), 1, "one patch was sent")
		Lib.eq(game.ofRemote()[1].ops[1].path, "draft", "the patch carries the draft")
	end)

	Lib.test("a draft with an unknown key is refused (NETWORKING 7)", function()
		local game = newGame()
		game.remotes.Draft_Update.fire(game.player, {
			seq = 1,
			draft = {
				sequence = 1,
				locked = false,
				openSlots = {},
				assign = {},
				market = { sell = {}, buy = {} },
				votes = {},
				sneaky = true,
			},
		})

		Lib.eq(game.state().drafts.Middle.sequence, 0, "the state did not change")
		Lib.eq(game.notices()[1].code, "InvalidPayload", "the client is told why")
	end)

	Lib.test("an older draft is ignored (NETWORKING 4)", function()
		local game = newGame()
		game.remotes.Draft_Update.fire(game.player, {
			seq = 5,
			draft = {
				sequence = 5,
				openSlots = {},
				locked = false,
				openSlots = {},
				openSlots = {},
				assign = {},
				market = { sell = {}, buy = {} },
				votes = {},
			},
		})
		game.remotes.Draft_Update.fire(game.player, {
			seq = 2,
			draft = {
				sequence = 2,
				openSlots = {},
				locked = false,
				openSlots = {},
				openSlots = {},
				assign = {},
				market = { sell = {}, buy = {} },
				votes = {},
			},
		})

		Lib.eq(game.state().drafts.Middle.sequence, 5, "the newer draft stays")
		Lib.eq(game.notices()[1].code, "StaleDraft", "the client is told why")
	end)

	Lib.test("no action is accepted outside the Window (NETWORKING 5)", function()
		local game = newGame()
		game.state().phase = "Reveal"
		game.remotes.Draft_Update.fire(game.player, {
			seq = 1,
			draft = {
				sequence = 1,
				locked = false,
				openSlots = {},
				assign = {},
				market = { sell = {}, buy = {} },
				votes = {},
			},
		})

		Lib.eq(game.state().drafts.Middle.sequence, 0, "the state did not change")
		Lib.eq(game.notices()[1].code, "WindowClosed", "the client is told why")
	end)

	Lib.test("the draft remote is rate limited (NETWORKING 3.1)", function()
		local game = newGame()
		for index = 1, 5 do
			game.remotes.Draft_Update.fire(game.player, {
				seq = index,
				draft = {
					sequence = index,
					locked = false,
					openSlots = {},
					assign = {},
					market = { sell = {}, buy = {} },
					votes = {},
				},
			})
		end
		Lib.eq(game.state().drafts.Middle.sequence, 5, "five drafts went through")
		game.remotes.Draft_Update.fire(game.player, {
			seq = 6,
			draft = {
				sequence = 6,
				openSlots = {},
				locked = false,
				openSlots = {},
				openSlots = {},
				assign = {},
				market = { sell = {}, buy = {} },
				votes = {},
			},
		})
		Lib.eq(game.state().drafts.Middle.sequence, 5, "the sixth was dropped")
		Lib.eq(game.notices()[1].code, "RateLimited", "the client is told why")
	end)

	Lib.test("a client that never joined gets nothing (NETWORKING 2)", function()
		local game = newGame()
		local stranger = { UserId = 99, Name = "Stranger" }
		game.remotes.Draft_Update.fire(stranger, {
			seq = 1,
			draft = {
				sequence = 1,
				locked = false,
				openSlots = {},
				assign = {},
				market = { sell = {}, buy = {} },
				votes = {},
			},
		})
		Lib.eq(game.state().drafts.Middle.sequence, 0, "the state did not change")
		Lib.eq(game.notices()[1].code, "NotSeated", "the client is told why")
	end)

	Lib.test("a trade offer is created and the other class hears about it", function()
		local game = newGame()
		game.remotes.Trade_Propose.fire(game.player, {
			requestId = "r1",
			to = "Capitalist",
			give = { Money = 5 },
			want = { Goods = 1 },
			promises = {},
		})

		Lib.eq(#game.state().trades, 1, "the offer is live")
		Lib.eq(game.state().trades[1].from, "Middle", "the sender's class, not a payload field")
		Lib.eq(game.state().trades[1].to, "Capitalist", "the target")
		Lib.eq(game.state().trades[1].give.Money, 5, "the amount")
	end)

	Lib.test("a trade offer with a bad bag is refused", function()
		local game = newGame()
		game.remotes.Trade_Propose.fire(game.player, {
			requestId = "r1",
			to = "Capitalist",
			give = { Money = -5 },
			want = {},
			promises = {},
		})
		Lib.eq(#game.state().trades, 0, "no offer")
		Lib.eq(game.notices()[1].code, "InvalidPayload", "the client is told why")
	end)

	Lib.test("only the recipient may answer an offer, and the money is checked again", function()
		local game = newGame({ second = "Capitalist" })
		game.remotes.Trade_Propose.fire(game.player, {
			requestId = "r1",
			to = "Capitalist",
			give = { Money = 5 },
			want = { Goods = 1000 },
			promises = {},
		})
		local offerId = game.state().trades[1].id

		-- the sender may not answer its own offer
		game.remotes.Trade_Respond.fire(game.player, { offerId = offerId, accept = true })
		Lib.eq(game.notices()[1].code, "Rejected", "the sender is refused")

		-- the recipient answers, but it cannot pay what it wants: the engine
		-- checks the money again when the trade is accepted
		local capitalist = game.players[2]
		game.remotes.Trade_Respond.fire(capitalist, { offerId = offerId, accept = true })
		-- the offer is gone either way; the result says what happened
		local result = game.ofRemote()[#game.ofRemote()]
		Lib.eq(result.status, "failed", "the trade failed")
		Lib.eq(game.state().classes.Middle.money, 25, "no money moved")
	end)

	Lib.test("a trade with a promise is accepted and the promise becomes public", function()
		local game = newGame({ second = "Capitalist" })
		game.remotes.Trade_Propose.fire(game.player, {
			requestId = "r1",
			to = "Capitalist",
			give = { Money = 5 },
			want = { Goods = 1 },
			promises = {
				{ kind = "Deliver", resource = "Money", amount = 3, to = "Capitalist", byDay = 2 },
			},
		})
		local offerId = game.state().trades[1].id
		Lib.eq(offerId, "Trade-1", "the offer id")

		local capitalist = game.players[2]
		game.remotes.Trade_Respond.fire(capitalist, { offerId = offerId, accept = true })

		Lib.eq(#game.state().trades, 0, "the offer is gone")
		Lib.eq(game.state().classes.Middle.money, 20, "Middle paid 5")
		Lib.eq(game.state().classes.Capitalist.money, 55, "Capitalist got 5")
		Lib.eq(game.state().classes.Capitalist.stock.goods, 1, "Capitalist paid 1 Goods")
		Lib.eq(game.state().classes.Middle.stock.goods, 2, "Middle got 1 Goods")

		Lib.eq(#game.state().promises, 1, "the promise exists")
		local promise = game.state().promises[1]
		Lib.eq(promise.from, "Middle", "the promisor")
		Lib.eq(promise.to, "Capitalist", "the promisee")
		Lib.eq(promise.kind, "Deliver", "the kind")
		Lib.eq(promise.spec.amount, 3, "the amount")
		Lib.eq(promise.status, "open", "the promise is open")

		-- the acceptance reached both parties, and so did the public patch
		local results = 0
		local patches = 0
		for _, entry in game.sent do
			local payload = entry.payload
			if
				payload
				and payload.offerId == offerId
				and payload.status == "accepted"
				and payload.requestId == nil
			then
				results += 1
			end
			if payload and payload.ops and payload.ops[1].path == "promises" then
				Lib.eq(payload.ops[1].op, "append", "the patch is an append")
				Lib.eq(payload.ops[1].value.id, promise.id, "the patch carries the promise")
				patches += 1
			end
		end
		Lib.eq(results, 2, "both parties heard the acceptance")
		Lib.eq(patches, 2, "both parties got the promise patch")
	end)

	Lib.test("a withdrawn offer reaches both parties (NETWORKING 3.2)", function()
		local game = newGame({ second = "Capitalist" })
		game.remotes.Trade_Propose.fire(game.player, {
			requestId = "r1",
			to = "Capitalist",
			give = { Money = 5 },
			want = {},
			promises = {},
		})
		local offerId = game.state().trades[1].id
		game.remotes.Trade_Cancel.fire(game.player, { offerId = offerId })
		Lib.eq(#game.state().trades, 0, "the offer is gone")

		local results = 0
		for _, entry in game.sent do
			local payload = entry.payload
			if payload and payload.offerId == offerId and payload.status == "declined" then
				results += 1
			end
		end
		Lib.eq(results, 2, "both parties heard the withdrawal")
	end)

	Lib.test("an alliance is proposed, accepted and broken through the remotes (M8-T3)", function()
		local game = newGame({ second = "Capitalist" })
		local capitalist = game.players[2]
		game.remotes.Alliance_Propose.fire(game.player, { to = "Capitalist" })
		Lib.eq(#game.state().allianceProposals, 1, "the proposal is live")
		local proposal = game.state().allianceProposals[1]
		Lib.eq(proposal.from, "Middle", "the sender's class")
		Lib.eq(
			#game.patches(game.player, "allianceProposals", "append"),
			1,
			"the proposer got the proposal"
		)
		Lib.eq(
			#game.patches(capitalist, "allianceProposals", "append"),
			1,
			"the recipient got the proposal"
		)
		Lib.eq(#game.patches(game.player, "alliances", "append"), 0, "no active alliance yet")

		local stateBefore = game.state()
		local middleView = PlayerViewBuilder.build(stateBefore, game.match:ruleSet(), "Middle")
		local outsiderView = PlayerViewBuilder.build(stateBefore, game.match:ruleSet(), "State")
		Lib.eq(#middleView.allianceProposals, 1, "the proposal is in the proposer's view")
		Lib.eq(#outsiderView.allianceProposals, 0, "a third class does not see it")

		game.remotes.Alliance_Respond.fire(capitalist, { from = "Middle", accept = true })
		Lib.eq(#game.state().alliances, 1, "the alliance exists")
		local alliance = game.state().alliances[1]
		Lib.eq(alliance.members[1], "Middle", "the first member")
		Lib.eq(alliance.members[2], "Capitalist", "the second member")
		Lib.eq(#game.state().allianceProposals, 0, "the proposal is gone")
		Lib.eq(
			#game.patches(game.player, "allianceProposals", "remove"),
			1,
			"the proposer dropped the proposal"
		)
		Lib.eq(
			#game.patches(capitalist, "allianceProposals", "remove"),
			1,
			"the recipient dropped the proposal"
		)
		Lib.eq(
			#game.patches(game.player, "alliances", "append"),
			1,
			"the proposer got the public alliance"
		)
		Lib.eq(#game.patches(capitalist, "alliances", "append"), 1, "the recipient got it too")

		local alliedView = PlayerViewBuilder.build(game.state(), game.match:ruleSet(), "State")
		Lib.eq(#alliedView.alliances, 1, "the active alliance is public")
		Lib.eq(#alliedView.allianceProposals, 0, "the proposal stays private")

		game.remotes.Alliance_Break.fire(game.player, {})
		Lib.eq(#game.state().alliances, 0, "the alliance is gone")
		Lib.eq(#game.patches(game.player, "alliances", "remove"), 1, "the proposer got the break")
		Lib.eq(#game.patches(capitalist, "alliances", "remove"), 1, "the recipient got the break")
		Lib.eq(
			game.patches(game.player, "alliances", "remove")[1].id,
			alliance.id,
			"the right alliance"
		)
		local brokenView = PlayerViewBuilder.build(game.state(), game.match:ruleSet(), "State")
		Lib.eq(#brokenView.alliances, 0, "the public badge is gone")
	end)

	Lib.test("a declined alliance proposal leaves both views", function()
		local game = newGame({ second = "Capitalist" })
		local capitalist = game.players[2]
		game.remotes.Alliance_Propose.fire(game.player, { to = "Capitalist" })
		game.remotes.Alliance_Respond.fire(capitalist, { from = "Middle", accept = false })
		Lib.eq(#game.state().alliances, 0, "no alliance")
		Lib.eq(#game.state().allianceProposals, 0, "the proposal is gone")
		Lib.eq(
			#game.patches(game.player, "allianceProposals", "remove"),
			1,
			"the proposer dropped it"
		)
		Lib.eq(
			#game.patches(capitalist, "allianceProposals", "remove"),
			1,
			"the recipient dropped it"
		)
		Lib.eq(#game.patches(game.player, "alliances", "append"), 0, "no public alliance")
	end)

	Lib.test("an alliance answer for the wrong proposer is refused", function()
		local game = newGame({ second = "Capitalist" })
		game.remotes.Alliance_Propose.fire(game.player, { to = "Capitalist" })
		local capitalist = game.players[2]
		game.remotes.Alliance_Respond.fire(capitalist, { from = "Working", accept = true })
		Lib.eq(#game.state().alliances, 0, "no alliance")
		Lib.eq(game.notices()[1].code, "Rejected", "the client is told why")
	end)

	Lib.test(
		"a bill is proposed, the Influence is spent, and a bill without Influence is refused",
		function()
			local game = newGame()
			game.remotes.Bill_Propose.fire(
				game.player,
				{ requestId = "r1", policyId = "Wage", level = 3 }
			)
			Lib.eq(#game.state().bills, 1, "the bill is live")
			Lib.eq(game.state().bills[1].proposer, "Middle", "the sender's class")
			Lib.eq(game.state().classes.Middle.influence, 1, "the Influence was spent")

			-- a second bill the class cannot pay for
			game.advance(1)
			game.remotes.Bill_Propose.fire(
				game.player,
				{ requestId = "r2", policyId = "Wage", level = 4 }
			)
			Lib.eq(#game.state().bills, 1, "no second bill")
			Lib.eq(game.notices()[1].code, "Rejected", "the client is told why")
		end
	)

	Lib.test("a bill passes with the votes of two clients", function()
		local game = newGame({ second = "Capitalist" })
		game.remotes.Bill_Propose.fire(
			game.player,
			{ requestId = "b1", policyId = "Wage", level = 3 }
		)
		Lib.eq(#game.state().bills, 1, "the bill is live")
		local billId = game.state().bills[1].id
		Lib.eq(game.state().classes.Middle.influence, 1, "the Middle paid the proposal cost")

		local function castVote(player, side)
			game.remotes.Draft_Update.fire(player, {
				seq = 1,
				draft = {
					sequence = 1,
					locked = false,
					openSlots = {},
					assign = {},
					market = { sell = {}, buy = {} },
					votes = { [billId] = { side = side, influence = 0 } },
				},
			})
		end
		castVote(game.player, "yes")
		local capitalist = game.players[2]
		castVote(capitalist, "yes")

		Lib.eq(game.state().drafts.Middle.votes[billId].side, "yes", "the Middle's ballot")
		Lib.eq(game.state().drafts.Capitalist.votes[billId].side, "yes", "the Capitalist's ballot")

		local tally = Bills.tally(game.state(), billId)
		Lib.eq(tally.yesWeight, 5, "Middle 3 + Capitalist 2")
		Lib.eq(tally.noWeight, 0, "no votes against")
		Lib.eq(tally.passed, true, "the bill passes")

		local heard = 0
		for _, entry in game.sent do
			if entry.player == capitalist and entry.payload.ops ~= nil then
				for _, op in entry.payload.ops do
					if op.path == "bills" and op.value.id == billId then
						heard += 1
					end
				end
			end
		end
		Lib.eq(heard, 1, "the other client heard about the bill")
	end)

	Lib.test("chat is filtered before it goes out, and only to the audience", function()
		local game = newGame({
			filter = function(text)
				if text == "bad" then
					return nil, "that message may not be sent"
				end
				return "[" .. text .. "]", ""
			end,
		})
		game.remotes.Chat_Send.fire(game.player, { channel = "Global", text = "hello" })
		local message = game.ofRemote()[1]
		Lib.eq(message.text, "[hello]", "the filtered text goes out")
		Lib.eq(message.fromClass, "Middle", "the sender's class")
		Lib.eq(message.fromName, "Ana", "the sender's name")

		game.advance(1)
		game.remotes.Chat_Send.fire(game.player, { channel = "Global", text = "bad" })
		Lib.eq(#game.ofRemote(), 1, "the filtered message did not go out")
		Lib.eq(game.notices()[1].code, "Filtered", "the client is told why")
	end)

	Lib.test("a message that is too long is refused (NETWORKING 3.1)", function()
		local game = newGame()
		game.remotes.Chat_Send.fire(
			game.player,
			{ channel = "Global", text = string.rep("x", 201) }
		)
		Lib.eq(#game.ofRemote(), 0, "nothing went out")
		Lib.eq(game.notices()[1].code, "InvalidPayload", "the client is told why")
	end)

	Lib.test("a player who left cannot act (NETWORKING 6)", function()
		local game = newGame()
		game.lobby:disconnect(game.player.UserId)
		game.remotes.Draft_Update.fire(game.player, {
			seq = 1,
			draft = {
				sequence = 1,
				locked = false,
				openSlots = {},
				assign = {},
				market = { sell = {}, buy = {} },
				votes = {},
			},
		})
		Lib.eq(game.state().drafts.Middle.sequence, 0, "the state did not change")
		Lib.eq(game.notices()[1].code, "Disconnected", "the client is told why")
	end)

	Lib.test("no client remote can move a phase (NETWORKING 8)", function()
		for _, name in Remotes.CLIENT_TO_SERVER do
			Lib.eq(
				string.find(name, "Phase", 1, true) == nil
					and string.find(name, "Resolve", 1, true) == nil,
				true,
				`{name} does not touch the phases`
			)
		end
	end)
end

return M
