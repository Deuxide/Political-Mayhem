--!strict
-- VP criterion `needsMet` (GAME_DESIGN 11.1): every one of the class's daily
-- needs was covered at this Day's Upkeep.
local Objective = require(script.Parent.Objective)

local NeedsMet = setmetatable({}, { __index = Objective })
NeedsMet.__index = NeedsMet

function NeedsMet.award(_self: NeedsMet, ctx: Objective.ScoreContext): number
	local unmet: number = (ctx.day.unmetByClass :: any)[ctx.classId] or 0
	return if unmet == 0 then 1 else 0
end

export type NeedsMet = typeof(setmetatable({} :: {}, NeedsMet))

return NeedsMet
