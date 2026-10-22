--!strict
-- MatchService (M6-T3): the phase scheduler. The server owns the clock
-- (NETWORKING 5): the Window runs for the difficulty's windowSeconds, then
-- the Day is resolved on the server, then the Reveal runs for revealSeconds,
-- and the next Window opens.
--
-- Nothing a client sends moves a phase (NETWORKING 8): the only way a phase
-- changes is the timer this service owns. The clock and the timer are
-- injected, so the flow can be driven deterministically in a test and runs
-- on the real clock on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Match = require(ReplicatedStorage.Shared.Game.Match)

type MatchType = Match.Match
type Phase = Types.Phase
type PhaseChangedPayload = Remotes.PhaseChangedPayload
type VictoryResult = Types.VictoryResult

export type MatchServiceOptions = {
	match: MatchType,
	onPhaseChanged: (PhaseChangedPayload) -> (),
	onMatchEnded: ((VictoryResult) -> ())?,
	clock: () -> number, -- epoch milliseconds
	schedule: (delaySeconds: number, callback: () -> ()) -> (),
}

local MatchService = {}
MatchService.__index = MatchService

export type MatchService = typeof(setmetatable(
	{} :: {
		_match: MatchType,
		_onPhaseChanged: (PhaseChangedPayload) -> (),
		_onMatchEnded: ((VictoryResult) -> ())?,
		_clock: () -> number,
		_schedule: (number, () -> ()) -> (),
		_phase: Phase,
		_running: boolean,
		_generation: number,
	},
	MatchService
))

function MatchService.new(options: MatchServiceOptions): MatchService
	return setmetatable({
		_match = options.match,
		_onPhaseChanged = options.onPhaseChanged,
		_onMatchEnded = options.onMatchEnded,
		_clock = options.clock,
		_schedule = options.schedule,
		_phase = "Window" :: Phase,
		_running = false,
		_generation = 0,
	}, MatchService)
end

-- Opens the first Window and starts the loop.
function MatchService.start(self: MatchService)
	if self._running then
		return
	end
	self._running = true
	self:_openWindow()
end

function MatchService.phase(self: MatchService): Phase
	return self._phase
end

-- The server's clock, in epoch seconds (NETWORKING 5).
function MatchService.serverTime(self: MatchService): number
	return self._clock()
end

function MatchService.running(self: MatchService): boolean
	return self._running
end

-- A timer that fires later; a timer from an earlier phase is ignored, so a
-- late callback can never move the match twice.
function MatchService._after(self: MatchService, seconds: number, callback: () -> ())
	self._generation += 1
	local generation = self._generation
	self._schedule(seconds, function()
		if generation == self._generation and self._running then
			callback()
		end
	end)
end

function MatchService._announce(self: MatchService)
	local state = self._match:state()
	self._onPhaseChanged({
		phase = self._phase,
		day = state.day,
		endsAt = state.phaseEndsAt,
	})
end

-- The Window: the players plan, trade, chat and vote until the timer ends.
function MatchService._openWindow(self: MatchService)
	local state = self._match:state()
	self._phase = "Window"
	state.phase = "Window"
	local seconds = self._match:ruleSet():windowSeconds()
	state.phaseEndsAt = self._clock() + seconds
	self:_announce()
	self:_after(seconds, function()
		self:_resolve()
	end)
end

-- The Closing Bell: the Day is resolved (GAME_DESIGN 10). The phase is
-- announced, the resolution runs, and the per-Day hash is logged so the
-- match can be replayed headlessly (NETWORKING 9).
function MatchService._resolve(self: MatchService)
	local match = self._match
	local state = match:state()
	self._phase = "Resolve"
	state.phase = "Resolve"
	state.phaseEndsAt = self._clock()
	self:_announce()

	local resolved = match:resolveDay(match:rng())
	print(`[Match] {resolved.id} day {resolved.day} hash {match:hash()}`)

	if resolved.victory ~= nil then
		self._running = false
		self._generation += 1
		print(`[Match] {resolved.id} ended ({resolved.victory.kind})`)
		if self._onMatchEnded ~= nil then
			self._onMatchEnded(resolved.victory)
		end
		return
	end

	self:_openReveal()
end

-- The Reveal: the city shows what happened, then the next Day opens.
function MatchService._openReveal(self: MatchService)
	local state = self._match:state()
	self._phase = "Reveal"
	state.phase = "Reveal"
	local seconds = self._match:ruleSet():revealSeconds()
	state.phaseEndsAt = self._clock() + seconds
	self:_announce()
	self:_after(seconds, function()
		self:_openWindow()
	end)
end

return MatchService
