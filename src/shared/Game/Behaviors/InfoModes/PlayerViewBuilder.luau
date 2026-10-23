--!strict
-- PlayerViewBuilder (GAME_DESIGN 13): turns the authoritative MatchState into
-- the PlayerView one client may receive. The builder owns everything that is
-- the same in every info mode — the viewer's own class, policies, Stability,
-- the Day, VP, lines, bills, promises, alliances, reputation and the victory
-- result — and delegates only the three fields a mode may hide or tier
-- (another class's Money, stocks and Influence) to the InfoMode strategy the
-- RuleSet selects.
--
-- The view is built from a deep copy of the state: what a client holds can
-- never alias the server's live state, and mutating a view (a test, a buggy
-- handler) cannot change the match.
--
-- Hidden fields are absent, never sent as a sentinel: Lua has no nil-valued
-- keys and the builder never assigns one, so "hidden" and "not there" are
-- the same thing on the wire — which is the point of section 13.

local Types = require(script.Parent.Parent.Parent.Types)
local RuleSet = require(script.Parent.Parent.Parent.RuleSet)
local StateOps = require(script.Parent.Parent.Parent.State.StateOps)
local Alliances = require(script.Parent.Parent.Parent.Ops.Alliances)
local Needs = require(script.Parent.Parent.Parent.Needs)
local InfoMode = require(script.Parent.InfoMode)
local OpenInfo = require(script.Parent.OpenInfo)
local PartialInfo = require(script.Parent.PartialInfo)
local FogInfo = require(script.Parent.FogInfo)

type ClassId = Types.ClassId
type ClassView = Types.ClassView
type LineId = Types.LineId
type LineView = Types.LineView
type MatchState = Types.MatchState
type PlayerView = Types.PlayerView
type RuleSetType = RuleSet.RuleSet

-- `RuleSet:infoMode()` names the strategy; the difficulty never does. `any`
-- because the three mode classes are sibling types with no common instance
-- type (same reason as the objective and step registries).
local REGISTRY: { [string]: any } = {
	open = OpenInfo,
	partial = PartialInfo,
	fog = FogInfo,
}

local PlayerViewBuilder = {}

-- Another class's lines are exact in every mode (13), but only the public
-- fields are sent; sorted by id so the same state always builds the same
-- view.
local function lineViews(state: MatchState, owner: ClassId): { LineView }
	local ids: { LineId } = {}
	for id, line in state.lines do
		if line.owner == owner then
			table.insert(ids, id)
		end
	end
	table.sort(ids)

	local views: { LineView } = {}
	for i = 1, #ids do
		local line = state.lines[ids[i]]
		table.insert(views, {
			id = line.id,
			type = line.type,
			owner = line.owner,
			openSlots = line.openSlots,
		})
	end
	return views
end

-- The alliance benefit (8.4): allied classes see each other's full stocks.
local function alliedWith(state: MatchState, viewer: ClassId, target: ClassId): boolean
	local alliance = Alliances.allianceOf(state, viewer)
	if alliance == nil then
		return false
	end
	for mi = 1, #alliance.members do
		if alliance.members[mi] == target then
			return true
		end
	end
	return false
end

local function buildClassView(
	mode: InfoMode.InfoMode,
	state: MatchState,
	viewer: ClassId,
	target: ClassId
): ClassView
	local ctx: InfoMode.TargetContext = {
		state = state,
		viewer = viewer,
		target = target,
		allied = alliedWith(state, viewer, target),
	}
	-- money, stock and influence come from the mode: nil for a hidden field,
	-- which leaves the key out of the table entirely
	return {
		money = mode:money(ctx),
		stock = mode:stock(ctx),
		influence = mode:influence(ctx),
		vp = state.classes[target].vp,
		lines = lineViews(state, target),
	}
end

function PlayerViewBuilder.build(
	state: MatchState,
	ruleSet: RuleSetType,
	viewer: ClassId
): PlayerView
	local modeName = ruleSet:infoMode()
	local mode: InfoMode.InfoMode? = REGISTRY[modeName]
	if mode == nil then
		error(`PlayerViewBuilder: no strategy for info mode '{modeName}'`, 0)
	end

	local snapshot = StateOps.deepCopy(state)

	local others: { [ClassId]: ClassView } = {}
	for ci = 1, #Types.CLASS_IDS do
		local classId: ClassId = Types.CLASS_IDS[ci] :: any
		if classId ~= viewer then
			others[classId] = buildClassView(mode, snapshot, viewer, classId)
		end
	end

	return {
		viewer = viewer,
		day = snapshot.day,
		rounds = ruleSet:rounds(),
		phase = snapshot.phase,
		stability = snapshot.stability,
		policies = snapshot.policies,
		own = snapshot.classes[viewer],
		ownLines = lineViews(snapshot, viewer),
		needs = Needs.required(snapshot, viewer, ruleSet),
		draft = snapshot.drafts[viewer],
		others = others,
		bills = snapshot.bills,
		promises = snapshot.promises,
		alliances = snapshot.alliances,
		reputation = snapshot.reputation,
		victory = snapshot.victory,
	}
end

return PlayerViewBuilder
