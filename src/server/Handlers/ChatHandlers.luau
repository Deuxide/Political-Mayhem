--!strict
-- The chat remote (NETWORKING section 3.1): Chat_Send. Player text is
-- filtered by Roblox's own text service before anybody sees it (D-025);
-- the filter is injected, so the handler can be tested without the engine.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Validate = require(ReplicatedStorage.Shared.Net.Validate)
local ConfigNetwork = require(ReplicatedStorage.Shared.Config.Network)
local Support = require(script.Parent.Support)

type ClassId = Types.ClassId
type SupportType = Support.Support

local ChatHandlers = {}

function ChatHandlers.connect(support: SupportType)
	support.remotes.Chat_Send.OnServerEvent:Connect(function(player: any, payload: any)
		if Support.rateLimited(support, "Chat_Send", player) then
			return
		end
		if
			type(payload) ~= "table"
			or not Support.hasOnlyKeys(payload, { "channel", "classTo", "text" })
		then
			Support.notice(
				support,
				player,
				"InvalidPayload",
				"Chat_Send needs a channel and a text."
			)
			return
		end
		local channel = payload.channel
		if channel ~= "Global" and channel ~= "Team" and channel ~= "Class" then
			Support.notice(support, player, "InvalidPayload", "there is no such chat channel.")
			return
		end
		if not Validate.isShortString(payload.text, ConfigNetwork.maxChatLength) then
			Support.notice(support, player, "InvalidPayload", "the message is empty or too long.")
			return
		end
		if channel == "Class" and not Validate.isClassId(payload.classTo) then
			Support.notice(support, player, "InvalidPayload", "the message needs a class to go to.")
			return
		end

		local classId: ClassId? = Support.authenticated(support, player) :: any
		if classId == nil then
			return
		end
		if support.muted[player.UserId] then
			Support.notice(support, player, "Muted", "you may not chat right now.")
			return
		end

		-- The text is filtered before it goes anywhere (D-025). The filter
		-- returns nil when the text may not be sent.
		local filtered, reason = support.filter(payload.text, player.UserId)
		if filtered == nil then
			Support.notice(support, player, "Filtered", reason or "that message may not be sent.")
			return
		end

		-- The audience: everybody, the sender's own class, or one class. A
		-- private Class line also reaches the sender, or they would never
		-- see what they sent (D-079).
		local audience: { any } = {}
		if channel == "Global" then
			audience = support.players()
		elseif channel == "Team" then
			audience = Support.membersOf(support, classId)
		else
			local classTo: ClassId = payload.classTo :: any
			audience = Support.membersOf(support, classTo)
			local senderHeard = false
			for _, member in audience do
				if member == player then
					senderHeard = true
					break
				end
			end
			if not senderHeard then
				table.insert(audience, player)
			end
		end

		local message = {
			channel = channel,
			fromClass = classId,
			fromName = player.Name,
			text = filtered,
			t = support.clock(),
		}
		for _, receiver in audience do
			support.remotes.Chat_Message:FireClient(receiver, message)
		end
	end)
end

return ChatHandlers
