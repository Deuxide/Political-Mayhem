--!strict
-- Bot tuning (GAME_DESIGN 15). Data only: the per-bot RNG seed stride keeps
-- the four deterministic streams apart while every stream still comes from
-- the match seed. A prime stride avoids accidental overlap between classes.
-- The heuristics themselves live in server/Services/Bots, not here.
--
-- `policyPreference` is the class-interest sign for a bill: +1 means the
-- class wants the track higher, -1 lower, 0/absent means it abstains. The
-- bots vote their base weight and never commit Influence in v1 (T2).

local Types = require(script.Parent.Parent.Game.Types)

type ClassId = Types.ClassId
type PolicyId = Types.PolicyId

export type PolicyPreference = { [ClassId]: { [PolicyId]: number } }
export type AlliancePreference = { [ClassId]: { [ClassId]: number } }

return table.freeze({
	rngSeedStride = 104729,

	-- Money kept back from wages so a bot can still buy a missing need.
	moneyReserve = 2,
	-- Extra units of a stock a bot keeps before selling the surplus.
	stockBuffer = 1,
	-- The market value of one Influence when a bot weighs a trade.
	influenceValue = 3,
	-- A neutral reputation (the starting 0/0 score) is 0.5. A less trusted
	-- counterparty must offer this much more value per point below neutral.
	neutralTrust = 0.5,
	tradeTrustPenalty = 1,
	-- Middle builds until it owns this many lines; it builds a School while
	-- its Education is below the VP target.
	middleLineTarget = 5,
	middleEducationTarget = 2,
	-- Capitalist builds Farms until it owns this many; Factories need a
	-- reliable Education input the bot cannot guarantee yet.
	capitalistFarmTarget = 3,
	-- State keeps this much Health/Education when PublicServices is Universal.
	publicServicesReserve = 2,

	-- Bots form an alliance in the first Window they are free, then review it
	-- after this many Days. A NoBreakAlliance promise delays the break.
	allianceBreakAfterDays = 4,

	-- Positive pair scores only; a bot accepts the best incoming proposal and
	-- otherwise proposes to the best free class. The values encode the
	-- natural bloc (Working + Middle, Capitalist + State) without making it
	-- mandatory when a class is already allied.
	alliancePreference = {
		Working = { Middle = 3, State = 2, Capitalist = 1 },
		Middle = { Working = 3, State = 2, Capitalist = 1 },
		Capitalist = { State = 3, Middle = 2, Working = 1 },
		State = { Capitalist = 3, Middle = 2, Working = 1 },
	} :: AlliancePreference,

	policyPreference = {
		Working = {
			Wage = 1,
			TaxWorking = -1,
			TaxMiddle = 1,
			TaxCapitalist = 1,
			PublicServices = 1,
			Tariff = -1,
			StrikeRights = 1,
		},
		Middle = {
			Wage = -1,
			TaxWorking = 1,
			TaxMiddle = -1,
			TaxCapitalist = 1,
			PublicServices = 1,
			Tariff = -1,
			StrikeRights = -1,
		},
		Capitalist = {
			Wage = -1,
			TaxWorking = 1,
			TaxMiddle = 1,
			TaxCapitalist = -1,
			PublicServices = 1,
			Tariff = -1,
			StrikeRights = -1,
		},
		State = {
			Wage = -1,
			TaxWorking = 1,
			TaxMiddle = 1,
			TaxCapitalist = 1,
			PublicServices = 1,
			Tariff = 1,
			StrikeRights = -1,
		},
	} :: PolicyPreference,
})
