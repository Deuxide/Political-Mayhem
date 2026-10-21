--!strict
-- Per-class statics (GAME_DESIGN 5.1/5.2, 7.1, 7.3): starting values (taken
-- before difficulty multipliers are applied), initial line ownership, base
-- votes, per-Day Influence income, build permissions, and lobby economics.
-- Needs live in Config/Needs; line production data in Config/Lines. Pure data.
local Types = require(script.Parent.Parent.Game.Types)

type ClassId = Types.ClassId
type StockId = Types.StockId
type LineType = Types.LineType

-- Lobby converts Money to Influence (GAME_DESIGN 7.1); present only for the
-- classes allowed to lobby.
export type LobbyConfig = {
	moneyPerInfluence: number,
	maxInfluence: number, -- per Day
}

export type ClassEntry = {
	startMoney: number,
	startInfluence: number,
	startStock: { [StockId]: number },
	startWorkers: number, -- meaningful for Working only; 0 elsewhere
	startLines: { [LineType]: number }, -- owned lines at creation (5.2)
	baseVotes: number, -- ballot weight (7.3)
	influenceIncome: number, -- per Day (7.1)
	canBuild: { LineType }, -- possibly empty (6.2)
	lobby: LobbyConfig?, -- nil = this class cannot lobby
}

export type ClassesConfig = {
	influenceCap: number, -- shared cap (7.1)
} & {
	[ClassId]: ClassEntry,
}

return table.freeze({
	influenceCap = 20,

	Working = {
		startMoney = 10,
		startInfluence = 3,
		startStock = { food = 4, goods = 0, health = 1, education = 0 },
		startWorkers = 16,
		startLines = { Farm = 0, Factory = 0, Clinic = 0, School = 0 },
		baseVotes = 4,
		influenceIncome = 3,
		canBuild = {},
		-- cannot lobby (7.1)
	} :: ClassEntry,

	Middle = {
		startMoney = 25,
		startInfluence = 2,
		startStock = { food = 2, goods = 1, health = 1, education = 1 },
		startWorkers = 0,
		startLines = { Farm = 2, Factory = 0, Clinic = 1, School = 1 },
		baseVotes = 3,
		influenceIncome = 2,
		canBuild = { "Farm", "Clinic", "School" },
		lobby = { moneyPerInfluence = 3, maxInfluence = 2 },
	} :: ClassEntry,

	Capitalist = {
		startMoney = 50,
		startInfluence = 1,
		startStock = { food = 1, goods = 2, health = 1, education = 3 },
		startWorkers = 0,
		startLines = { Farm = 1, Factory = 3, Clinic = 0, School = 0 },
		baseVotes = 2,
		influenceIncome = 1,
		canBuild = { "Farm", "Factory" },
		lobby = { moneyPerInfluence = 2, maxInfluence = 4 },
	} :: ClassEntry,

	State = {
		startMoney = 30,
		startInfluence = 2,
		startStock = { food = 0, goods = 0, health = 0, education = 0 },
		startWorkers = 0,
		startLines = { Farm = 0, Factory = 0, Clinic = 1, School = 1 },
		baseVotes = 3,
		influenceIncome = 2,
		canBuild = { "Clinic", "School" },
		-- cannot lobby (7.1)
	} :: ClassEntry,
} :: ClassesConfig)
