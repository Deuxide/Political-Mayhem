--!strict
-- VP criterion `employmentAtLeast` (GAME_DESIGN 11.1): the Working's
-- employment is at least `fraction` of its workers this Day. The staffed
-- slot count comes from R5 Production through the scratch channel (D-046).
local Objective = require(script.Parent.Objective)

local EmploymentAtLeast = setmetatable({}, { __index = Objective })
EmploymentAtLeast.__index = EmploymentAtLeast

function EmploymentAtLeast.award(_self: EmploymentAtLeast, ctx: Objective.ScoreContext): number
	local workers = ctx.state.classes[ctx.classId].workers
	if workers <= 0 then
		return 0
	end
	local fraction = ctx.params.fraction or 0
	local employed = ctx.day.employedWorkers
	return if employed / workers >= fraction then 1 else 0
end

export type EmploymentAtLeast = typeof(setmetatable({} :: {}, EmploymentAtLeast))

return EmploymentAtLeast
