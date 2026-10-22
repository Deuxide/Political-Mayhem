--!strict
-- LobbyService (M6-T2): the pre-match lobby. Pure data — no Roblox services —
-- so the whole flow is unit-testable; the PlayerAdded listener and the
-- remote handlers live outside (server/Handlers/LobbyHandlers.luau).
--
-- The flow (NETWORKING section 3.1 and 6): a player joins, picks a class that
-- still has a free human seat, says whether they are ready, and the host
-- starts the match. Every class no human took is filled with a bot (the bot
-- strategies arrive with M9).
--
-- The lobby is the server's: the client never tells the server what class it
-- is or that the match may start, it only asks (NETWORKING 2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Seats = require(ReplicatedStorage.Shared.Net.Seats)
local StateFactory = require(ReplicatedStorage.Shared.Game.State.StateFactory)
local RuleSet = require(ReplicatedStorage.Shared.Game.RuleSet)
local Rng = require(ReplicatedStorage.Shared.Game.Rng)
local Match = require(ReplicatedStorage.Shared.Game.Match)
local Signal = require(ReplicatedStorage.Shared.Game.Signal)
local ConfigDifficulty = require(ReplicatedStorage.Shared.Config.Difficulty)
local BotService = require(script.Parent.BotService)

type ClassId = Types.ClassId
type Difficulty = Types.Difficulty
type MatchType = Match.Match
type Seat = Seats.Seat
type SeatId = Types.SeatId
type SeatMap = StateFactory.SeatMap

local LobbyService = {}
LobbyService.__index = LobbyService

export type LobbyService = typeof(setmetatable({
	_seats = {} :: { [SeatId]: Seat },
	_order = {} :: { SeatId },
	_host = nil :: SeatId?,
	_started = false,
	_match = nil :: MatchType?,
	_difficulty = ConfigDifficulty.defaultDifficulty :: Difficulty,
	_seed = 0 :: number,
	_startedSignal = Signal.new() :: Signal.Signal,
}, LobbyService))

-- The seed is the server's (the lobby configures the difficulty, not the
-- seed); the match logs it so a match can be replayed (NETWORKING 9).
function LobbyService.new(seed: number): LobbyService
	return setmetatable({
		_seats = {},
		_order = {},
		_host = nil,
		_started = false,
		_match = nil,
		_difficulty = ConfigDifficulty.defaultDifficulty,
		_seed = seed,
		_startedSignal = Signal.new(),
	}, LobbyService)
end

-- Fired with the new match when the host starts it.
function LobbyService.onStart(self: LobbyService, handler: (...any) -> ()): () -> ()
	return self._startedSignal:connect(handler)
end

-- A player joins: a seat is created for them, and the first joiner hosts.
function LobbyService.join(self: LobbyService, userId: number, name: string): Seat
	local existing = self:seatOf(userId)
	if existing ~= nil then
		return existing
	end
	local seat: Seat = {
		id = `Seat-{userId}`,
		kind = "Human",
		userId = userId,
		name = name,
		classId = nil,
		roles = { "Economy", "Politics", "Diplomacy" },
		connected = true,
		ready = false,
		botControlled = false,
	}
	self._seats[seat.id] = seat
	table.insert(self._order, seat.id)
	if self._host == nil then
		self._host = seat.id
	end
	self:_refreshRoles()
	return seat
end

-- The player left: the seat stays, but nobody controls the class until the
-- player comes back or a bot takes over (NETWORKING 6).
function LobbyService.disconnect(self: LobbyService, userId: number): boolean
	local seat = self:seatOf(userId)
	if seat == nil then
		return false
	end
	seat.connected = false
	return true
end

-- The player came back: the seat controls its class again.
function LobbyService.reconnect(self: LobbyService, userId: number): boolean
	local seat = self:seatOf(userId)
	if seat == nil then
		return false
	end
	seat.connected = true
	seat.botControlled = false
	return true
end

-- A bot takes over the class of a player who did not come back in time.
-- The takeover only happens once, and only while the player is away.
function LobbyService.takeover(self: LobbyService, userId: number): boolean
	local seat = self:seatOf(userId)
	if seat == nil then
		return false
	end
	if seat.connected or seat.botControlled then
		return false
	end
	seat.botControlled = true
	return true
end

function LobbyService.seatOf(self: LobbyService, userId: number): Seat?
	for _, seatId in self._order do
		local seat = self._seats[seatId]
		if seat.userId == userId then
			return seat
		end
	end
	return nil
end

function LobbyService.seats(self: LobbyService): { Seat }
	local list: { Seat } = {}
	for _, seatId in self._order do
		table.insert(list, self._seats[seatId])
	end
	return list
