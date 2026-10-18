--!strict
-- Team service: manages teams (1-N players per class), role gating.

export type TeamService = {
	init: () -> (),
}

local TeamService = {}

function TeamService.init()
	-- TODO: Implement team logic (M12-T1)
	print("TeamService initialized")
end

return TeamService
