--!strict
-- Random event configurations (V2, milestone M12).

export type EventConfig = {
	id: string,
	kind: "HarvestFailure" | "ExportBoom" | "Pandemic" | "Recession" | "EducationGrant" | "Scandal",
	weight: number, -- relative probability
	minDay: number,
	maxDay: number?,
	effect: string, -- description
	apply: (state: any, rng: any) -> (), -- mutation function
	forecastable: boolean, -- shown on Hard
}

export type Events = {
	enabled: boolean,
	interval: number, -- schedule one every N days starting from minDay
	startDay: number,
	events: { EventConfig },
}

return {
	enabled = false, -- V2 feature, disabled until M12
	interval = 3,
	startDay = 3,
	events = {
		{
			id = "HarvestFailure",
			kind = "HarvestFailure",
			weight = 1,
			minDay = 3,
			effect = "Farm output halved for one day",
			apply = function(state: any, rng: any)
				-- Halve farm output for all classes
				for _, line in pairs(state.lines) do
					if line.type == "Farm" then line._eventOutputMultiplier = 0.5 end
				end
			end,
			forecastable = true,
		},
		{
			id = "ExportBoom",
			kind = "ExportBoom",
			weight = 1,
			minDay = 3,
			effect = "Goods export price +2 for one day",
			apply = function(state: any, rng: any) state._eventExportBonus = { Goods = 2 } end,
			forecastable = true,
		},
		{
			id = "Pandemic",
			kind = "Pandemic",
			weight = 1,
			minDay = 3,
			effect = "Health needs doubled for one day",
			apply = function(state: any, rng: any) state._eventHealthNeedsMultiplier = 2 end,
			forecastable = true,
		},
		{
			id = "Recession",
			kind = "Recession",
			weight = 1,
			minDay = 3,
			effect = "All export prices -1 (min 1) for one day",
			apply = function(state: any, rng: any) state._eventExportPricePenalty = 1 end,
			forecastable = true,
		},
		{
			id = "EducationGrant",
			kind = "EducationGrant",
			weight = 1,
			minDay = 3,
			effect = "State gains 4 Education",
			apply = function(state: any, rng: any)
				state.classes.State.stock.education += 4
			end,
			forecastable = true,
		},
		{
			id = "Scandal",
			kind = "Scandal",
			weight = 1,
			minDay = 3,
			effect = "Random class loses 2 Influence, Stability -5",
			apply = function(state: any, rng: any)
				local classes = { "Working", "Middle", "Capitalist", "State" }
				local target = classes[rng:int(1, 4)]
				state.classes[target].influence = math.max(0, state.classes[target].influence - 2)
				state.stability = math.max(0, state.stability - 5)
				table.insert(state.eventLog, {
					day = state.day,
					step = "Events",
					class = target,
					message = "Scandal! " .. target .. " loses 2 Influence, Stability -5",
					data = {},
				})
			end,
			forecastable = true,
		},
	},
}
