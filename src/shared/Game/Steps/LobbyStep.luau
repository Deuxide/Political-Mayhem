--!strict
-- R2 Lobby (GAME_DESIGN 7.1, section 10): the class that set a lobby
-- request in its draft buys Influence with Money, validated against the
-- current stock:
--   - only Capitalist and Middle may lobby (Config/Classes.lobby),
--   - the request may not exceed the class's per-Day lobby cap,
--   - the class must have the Money for it,
--   - the Influence may not push the class past the shared Influence cap.
-- An invalid request is skipped with a log entry; nothing is paid when the
-- request is refused. The Influence income itself is R10's business.

local Types = require(script.Parent.Parent.Types)
local Step = require(script.Parent.Step)
local StateOps = require(script.Parent.Parent.State.StateOps)
local ConfigClasses = require(script.Parent.Parent.Parent.Config.Classes)

type ClassId = Types.ClassId
type LogEntry = Types.LogEntry
type MatchState = Types.MatchState
type StepContext = Step.StepContext

local function log(state: MatchState, entry: LogEntry)
	table.insert(state.eventLog, entry)
end

local LobbyStep = setmetatable({}, { __index = Step })
LobbyStep.__index = LobbyStep

function LobbyStep.new(): LobbyStep
	return setmetatable({}, LobbyStep)
end

export type LobbyStep = typeof(setmetatable({} :: {}, LobbyStep))

function LobbyStep.run(_self: LobbyStep, state: MatchState, _ctx: StepContext)
	for ci = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[ci] :: any
		local lobby = state.drafts[classId].lobby
		if lobby ~= nil and lobby.amount > 0 then
			local entry = ConfigClasses.entries[classId] :: ConfigClasses.ClassEntry
			local lobbyConfig = entry.lobby

			if lobbyConfig == nil then
				log(state, {
					day = state.day,
					text = `{classId} lobby skipped: {classId} cannot lobby`,
					actor = classId,
				})
			elseif lobby.amount > lobbyConfig.maxInfluence then
				log(state, {
					day = state.day,
					text = `{classId} lobby skipped: at most {lobbyConfig.maxInfluence} Influence per Day`,
					actor = classId,
				})
			elseif state.classes[classId].influence + lobby.amount > ConfigClasses.influenceCap then
				log(state, {
					day = state.day,
					text = `{classId} lobby skipped: the Influence cap of {ConfigClasses.influenceCap} would be passed`,
					actor = classId,
				})
			else
				local cost = lobby.amount * lobbyConfig.moneyPerInfluence
				if StateOps.subtractResource(state, classId, "Money", cost) then
					StateOps.addResource(state, classId, "Influence", lobby.amount)
					log(state, {
						day = state.day,
						text = `{classId} bought {lobby.amount} Influence for {cost} Money`,
						actor = classId,
					})
				else
					log(state, {
						day = state.day,
						text = `{classId} lobby skipped: cannot afford {cost} Money`,
						actor = classId,
					})
				end
			end
		end
	end
end

return LobbyStep
