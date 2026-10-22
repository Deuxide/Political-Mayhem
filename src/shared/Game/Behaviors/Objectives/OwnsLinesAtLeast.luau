--!strict
-- VP criterion `ownsLinesAtLeast` (GAME_DESIGN 11.1): the class owns at least
-- `count` lines at the end of the Day (Middle: 5).
local Objective = require(script.Parent.Objective)

local OwnsLinesAtLeast = setmetatable({}, { __index = Objective })
OwnsLinesAtLeast.__index = OwnsLinesAtLeast

function OwnsLinesAtLeast.award(_self: OwnsLinesAtLeast, ctx: Objective.ScoreContext): number
	local owned = 0
	for _, line in ctx.state.lines do
		if line.owner == ctx.classId then
			owned += 1
		end
	end
	return if owned >= (ctx.params.count or 0) then 1 else 0
end

export type OwnsLinesAtLeast = typeof(setmetatable({} :: {}, OwnsLinesAtLeast))

return OwnsLinesAtLeast
