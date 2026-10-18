--!strict
-- Match service: phase scheduler, server clock, per-Day state hash logging.

export type MatchService = {
	init: () -> (),
}

local MatchService = {}

function MatchService.init()
	-- TODO: Implement match service (M6-T3)
	print("MatchService initialized")
end

return MatchService
