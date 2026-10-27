--!nocheck
-- CityLayout tests (M11-T1): the city plan is a pure function of the public
-- line data in a PlayerView. Every line gets exactly one plot, plots are
-- grouped by owner, and the same view always produces the same plan. The
-- Instances that draw the plan are checked in Studio; this suite checks the
-- data contract they consume.

local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

local SEATS: { [string]: { string } } = {
	Working = { "Seat-Working" },
	Middle = { "Seat-Middle" },
	Capitalist = { "Seat-Capitalist" },
	State = { "Seat-State" },
}

function M.run()
	print("city layout")
	local root = Loader.mount("src")
	local CityLayout = Loader.require(root.client.City.CityLayout)
	local Types = Loader.require(root.shared.Game.Types)
	local StateFactory = Loader.require(root.shared.Game.State.StateFactory)
	local RuleSet = Loader.require(root.shared.Game.RuleSet)
	local PlayerViewBuilder = Loader.require(root.shared.Game.Behaviors.InfoModes.PlayerViewBuilder)

	local function viewFor(viewer: string): any
		local state = StateFactory.create("Normal", SEATS, 41)
		return PlayerViewBuilder.build(state, RuleSet.new("Normal"), viewer)
	end

	local function countByOwner(layout: any): { [string]: number }
		local counts: { [string]: number } = {}
		for _, plot in layout.plots do
			counts[plot.owner] = (counts[plot.owner] or 0) + 1
		end
		return counts
	end

	local function ids(layout: any): { string }
		local result: { string } = {}
		for _, plot in layout.plots do
			table.insert(result, plot.lineId)
		end
		table.sort(result)
		return result
	end

	Lib.test("the four districts exist even before a view arrives", function()
		local layout = CityLayout.build(nil)
		Lib.eq(#layout.districts, 4, "four class districts")
		Lib.eq(#layout.plots, 0, "no buildings yet")
		for index, owner in Types.CLASS_IDS do
			Lib.eq(layout.districts[index].owner, owner, "the canonical class order")
			Lib.eq(layout.districts[index].count, 0, "an empty district")
		end
	end)

	Lib.test("every line in the view gets exactly one plot in its owner's district", function()
		local view = viewFor("Working")
		local layout = CityLayout.build(view)
		local counts = countByOwner(layout)

		Lib.eq(#layout.plots, 10, "the initial ten lines")
		Lib.eq(counts.Working or 0, 0, "Working starts with no lines")
		Lib.eq(counts.Middle, 4, "Middle's four lines")
		Lib.eq(counts.Capitalist, 4, "Capitalist's four lines")
		Lib.eq(counts.State, 2, "State's two lines")

		for _, district in layout.districts do
			Lib.eq(
				district.count,
				counts[district.owner] or 0,
				`the {district.owner} district count matches its plots`
			)
		end

		-- Every id appears once; the initial set has all four line types.
		local expected: { string } = {}
		local seenTypes: { [string]: boolean } = {}
		for _, line in view.ownLines do
			table.insert(expected, line.id)
			seenTypes[line.type] = true
		end
		for _, owner in Types.CLASS_IDS do
			local other = view.others[owner]
			if other ~= nil then
				for _, line in other.lines do
					table.insert(expected, line.id)
					seenTypes[line.type] = true
				end
			end
		end
		table.sort(expected)
		local actual = ids(layout)
		Lib.eq(#actual, #expected, "one plot per line")
		for index = 1, #expected do
			Lib.eq(actual[index], expected[index], "the line ids match")
		end
		for _, lineType in Types.LINE_TYPES do
			Lib.truthy(seenTypes[lineType], `the initial city has a {lineType}`)
		end
	end)

	Lib.test("the plan is deterministic and independent of the viewer", function()
		local working = CityLayout.build(viewFor("Working"))
		local middle = CityLayout.build(viewFor("Middle"))
		Lib.eq(#working.plots, #middle.plots, "the same city size")
		for index = 1, #working.plots do
			Lib.eq(working.plots[index].lineId, middle.plots[index].lineId, "the same line")
			Lib.eq(working.plots[index].owner, middle.plots[index].owner, "the same owner")
			Lib.eq(working.plots[index].x, middle.plots[index].x, "the same x")
			Lib.eq(working.plots[index].z, middle.plots[index].z, "the same z")
		end

		local again = CityLayout.build(viewFor("Working"))
		for index = 1, #again.plots do
			Lib.eq(again.plots[index].x, working.plots[index].x, "a stable x")
			Lib.eq(again.plots[index].z, working.plots[index].z, "a stable z")
		end
	end)

	Lib.test("plots stay inside their district and never share a position", function()
		local layout = CityLayout.build(viewFor("Capitalist"))
		local half = CityLayout.DISTRICT_SIZE / 2
		local positions: { [string]: boolean } = {}
		for _, plot in layout.plots do
			local district
			for _, candidate in layout.districts do
				if candidate.owner == plot.owner then
					district = candidate
					break
				end
			end
			Lib.truthy(district ~= nil, "the plot has a district")
			Lib.truthy(math.abs(plot.x - district.centerX) <= half, "x stays inside the district")
			Lib.truthy(math.abs(plot.z - district.centerZ) <= half, "z stays inside the district")
			local key = `{plot.x}:{plot.z}`
			Lib.eq(positions[key], nil, "no two lines share a plot")
			positions[key] = true
		end
	end)
end

return M
