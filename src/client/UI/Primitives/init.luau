--!strict
-- Primitives module: exports all primitive components.

local Surface = require(script.Surface)
local Text = require(script.Text)
local Button = require(script.Button)
local Icon = require(script.Icon)
local Divider = require(script.Divider)
local TrackSegment = require(script.TrackSegment)

return {
	Surface = Surface,
	Text = Text,
	Button = Button,
	Icon = Icon,
	Divider = Divider,
	TrackSegment = TrackSegment,
}