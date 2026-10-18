--!strict
-- Production line configurations.

export type LineConfig = {
	id: string,
	type: "Farm" | "Factory" | "Clinic" | "School",
	buildCost: { [string]: number },
	outputPerSlot: number,
	slotsMax: number,
	input: { [string]: number }?, -- per operating line
	eligibleOwners: { string },
}

export type Lines = {
	Farm: LineConfig,
	Factory: LineConfig,
	Clinic: LineConfig,
	School: LineConfig,
}

return {
	Farm = {
		id = "Farm",
		type = "Farm",
		buildCost = { Money = 12 },
		outputPerSlot = 2,
		slotsMax = 2,
		input = {},
		eligibleOwners = { "Middle", "Capitalist" },
	},
	Factory = {
		id = "Factory",
		type = "Factory",
		buildCost = { Money = 20 },
		outputPerSlot = 2,
		slotsMax = 2,
		input = { Education = 1 }, -- per operating line
		eligibleOwners = { "Capitalist" },
	},
	Clinic = {
		id = "Clinic",
		type = "Clinic",
		buildCost = { Money = 15 },
		outputPerSlot = 1,
		slotsMax = 2,
		input = {},
		eligibleOwners = { "Middle", "State" },
	},
	School = {
		id = "School",
		type = "School",
		buildCost = { Money = 15 },
		outputPerSlot = 1,
		slotsMax = 2,
		input = {},
		eligibleOwners = { "Middle", "State" },
	},
}
