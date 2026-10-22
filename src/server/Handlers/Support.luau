--!strict
-- The shared parts of every server handler (NETWORKING section 1.2):
-- authenticate -> shape-validate -> state-validate -> apply -> acknowledge.
--
-- A handler never trusts the client for anything that grants authority: the
-- class comes from the sender's seat, the role from that seat, and every
-- amount is checked against the state. A refused action answers with a
-- Notice and changes nothing (and a Notice never carries internal state,
-- NETWORKING 8).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Match = require(ReplicatedStorage.Shared.Game.Match)
local ConfigNetwork = require(ReplicatedStorage.Shared.Config.Network)
local RemoteFactory = require(script.Parent.Parent.Net.RemoteFactory)
local RateLimiter = require(script.Parent.Parent.Net.RateLimiter)
local LobbyService = require(script.Parent.Parent.Services.LobbyService)

type ClassId = Types.ClassId
type LobbyServiceType = LobbyService.LobbyService
type MatchType = Match.Match
type RemoteSet = RemoteFactory.RemoteSet
type Role = Types.Role

-- What every handler needs: the remotes, the lobby (the seats and the
-- running match), the players, the clock and the chat filter.
export type Support = {
	remotes: RemoteSet,
	lobby: LobbyServiceType,
	players: () -> { any },
	clock: () -> number, -- epoch milliseconds
	filter: (text: string, fromUserId: number) -> (string?, string?),
	limiters: { [string]: RateLimiter.RateLimiter? },
	muted: { [number]: boolean },
}

local Support = {}

function Support.new(
	remotes: RemoteSet,
	lobby: LobbyServiceType,
	players: () -> { any },
	clock: () -> number,
	filter: (text: string, fromUserId: number) -> (string?, string?)
): Support
	local limiters: { [string]: RateLimiter.RateLimiter? } = {}
	for name, limit in ConfigNetwork.rateLimits do
		limiters[name] = RateLimiter.new(limit.limit, limit.periodSeconds, clock)
	end
	return {
		remotes = remotes,
		lobby = lobby,
		players = players,
		clock = clock,
		filter = filter,
		limiters = limiters,
		muted = {},
	}
end

-- The class of the sender, from its seat (NETWORKING 2). The client never
-- says which class it is.
function Support.classOf(support: Support, player: any): ClassId?
	local seat = support.lobby:seatOf(player.UserId)
	if seat == nil then
		return nil
	end
	-- luau-lsp loses the union through the module boundary, so the value
	-- travels through `any` (the same trick the game code uses)
	local classId: ClassId? = seat.classId :: any
	return classId
end

-- The roles of the sender's seat (GAME_DESIGN 14).
function Support.rolesOf(support: Support, player: any): { Role }
	local seat = support.lobby:seatOf(player.UserId)
	if seat == nil then
		return {}
	end
	return seat.roles
end

function Support.hasRole(support: Support, player: any, role: Role): boolean
	for _, held in Support.rolesOf(support, player) do
		if held == role then
			return true
		end
	end
	return false
end

-- The running match, or nil when the lobby has not started one.
function Support.match(support: Support): MatchType?
	return support.lobby:match()
end

function Support.notice(
	support: Support,
	player: any,
	code: string,
	message: string,
	requestId: string?
)
	support.remotes.Notice:FireClient(player, {
		code = code,
		message = message,
		requestId = requestId,
	})
end

-- The rate limit of a remote: over the limit, the packet is dropped with a
-- notice (NETWORKING 3.1).
function Support.rateLimited(support: Support, name: string, player: any): boolean
	local limiter = support.limiters[name]
	if limiter == nil then
		return false
	end
	if limiter:allow(tostring(player.UserId)) then
		return false
	end
	Support.notice(support, player, "RateLimited", `too many {name} messages`)
	return true
end

-- The sender must have a seat and a class; a client that never joined gets
-- nothing.
function Support.authenticated(support: Support, player: any): ClassId?
	local classId: ClassId? = Support.classOf(support, player) :: any
	if classId == nil then
		Support.notice(support, player, "NotSeated", "you are not in this match")
		return nil
	end
	return classId
end

-- Only the Window accepts live actions (NETWORKING 5).
function Support.inWindow(support: Support, player: any): MatchType?
	local match = Support.match(support)
	if match == nil then
		Support.notice(support, player, "NoMatch", "there is no match running")
		return nil
	end
	if match:state().phase ~= "Window" then
		Support.notice(support, player, "WindowClosed", "the window is closed")
		return nil
	end
	return match
end

-- A payload may only carry the keys the remote defines (NETWORKING 7).
function Support.hasOnlyKeys(payload: any, allowed: { string }): boolean
	for key in payload do
		local known = false
		for _, name in allowed do
			if key == name then
				known = true
				break
			end
		end
		if not known then
			return false
		end
	end
	return true
end

-- Whether two values are the same, so a field the sender may not edit can
-- be compared with the stored one (NETWORKING 3.1).
function Support.sameValue(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in a do
		if not Support.sameValue(value, (b :: any)[key]) then
			return false
		end
	end
	for key in b do
		if (a :: any)[key] == nil then
			return false
		end
	end
	return true
end

-- Sends a patch to every member of a class (NETWORKING 3.2).
function Support.patch(support: Support, classId: ClassId, path: string, value: any)
	for _, member in Support.membersOf(support, classId) do
		support.remotes.View_Patch:FireClient(member, {
			ops = { { op = "set", path = path, value = value } },
			serverTime = support.clock(),
		})
	end
end

-- The members of a class (the team), for the messages a class hears.
function Support.membersOf(support: Support, classId: ClassId): { any }
	local members: { any } = {}
	for _, player in support.players() do
		if Support.classOf(support, player) == classId then
			table.insert(members, player)
		end
	end
	return members
end

return Support
