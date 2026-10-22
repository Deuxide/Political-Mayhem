--!strict
-- VP criterion `ownBillPassed` (GAME_DESIGN 11.1): a bill the class proposed
-- passed this Day. R3 Bills records the passed bills in the scratch channel
-- (D-046) before it clears them from the state.
local Objective = require(script.Parent.Objective)

local OwnBillPassed = setmetatable({}, { __index = Objective })
OwnBillPassed.__index = OwnBillPassed

function OwnBillPassed.award(_self: OwnBillPassed, ctx: Objective.ScoreContext): number
	for _, bill in ctx.day.passedBills do
		if bill.proposer == ctx.classId then
			return 1
		end
	end
	return 0
end

export type OwnBillPassed = typeof(setmetatable({} :: {}, OwnBillPassed))

return OwnBillPassed
