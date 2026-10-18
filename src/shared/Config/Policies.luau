--!strict
-- Policy track configurations.

export type PolicyConfig = {
	id: PolicyId,
	levels: number, -- max level (1-based)
	default: number,
	effect: string, -- description
	enabledOnEasy: boolean,
}

export type PolicyId =
	"Wage"
	| "TaxWorking"
	| "TaxMiddle"
	| "TaxCapitalist"
	| "PublicServices"
	| "Tariff"
	| "StrikeRights"

export type Policies = {
	tracks: { [PolicyId]: PolicyConfig },
	taxRates: { [number]: number }, -- level -> rate (0, 0.1, 0.2, 0.3)
	wageRates: { [number]: number }, -- level -> wage per slot
	publicServicesModes: { [number]: string }, -- 0 = Market, 1 = Universal
	tariffRates: { [number]: number }, -- level -> additional import cost
	strikeRightsModes: { [number]: string }, -- 0 = Outlawed, 1 = Allowed
}

return {
	tracks = {
		Wage = {
			id = "Wage",
			levels = 3,
			default = 2,
			effect = "Wage per staffed slot: Low=1, Medium=2, High=3 Money",
			enabledOnEasy = true,
		},
		TaxWorking = {
			id = "TaxWorking",
			levels = 3,
			default = 1,
			effect = "Tax rate on Working income: 0%, 10%, 20%, 30%",
			enabledOnEasy = false,
		},
		TaxMiddle = {
			id = "TaxMiddle",
			levels = 3,
			default = 1,
			effect = "Tax rate on Middle income: 0%, 10%, 20%, 30%",
			enabledOnEasy = false,
		},
		TaxCapitalist = {
			id = "TaxCapitalist",
			levels = 3,
			default = 1,
			effect = "Tax rate on Capitalist income: 0%, 10%, 20%, 30%",
			enabledOnEasy = true,
		},
		PublicServices = {
			id = "PublicServices",
			levels = 1,
			default = 0,
			effect = "0=Market (State sells stock), 1=Universal (free distribution to unmet needs)",
			enabledOnEasy = true,
		},
		Tariff = {
			id = "Tariff",
			levels = 2,
			default = 0,
			effect = "Additional import cost per unit: level 1=+1, level 2=+2 Money. Revenue to State.",
			enabledOnEasy = false,
		},
		StrikeRights = {
			id = "StrikeRights",
			levels = 1,
			default = 1,
			effect = "0=Outlawed (Working loses 2 Inf, State gains 1 Inf, Stability -1 per strike), 1=Allowed",
			enabledOnEasy = false,
		},
	},
	taxRates = { [0] = 0, [1] = 0.1, [2] = 0.2, [3] = 0.3 },
	wageRates = { [1] = 1, [2] = 2, [3] = 3 },
	publicServicesModes = { [0] = "Market", [1] = "Universal" },
	tariffRates = { [0] = 0, [1] = 1, [2] = 2 },
	strikeRightsModes = { [0] = "Outlawed", [1] = "Allowed" },
}
