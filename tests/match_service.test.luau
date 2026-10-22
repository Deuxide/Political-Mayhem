--!nocheck
-- MatchService (M6-T3): the phase scheduler. The Window runs, the Day is
-- resolved, the Reveal runs, the next Window opens — all on the server's
-- clock, and never because a client asked.
--
-- The clock and the timer are injected, so the test drives the same code
-- the server runs, one timer at a time.

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
	print("match service")
	local root = Loader.mount("src")
	local Types = Loader.require(root.shared.Game.Types)
	local StateFactory = Loader.require(root.shared.Game.State.StateFactory)
	local RuleSet = Loader.require(root.shared.Game.RuleSet)
	local Rng = Loader.require(root.shared.Game.Rng)
	local Match = Loader.require(root.shared.Game.Match)
	local MatchService = Loader.require(root.server.Services.MatchService)

	-- A match with a fake clock and a fake timer: the test decides when the
	-- timer fires, so the whole flow is deterministic.
	local function newService(difficulty: string)
		local match = Match.new(
			StateFactory.create(difficulty, SEATS, 41),
			RuleSet.new(difficulty),
			Rng.new(41)
		)
		local now = 1000
		local pending = nil
		local announced = {}
		local ended = nil
		local service = MatchService.new({
			match = match,
			onPhaseChanged = function(payload)
				table.insert(announced, payload)
			end,
			onMatchEnded = function(result)
				ended = result
			end,
			clock = function()
				return now
			end,
			schedule = function(delaySeconds, callback)
				pending = { delay = delaySeconds, callback = callback }
			end,
		})
		return {
			service = service,
			match = match,
			announced = announced,
			getEnded = function()
				return ended
			end,
			fire = function()
				local timer = pending
				pending = nil
				now += timer.delay
				timer.callback()
			end,
			capture = function()
				return pending and pending.callback or nil
			end,
			pendingDelay = function()
				return pending and pending.delay or nil
			end,
		}
	end

	Lib.test("the Window opens and announces itself with an end time", function()
		local harness = newService("Normal")
		harness.service:start()

		Lib.eq(harness.service:phase(), "Window", "the phase")
		Lib.eq(#harness.announced, 1, "one announcement")
		local payload = harness.announced[1]
		Lib.eq(payload.phase, "Window", "the announced phase")
		Lib.eq(payload.day, 1, "the Day")
		Lib.eq(payload.endsAt, 1000 + 120, "the Window ends after windowSeconds")
		Lib.eq(harness.pendingDelay(), 120, "the Window timer")
		Lib.eq(harness.match:state().phase, "Window", "the state agrees")
		Lib.eq(harness.match:state().phaseEndsAt, payload.endsAt, "the state knows the end time")
	end)

	Lib.test("the timer resolves the Day and opens the Reveal", function()
		local harness = newService("Normal")
		harness.service:start()
		harness.fire()

		Lib.eq(harness.service:phase(), "Reveal", "the phase after the Window")
		Lib.eq(#harness.announced, 3, "the Window, the Resolve and the Reveal were announced")
		Lib.eq(harness.announced[2].phase, "Resolve", "the Resolve is announced")
		Lib.eq(harness.announced[2].day, 1, "the Day that was resolved")
		Lib.eq(harness.announced[3].phase, "Reveal", "the Reveal is announced")
		Lib.eq(harness.pendingDelay(), 8, "the Reveal timer")
		Lib.eq(harness.match:state().day, 2, "the Day counter advanced")
	end)

	Lib.test("the Reveal ends with the next Window", function()
		local harness = newService("Normal")
		harness.service:start()
		harness.fire()
		harness.fire()

		Lib.eq(harness.service:phase(), "Window", "the next Window")
		Lib.eq(harness.announced[4].phase, "Window", "announced")
		Lib.eq(harness.announced[4].day, 2, "the new Day")
		Lib.eq(harness.match:state().day, 2, "the state agrees")
		Lib.eq(harness.pendingDelay(), 120, "the next Window timer")
	end)

	Lib.test("a stale timer cannot move the match twice", function()
		local harness = newService("Normal")
		harness.service:start()
		harness.service:start() -- starting twice must not open a second Window
		Lib.eq(#harness.announced, 1, "one announcement only")

		local stale = harness.capture()
		harness.fire() -- the Window's timer fires: the Resolve and the Reveal
		Lib.eq(harness.service:phase(), "Reveal", "the phase after the Window")

		stale() -- the Window's timer fires again, late
		Lib.eq(harness.service:phase(), "Reveal", "the late timer changed nothing")
		Lib.eq(#harness.announced, 3, "no extra announcement")
	end)

	Lib.test("the match ends on the final Day and the loop stops", function()
		local harness = newService("Normal")
		harness.service:start()
		-- Normal runs 12 rounds; each round is two timers
		for _ = 1, 24 do
			if not harness.service:running() then
				break
			end
			harness.fire()
		end

		Lib.eq(harness.service:running(), false, "the service stopped")
		local ended = harness.getEnded()
		Lib.truthy(ended ~= nil, "the end was reported")
		Lib.eq(ended.kind, "final", "the final-Day comparison decided")
		Lib.eq(ended.day, 12, "on the last Day")
		Lib.eq(harness.match:state().day, 12, "the Day counter stopped there")
	end)

	Lib.test("the server's clock is the one the client sees", function()
		local harness = newService("Normal")
		Lib.eq(harness.service:serverTime(), 1000, "the clock")
		harness.service:start()
		harness.fire()
		Lib.eq(harness.service:serverTime(), 1000 + 120, "the clock moved with the timer")
	end)
end

return M