end

function LobbyService.isHost(self: LobbyService, userId: number): boolean
	local seat = self:seatOf(userId)
	return seat ~= nil and self._host == seat.id
end

function LobbyService.started(self: LobbyService): boolean
	return self._started
end

function LobbyService.match(self: LobbyService): MatchType?
	return self._match
end

function LobbyService.difficulty(self: LobbyService): Difficulty
	return self._difficulty
end

-- A class is free while no human seat holds it.
function LobbyService._classIsFree(
	self: LobbyService,
	classId: ClassId,
	exceptSeatId: SeatId
): boolean
	for _, seatId in self._order do
		local seat = self._seats[seatId]
		if seat.kind == "Human" and seat.id ~= exceptSeatId and seat.classId == classId then
			return false
		end
	end
	return true
end

-- The player picks (or changes) their class.
function LobbyService.setClass(
	self: LobbyService,
	userId: number,
	classId: ClassId
): (boolean, string)
	local seat = self:seatOf(userId)
	if seat == nil then
		return false, "you are not in the lobby"
	end
	if self._started then
		return false, "the match has already started"
	end
	if not self:_classIsFree(classId, seat.id) then
		return false, `{classId} already has a human player`
	end
	seat.classId = classId
	self:_refreshRoles()
	return true, ""
end

function LobbyService.setReady(
	self: LobbyService,
	userId: number,
	ready: boolean
): (boolean, string)
	local seat = self:seatOf(userId)
	if seat == nil then
		return false, "you are not in the lobby"
	end
	if self._started then
		return false, "the match has already started"
	end
	seat.ready = ready
	return true, ""
end

-- Only the host sets the difficulty, and only before the match starts.
function LobbyService.configure(
	self: LobbyService,
	userId: number,
	difficulty: Difficulty
): (boolean, string)
	if not self:isHost(userId) then
		return false, "only the host can configure the match"
	end
	if self._started then
		return false, "the match has already started"
	end
	self._difficulty = difficulty
	return true, ""
end

-- The host starts the match: every human has a class and is ready, and the
-- classes nobody took get a bot.
function LobbyService.start(self: LobbyService, userId: number): (MatchType?, string)
	if not self:isHost(userId) then
		return nil, "only the host can start the match"
	end
	if self._started then
		return nil, "the match has already started"
	end

	local humans = 0
	for _, seatId in self._order do
		local seat = self._seats[seatId]
		if seat.kind == "Human" then
			humans += 1
			if seat.classId == nil then
				return nil, `{seat.name} has not chosen a class`
			end
			if not seat.ready then
				return nil, `{seat.name} is not ready`
			end
		end
	end
	if humans == 0 then
		return nil, "no human player in the lobby"
	end

	-- the bots fill the classes no human took
	local taken: { [ClassId]: boolean } = {}
	for _, seatId in self._order do
		local seat = self._seats[seatId]
		local classId: ClassId? = seat.classId
		if classId ~= nil then
			taken[classId] = true
		end
	end
	for index = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[index] :: any
		if not taken[classId] then
			local bot = BotService.seatFor(classId)
			self._seats[bot.id] = bot
			table.insert(self._order, bot.id)
			taken[classId] = true
		end
	end

	local state = StateFactory.create(self._difficulty, self:seatMap(), self._seed)
	local match = Match.new(state, RuleSet.new(self._difficulty), Rng.new(self._seed))
	self._match = match
	self._started = true
	self._startedSignal:fire(match)
	return match, ""
end

-- The seat map the match is built from: the humans of a class first, then
-- its bot.
function LobbyService.seatMap(self: LobbyService): SeatMap
	local map: SeatMap = {}
	for index = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[index] :: any
		map[classId] = {}
	end
	for _, seatId in self._order do
		local seat = self._seats[seatId]
		local classId: ClassId? = seat.classId
		if classId ~= nil then
			table.insert(map[classId], seat.id)
		end
	end
	return map
end

-- The roles of the human members of a class follow GAME_DESIGN section 14;
-- a bot holds every role of its class.
function LobbyService._refreshRoles(self: LobbyService)
	local humans: { [ClassId]: { Seat } } = {}
	for index = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[index] :: any
		humans[classId] = {}
	end
	for _, seatId in self._order do
		local seat = self._seats[seatId]
		local classId: ClassId? = seat.classId
		if classId ~= nil and seat.kind == "Human" then
			table.insert(humans[classId], seat)
		end
	end
	for index = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[index] :: any
		local list = humans[classId]
		local roleSets = Seats.rolesFor(#list)
		for memberIndex, seat in list do
			seat.roles = roleSets[memberIndex]
		end
	end
end

return LobbyService
