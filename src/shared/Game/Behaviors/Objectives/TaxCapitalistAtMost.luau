--!strict
-- VP criterion `taxCapitalistAtMost` (GAME_DESIGN 11.1): the TaxCapitalist
-- track ended the Day at `level` or lower (Capitalist: 1). A track the
-- difficulty disabled is absent and reads as 0 (D-041), so it passes.
local Objective = require(script.Parent.Objective)

local TaxCapitalistAtMost = setmetatable({}, { __index = Objective })
TaxCapitalistAtMost.__index = TaxCapitalistAtMost

function TaxCapitalistAtMost.award(_self: TaxCapitalistAtMost, ctx: Objective.ScoreContext): number
	local level = Objective.policyLevel(ctx.state, "TaxCapitalist")
	return if level <= (ctx.params.level or 0) then 1 else 0
end

export type TaxCapitalistAtMost = typeof(setmetatable({} :: {}, TaxCapitalistAtMost))

return TaxCapitalistAtMost
