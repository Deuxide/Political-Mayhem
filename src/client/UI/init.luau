--!strict
-- UI module: exports all UI modules.

local Theme = require(script.Theme)
local Screens = require(script.Screens)
local Primitives = require(script.Primitives)
local Composites = require(script.Composites)
local Panels = require(script.Panels)
local Gallery = require(script.Gallery)

return {
	Theme = Theme,
	Screens = Screens,
	Primitives = Primitives,
	Composites = Composites,
	Panels = Panels,
	Gallery = Gallery,
}
