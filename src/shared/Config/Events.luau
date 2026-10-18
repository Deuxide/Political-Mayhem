--!strict
-- Random event configurations (V2, M12).

export type Events = {
	enabled: boolean,
	events: { [string]: EventConfig },
}

export type EventConfig = {
	weight: number,
	minRound: number,
	maxRound: number?,
	affectedClasses: { string },
	effect: { [string]: any },
}

return {
	enabled = false, -- Disabled until M12
	events = {},
}
