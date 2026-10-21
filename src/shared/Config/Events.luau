--!strict
-- Random-event registry (GAME_DESIGN 16). Scheduling, forecast behavior, and
-- the Scandal class choice are V2 mechanics (M12) running through the
-- difficulty's eventsEnabled gate; this table is the roadmap's Config-scope
-- data for them, ids are stable strings. Pure data.
local Types = require(script.Parent.Parent.Game.Types)

type EventId = Types.EventId

export type EventSpec = {
	name: string,
	effect: string, -- one-line description from GAME_DESIGN 16 (executed in M12)
}

export type ScheduleConfig = {
	everyDays: number, -- one event every N Days...
	startDay: number, -- ...starting at this Day (inclusive)
}

export type EventsConfig = {
	schedule: ScheduleConfig,
	specs: {
		[EventId]: EventSpec,
	},
}

return table.freeze({
	schedule = {
		everyDays = 3,
		startDay = 3,
	} :: ScheduleConfig,

	specs = {
		HarvestFailure = { name = "Harvest Failure", effect = "Farm output halved" } :: EventSpec,
		ExportBoom = { name = "Export Boom", effect = "Goods export price +2" } :: EventSpec,
		Pandemic = { name = "Pandemic", effect = "Health needs doubled" } :: EventSpec,
		Recession = { name = "Recession", effect = "All export prices -1 (min 1)" } :: EventSpec,
		EducationGrant = { name = "Education Grant", effect = "State gains 4 Education" } :: EventSpec,
		Scandal = {
			name = "Scandal",
			effect = "Random class (via RNG) loses 2 Influence, Stability -5",
		} :: EventSpec,
	} :: {
		[EventId]: EventSpec,
	},
} :: EventsConfig)
