--!strict
-- PolicyBoard: the seven policy tracks, their current level and whether the
-- match enables them (UI_SPEC 4.2, PoliticsTab). It is a read/select panel:
-- clicking an enabled track selects it for the propose form; the PoliticsTab
-- owns the form itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Game.Types)
local ConfigPolicies = require(ReplicatedStorage.Shared.Config.Policies)
local Text = require(script.Parent.Parent.Primitives.Text)
local Button = require(script.Parent.Parent.Primitives.Button)

type PolicyId = Types.PolicyId

export type PolicyBoardProps = {
	policies: { [PolicyId]: number },
	selected: PolicyId?,
	onSelect: ((PolicyId) -> ())?,
	position: UDim2?,
}

local PolicyBoard = {}

local ROW = 28
local GAP = 2
local HEADING = 20
local WIDTH = 392

-- The height the PoliticsTab reserves for the board: the heading plus one
-- row per track. The panel places the propose form below it.
PolicyBoard.HEIGHT = HEADING + #Types.POLICY_IDS * (ROW + GAP)

local function trackLabel(policyId: PolicyId, policies: { [PolicyId]: number }): string
	local track = ConfigPolicies.tracks[policyId]
	local level = policies[policyId]
	if level == nil then
		return "OFF"
	end
	return track.levelLabels[level] or tostring(level)
end

function PolicyBoard.render(props: PolicyBoardProps): any
	local children: { any } = {}
	table.insert(
		children,
		React.createElement(Text.render, {
			text = "Policy board",
			tone = "muted",
			size = "xs",
			uppercase = true,
			position = UDim2.fromOffset(0, 0),
			size2 = UDim2.fromOffset(WIDTH, HEADING),
		})
	)

	for index = 1, #Types.POLICY_IDS do
		local policyId: PolicyId = Types.POLICY_IDS[index] :: any
		local track = ConfigPolicies.tracks[policyId]
		local enabled = props.policies[policyId] ~= nil
		local selected = props.selected == policyId
		table.insert(
			children,
			React.createElement(Button.render, {
				text = string.format("%s  %s", track.name, trackLabel(policyId, props.policies)),
				variant = if selected then "primary" else "secondary",
				size = "s",
				disabled = not enabled,
				position = UDim2.fromOffset(0, HEADING + (index - 1) * (ROW + GAP)),
				size2 = UDim2.fromOffset(WIDTH, ROW),
				onClick = function()
					if enabled and props.onSelect ~= nil then
						props.onSelect(policyId)
					end
				end,
			})
		)
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Position = props.position or UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(WIDTH, PolicyBoard.HEIGHT),
	}, children)
end

return PolicyBoard
