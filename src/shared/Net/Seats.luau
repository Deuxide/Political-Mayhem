--!strict
-- The seat record of NETWORKING section 6 and the role split of GAME_DESIGN
-- section 14. Plain data: the server owns the registry, the client shows the
-- same shape in the lobby.

local Types = require(script.Parent.Parent.Game.Types)

export type ClassId = Types.ClassId
export type Role = Types.Role
export type SeatId = Types.SeatId

-- One seat on a class. A human seat has no class until the player picks
-- one; a bot seat always knows its class.
export type Seat = {
	id: SeatId,
	kind: "Human" | "Bot",
	userId: number?, -- humans only (a UserId)
	name: string,
	classId: Types.ClassId?, -- nil until a human chooses
	roles: { Role },
	connected: boolean,
	ready: boolean,
}

local Seats = {}

-- The roles of the members of a class, in join order (GAME_DESIGN section
-- 14): one member holds every role, two split them (Economy + Diplomacy,
-- Politics), three hold one each, and further members are advisors.
function Seats.rolesFor(memberCount: number): { { Role } }
	if memberCount <= 1 then
		return { { "Economy", "Politics", "Diplomacy" } :: { Role } }
	end
	if memberCount == 2 then
		return {
			{ "Economy", "Diplomacy" } :: { Role },
			{ "Politics" } :: { Role },
		}
	end
	local roles: { { Role } } = {
		{ "Economy" } :: { Role },
		{ "Politics" } :: { Role },
		{ "Diplomacy" } :: { Role },
	}
	for _ = 4, memberCount do
		table.insert(roles, { "Advisor" } :: { Role })
	end
	return roles
end

return Seats
