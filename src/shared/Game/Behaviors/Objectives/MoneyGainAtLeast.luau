--!strict
-- VP criterion `moneyGainAtLeast` (GAME_DESIGN 11.1): the class gained at
-- least `amount` Money this Day. "Gained" is income (Objective.moneyGained),
-- not the net change of the wallet.
local Objective = require(script.Parent.Objective)

local MoneyGainAtLeast = setmetatable({}, { __index = Objective })
MoneyGainAtLeast.__index = MoneyGainAtLeast

function MoneyGainAtLeast.award(_self: MoneyGainAtLeast, ctx: Objective.ScoreContext): number
	return if Objective.moneyGained(ctx) >= (ctx.params.amount or 0) then 1 else 0
end

export type MoneyGainAtLeast = typeof(setmetatable({} :: {}, MoneyGainAtLeast))

return MoneyGainAtLeast
