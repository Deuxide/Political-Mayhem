--!strict
-- CityLayout: turns the public line data in a PlayerView into a deterministic
-- city plan. It is pure data (no Instances, no gameplay state), so the same
-- view always places the same building in the same plot. CityView draws the
-- plan; LineVisual gives each plot its building shape.
--
-- Each class owns one district of the city, so ownership is visible without
-- reading a label. Within a district the plots are a grid, one plot per line,
-- which makes the line count visible too.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Game.Types)

type ClassId = Types.ClassId
type LineType = Types.LineType
type LineView = Types.LineView
type PlayerView = Types.PlayerView

export type District = {
	owner: ClassId,
	centerX: number,
	centerZ: number,
	count: number,
}

export type Plot = {
	lineId: string,
	lineType: LineType,
	owner: ClassId,
	x: number,
	z: number,
	row: number, -- zero-based row within the owner's district
	column: number, -- zero-based column within the owner's district
}

export type Layout = {
	plots: { Plot },
	districts: { District },
}

local CityLayout = {}

-- Visual constants live here with the plan, not in a component. The district
-- size leaves a road-width gap between neighbours; the plot grid fits inside
-- it even when every district has four full rows.
CityLayout.DISTRICT_SIZE = 16
CityLayout.CITY_SIZE = 38
CityLayout.PLOT_SPACING = 3.4
CityLayout.GRID_COLUMNS = 4

-- The city is read from the default camera, which looks from +Z towards the
-- centre: Working and Middle are the front pair, Capitalist and State the back.
local CENTERS: { [ClassId]: { x: number, z: number } } = {
	Working = { x = -9, z = 9 },
	Middle = { x = 9, z = 9 },
	Capitalist = { x = -9, z = -9 },
	State = { x = 9, z = -9 },
}

local function linesFor(view: PlayerView, owner: ClassId): { LineView }
	local result: { LineView } = {}
	if owner == view.viewer then
		for _, line in view.ownLines do
			table.insert(result, line)
		end
	else
		local other = view.others[owner]
		if other ~= nil then
			for _, line in other.lines do
				table.insert(result, line)
			end
		end
	end
	table.sort(result, function(a, b)
		return a.id < b.id
	end)
	return result
end

-- build(nil) still returns the four empty districts, so the city keeps its
-- shape while the client waits for the first snapshot.
function CityLayout.build(view: PlayerView?): Layout
	local plots: { Plot } = {}
	local districts: { District } = {}

	for index = 1, #Types.CLASS_IDS do
		local owner: ClassId = Types.CLASS_IDS[index] :: any
		local center = CENTERS[owner]
		local lines: { LineView } = {}
		if view ~= nil then
			lines = linesFor(view, owner)
		end
		local columns = math.min(CityLayout.GRID_COLUMNS, math.max(1, #lines))
		local rows = math.max(1, math.ceil(#lines / columns))

		table.insert(districts, {
			owner = owner,
			centerX = center.x,
			centerZ = center.z,
			count = #lines,
		})

		for plotIndex, line in lines do
			local column = (plotIndex - 1) % columns
			local row = math.floor((plotIndex - 1) / columns)
			table.insert(plots, {
				lineId = line.id,
				lineType = line.type,
				owner = owner,
				x = center.x + (column - (columns - 1) / 2) * CityLayout.PLOT_SPACING,
				z = center.z + (row - (rows - 1) / 2) * CityLayout.PLOT_SPACING,
				row = row,
				column = column,
			})
		end
	end

	return { plots = plots, districts = districts }
end

return CityLayout
