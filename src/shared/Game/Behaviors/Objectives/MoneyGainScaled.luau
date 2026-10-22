--!strict
-- VP criterion `moneyGainScaled` (GAME_DESIGN 11.1): floor(gained / divisor)
-- VP, capped by the objective's own `vp` (Capitalist: 3). The raw award is
-- returned uncapped; Scoring applies both caps so the numbers stay in
-- Config/Objectives.
local Objective = require(script.Parent.Objective)

local MoneyGainScaled = setmetatable({}, { __index = Objective })
MoneyGainScaled.__index = MoneyGainScaled

function MoneyGainScaled.award(_self: MoneyGainScaled, ctx: Objective.ScoreContext): number
	local divisor = ctx.params.divisor or 0
	if divisor <= 0 then
		return 0
	end
	return math.floor(Objective.moneyGained(ctx) / divisor)
end

export type MoneyGainScaled = typeof(setmetatable({} :: {}, MoneyGainScaled))

return MoneyGainScaled
