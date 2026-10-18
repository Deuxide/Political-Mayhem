--!strict
-- Production line configurations.

export type LineConfig = {
	id: string,
	type: "Farm" | "Factory" | "Clinic" | "School",
	buildCost: { [string]: number },
	outputPerSlot: number,
	wagePerSlot: number,
	upkeepCost: { [string]: number },
	maxSlots: number,
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
		buildCost = { Money = 10, Goods = 2 },
		outputPerSlot = 2,
		wagePerSlot = 1,
		upkeepCost = { Money = 1 },
		maxSlots = 5,
	},
	Factory = {
		id = "Factory",
		type = "Factory",
		buildCost = { Money = 15, Goods = 5, Education = 1 },
		outputPerSlot = 3,
		wagePerSlot = 2,
		upkeepCost = { Money = 2, Goods = 1 },
		maxSlots = 5,
	},
	Clinic = {
		id = "Clinic",
		type = "Clinic",
		buildCost = { Money = 12, Goods = 3, Health = 2 },
		outputPerSlot = 2,
		wagePerSlot = 2,
		upkeepCost = { Money = 2, Health = 1 },
		maxSlots = 5,
	},
	School = {
		id = "School",
		type = "School",
		buildCost = { Money = 10, Goods = 2, Education = 2 },
		outputPerSlot = 1,
		wagePerSlot = 1,
		upkeepCost = { Money = 1, Education = 1 },
		maxSlots = 5,
	},
}
