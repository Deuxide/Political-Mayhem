--!strict
-- VP criterion `stabilityAtLeast` (GAME_DESIGN 11.1): Stability ended the Day
-- at `level` or higher. Config lists it twice for the State (60 then 80), so
-- a calm world pays both tiers.
local Objective = require(script.Parent.Objective)

local StabilityAtLeast = setmetatable({}, { __index = Objective })
StabilityAtLeast.__index = StabilityAtLeast

function StabilityAtLeast.award(_self: StabilityAtLeast, ctx: Objective.ScoreContext): number
	return if ctx.state.stability >= (ctx.params.level or 0) then 1 else 0
end

export type StabilityAtLeast = typeof(setmetatable({} :: {}, StabilityAtLeast))

return StabilityAtLeast
