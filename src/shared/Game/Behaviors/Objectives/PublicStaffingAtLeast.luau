--!strict
-- VP criterion `publicStaffingAtLeast` (GAME_DESIGN 11.1): at least `fraction`
-- of the class's open slots were staffed this Day (State: 0.75). "Public
-- lines" are the State's Clinic and School (6.4, 6.8), and every line the
-- State owns is public — so the criterion sums the class's own lines.
local Objective = require(script.Parent.Objective)

local PublicStaffingAtLeast = setmetatable({}, { __index = Objective })
PublicStaffingAtLeast.__index = PublicStaffingAtLeast

function PublicStaffingAtLeast.award(
	_self: PublicStaffingAtLeast,
	ctx: Objective.ScoreContext
): number
	local assigned = 0
	local open = 0
	for _, line in ctx.state.lines do
		if line.owner == ctx.classId then
			assigned += line.assigned
			open += line.openSlots
		end
	end
	if open <= 0 then
		return 0
	end
	return if assigned / open >= (ctx.params.fraction or 0) then 1 else 0
end

export type PublicStaffingAtLeast = typeof(setmetatable({} :: {}, PublicStaffingAtLeast))

return PublicStaffingAtLeast
