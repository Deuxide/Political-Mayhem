--!strict
-- VP criterion `moneyNotDecreasing` (GAME_DESIGN 11.1): the State's Money is
-- non-negative and did not fall during the Day. R1 records the start-of-Day
-- wallet in the scratch channel (D-046); the comparison is against that.
local Objective = require(script.Parent.Objective)

local MoneyNotDecreasing = setmetatable({}, { __index = Objective })
MoneyNotDecreasing.__index = MoneyNotDecreasing

function MoneyNotDecreasing.award(_self: MoneyNotDecreasing, ctx: Objective.ScoreContext): number
	local money = ctx.state.classes[ctx.classId].money
	local start: number = (ctx.day.startMoney :: any)[ctx.classId] or money
	return if money >= 0 and money >= start then 1 else 0
end

export type MoneyNotDecreasing = typeof(setmetatable({} :: {}, MoneyNotDecreasing))

return MoneyNotDecreasing
