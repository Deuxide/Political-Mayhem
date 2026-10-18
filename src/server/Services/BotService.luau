--!strict
-- Bot service: fills empty seats with bot strategies.

export type BotService = {
	init: () -> (),
}

local BotService = {}

function BotService.init()
	-- TODO: Implement bot service (M9)
	print("BotService initialized")
end

return BotService
