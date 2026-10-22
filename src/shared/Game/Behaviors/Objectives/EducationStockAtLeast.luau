--!strict
-- VP criterion `educationStockAtLeast` (GAME_DESIGN 11.1): the class's
-- Education stock after this Day's Upkeep is at least `amount` (Middle: 2).
-- R12 runs after R9, so the stock already paid for the Day's needs.
local Objective = require(script.Parent.Objective)

local EducationStockAtLeast = setmetatable({}, { __index = Objective })
EducationStockAtLeast.__index = EducationStockAtLeast

function EducationStockAtLeast.award(
	_self: EducationStockAtLeast,
	ctx: Objective.ScoreContext
): number
	local education: number = (ctx.state.classes[ctx.classId].stock :: any)["education"] or 0
	return if education >= (ctx.params.amount or 0) then 1 else 0
end

export type EducationStockAtLeast = typeof(setmetatable({} :: {}, EducationStockAtLeast))

return EducationStockAtLeast
