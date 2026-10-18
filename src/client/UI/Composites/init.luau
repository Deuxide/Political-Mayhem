--!strict
-- Composites module: exports all composite components.

local Card = require(script.Card)
local ResourceChip = require(script.ResourceChip)
local SegmentedTrack = require(script.SegmentedTrack)
local Stepper = require(script.Stepper)
local Tabs = require(script.Tabs)
local Modal = require(script.Modal)
local Toast = require(script.Toast)
local StatRow = require(script.StatRow)
local ClassHeader = require(script.ClassHeader)
local Tooltip = require(script.Tooltip)

return {
	Card = Card,
	ResourceChip = ResourceChip,
	SegmentedTrack = SegmentedTrack,
	Stepper = Stepper,
	Tabs = Tabs,
	Modal = Modal,
	Toast = Toast,
	StatRow = StatRow,
	ClassHeader = ClassHeader,
	Tooltip = Tooltip,
}
