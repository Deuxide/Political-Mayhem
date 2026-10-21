--!strict
-- Per-class daily needs (GAME_DESIGN 5.3) and the difficulty scaling
-- (§12 needsMultiplier, rounded up). Shared by R8 PublicServices (which
-- covers unmet needs from the State's stock) and R9 Upkeep (which consumes
-- them), so both steps see exactly the same numbers.
--
-- Working's needs follow the worker count: ceil(workers x rate) from the
-- Config/Needs rates (0.5 Food, 0.25 Health). The other classes have flat
-- needs. The base need is a whole number (§5.3 states it in units); the
-- difficulty multiplier scales it and rounds up (D-051).
local Types = require(script.Parent.Types)
local RuleSet = require(script.Parent.RuleSet)
local ConfigNeeds = require(script.Parent.Parent.Config.Needs)

type ClassId = Types.ClassId
type MatchState = Types.MatchState
type StockId = Types.StockId

-- What a class has to cover this Day, per stock resource.
export type Required = { [StockId]: number }

local Needs = {}

-- The §5.3 base need of a class, before the difficulty scaling.
local function baseNeeds(state: MatchState, classId: ClassId): Required
	local workingId: ClassId = "Working"
	local workers = 0
	if classId == workingId then
		workers = state.classes[workingId].workers
	end

	local rates = (ConfigNeeds :: any)[classId]
	local required: Required = {}
	for si = 1, #Types.STOCK_IDS do
		local stockId: StockId = Types.STOCK_IDS[si] :: any
		local rate = (rates :: { [any]: any })[stockId]
		if rate ~= nil then
			if rate.perWorker ~= nil then
				required[stockId] = math.ceil(workers * rate.perWorker)
			elseif rate.flat ~= nil then
				required[stockId] = rate.flat
			end
		end
	end
	return required
end

-- The needs a class must cover this Day: the §5.3 base scaled by the
-- difficulty's needsMultiplier and rounded up (§12).
function Needs.required(state: MatchState, classId: ClassId, ruleSet: RuleSet.RuleSet): Required
	local base = baseNeeds(state, classId)
	local multiplier = ruleSet:needsMultiplier()
	local required: Required = {}
	-- index loop over the fixed mirror: `for-in` keys degrade to `string`
	-- in luau-lsp 1.70.1 (see luau-conventions)
	for si = 1, #Types.STOCK_IDS do
		local stockId: StockId = Types.STOCK_IDS[si] :: any
		local amount = base[stockId]
		if amount ~= nil then
			required[stockId] = math.ceil(amount * multiplier)
		end
	end
	return required
end

return Needs
