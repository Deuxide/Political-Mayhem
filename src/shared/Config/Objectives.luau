--!strict
-- Victory objective configurations (VP criteria per class per day).

export type ObjectiveConfig = {
	id: string,
	class: "Working" | "Middle" | "Capitalist" | "State",
	description: string,
	check: (state: any, classState: any, classId: string, ctx: any) -> boolean,
}

export type Objectives = {
	Working: { ObjectiveConfig },
	Middle: { ObjectiveConfig },
	Capitalist: { ObjectiveConfig },
	State: { ObjectiveConfig },
	maxPerClassPerDay: number,
}

-- Note: Actual predicate functions are in Game/Steps/Scoring.luau
-- These configs define the criteria for reference and data-driven checks

return {
	Working = {
		{ id = "NeedsMet", class = "Working", description = "All needs met (Food, Health)" },
		{ id = "Employment75", class = "Working", description = "Employment >= 75% of workers" },
		{ id = "WageMedium", class = "Working", description = "Wage level >= Medium (level 2)" },
		{
			id = "ProposedBillPassed",
			class = "Working",
			description = "A bill Working proposed passed this day",
		},
	},
	Middle = {
		{
			id = "EducationStock2",
			class = "Middle",
			description = "Education stock after upkeep >= 2",
		},
		{ id = "MoneyGained5", class = "Middle", description = "Money gained this day >= 5" },
		{ id = "Owns5Lines", class = "Middle", description = "Owns >= 5 lines" },
		{ id = "NeedsMet", class = "Middle", description = "All needs met" },
	},
	Capitalist = {
		{
			id = "MoneyGained",
			class = "Capitalist",
			description = "min(3, floor(Money gained / 8)) VP",
		},
		{
			id = "TaxCapitalistLow",
			class = "Capitalist",
			description = "TaxCapitalist <= 1 at end of day",
		},
	},
	State = {
		{
			id = "MoneyNonNegative",
			class = "State",
			description = "Money >= 0 and not decreasing this day",
		},
		{ id = "Stability60", class = "State", description = "Stability >= 60" },
		{ id = "Stability80", class = "State", description = "Stability >= 80" },
		{
			id = "PublicLinesStaffed75",
			class = "State",
			description = "Public lines >= 75% of open slots staffed",
		},
	},
	maxPerClassPerDay = 4,
}
