--!strict
-- VP criterion `wageAtLeast` (GAME_DESIGN 11.1): the Wage policy level is at
-- least `level` (Working: Medium = 2) at the end of the Day.
local Objective = require(script.Parent.Objective)

local WageAtLeast = setmetatable({}, { __index = Objective })
WageAtLeast.__index = WageAtLeast

function WageAtLeast.award(_self: WageAtLeast, ctx: Objective.ScoreContext): number
	local level = Objective.policyLevel(ctx.state, "Wage")
	return if level >= (ctx.params.level or 0) then 1 else 0
end

export type WageAtLeast = typeof(setmetatable({} :: {}, WageAtLeast))

return WageAtLeast
