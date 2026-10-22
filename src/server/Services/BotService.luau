--!strict
-- BotService (M6-T2): the bots that take the seats no human wanted. Only
-- the seat exists here — the bot strategies (what a bot does in a Day) are
-- M9; until then a bot seat simply holds the class.
--
-- Plain data, no Roblox services, so the lobby can be unit-tested.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Seats = require(ReplicatedStorage.Shared.Net.Seats)

type ClassId = Types.ClassId
type Seat = Seats.Seat

local BotService = {}

-- The bot that takes a class nobody else did.
function BotService.seatFor(classId: ClassId): Seat
	return {
		id = `Bot-{classId}`,
		kind = "Bot",
		userId = nil,
		name = `{classId} bot`,
		classId = classId,
		roles = { "Economy", "Politics", "Diplomacy" },
		connected = true,
		ready = true,
	}
end

return BotService
