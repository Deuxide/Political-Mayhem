--!strict
-- PromiseBuilder: the promise form of the trade composer (UI_SPEC 4.2,
-- GAME_DESIGN 8.3). It edits one PromiseSpec: the kind, the auditable
-- parameters and the Day of the audit. The composer owns the spec, so the
-- form is controlled; every click emits a complete new spec.
--
-- The form shows exactly what will be audited and when: the description line
-- names both classes and the terms, the second line names the Closing Bell.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Game.Types)
local ConfigPolicies = require(ReplicatedStorage.Shared.Config.Policies)
local ConfigResources = require(ReplicatedStorage.Shared.Config.Resources)
local Bills = require(ReplicatedStorage.Shared.Game.Ops.Bills)
local Text = require(script.Parent.Parent.Primitives.Text)
local Button = require(script.Parent.Parent.Primitives.Button)
local Stepper = require(script.Parent.Parent.Composites.Stepper)

type ClassId = Types.ClassId
type PlayerView = Types.PlayerView
type PolicyId = Types.PolicyId
type PromiseKind = Types.PromiseKind
type PromiseSpec = Types.PromiseSpec
type ResourceId = Types.ResourceId

export type PromiseBuilderProps = {
	viewer: ClassId,
	target: ClassId?,
	day: number,
	rounds: number,
	policies: { [PolicyId]: number },
	promise: PromiseSpec?,
	onChange: (PromiseSpec?) -> (),
	position: UDim2?,
}

local PromiseBuilder = {}

local WIDTH = 392
PromiseBuilder.HEIGHT = 230

-- A UI bound for the stepper; the server caps a promise at the same amount
-- as any other bag (NETWORKING 3.1), so this is only about clicks.
local MAX_PROMISE_AMOUNT = 99

local KINDS: { { kind: PromiseKind, label: string } } = {
	{ kind = "Deliver", label = "Deliver" },
	{ kind = "VoteYes", label = "Vote yes" },
	{ kind = "NoStrike", label = "No strike" },
	{ kind = "NoBreakAlliance", label = "No alliance" },
}

local function firstEnabled(policies: { [PolicyId]: number }): PolicyId?
	for _, rawPolicyId in Types.POLICY_IDS do
		local policyId: PolicyId = rawPolicyId :: any
		if policies[policyId] ~= nil then
			return policyId
		end
	end
	return nil
end

local function defaultLevel(policyId: PolicyId, current: number): number
	local low, high = Bills.targetBounds(policyId, current)
	if current + 1 <= high then
		return current + 1
	end
	if current - 1 >= low then
		return current - 1
	end
	return current
end

local function levelLabel(policyId: PolicyId, level: number): string
	local track = ConfigPolicies.tracks[policyId]
	return track.levelLabels[level] or tostring(level)
end

-- The promise spec a fresh click on `kind` starts from. Deliver needs a
-- target (the offer's recipient); VoteYes needs an active policy track.
function PromiseBuilder.defaultSpec(
	kind: PromiseKind,
	target: ClassId?,
	day: number,
	rounds: number,
	policies: { [PolicyId]: number }
): PromiseSpec?
	local byDay = math.min(rounds, day + 1)
	if kind == "Deliver" then
		if target == nil then
			return nil
		end
		return { kind = "Deliver", resource = "Food", amount = 1, to = target, byDay = byDay }
	elseif kind == "VoteYes" then
		local policyId: PolicyId? = firstEnabled(policies)
		if policyId == nil then
			return nil
		end
		local chosen: PolicyId = policyId :: any
		return {
			kind = "VoteYes",
			policyId = chosen,
			level = defaultLevel(chosen, (policies :: any)[chosen]),
			byDay = byDay,
		}
	elseif kind == "NoStrike" then
		return { kind = "NoStrike", untilDay = byDay }
	end
	return { kind = "NoBreakAlliance", untilDay = byDay }
end

local function withUntil(kind: "NoStrike" | "NoBreakAlliance", untilDay: number): PromiseSpec
	if kind == "NoStrike" then
		return { kind = "NoStrike", untilDay = untilDay }
	end
	return { kind = "NoBreakAlliance", untilDay = untilDay }
end

-- The one-line description shared by the builder, the offer cards and the
-- ledger. `promisee` supplies the class for the two kinds whose spec does not
-- carry the recipient (NoStrike, NoBreakAlliance).
function PromiseBuilder.describeSpec(spec: PromiseSpec, promisee: ClassId?): string
	if spec.kind == "Deliver" then
		local resource = (ConfigResources :: any)[spec.resource]
		return string.format(
			"Deliver %d %s to %s by Day %d",
			spec.amount,
			resource.name,
			spec.to,
			spec.byDay
		)
	elseif spec.kind == "VoteYes" then
		local track = ConfigPolicies.tracks[spec.policyId]
		return string.format(
			"Vote Yes on %s to %s by Day %d",
			track.name,
			track.levelLabels[spec.level] or tostring(spec.level),
			spec.byDay
		)
	elseif spec.kind == "NoStrike" then
		return string.format(
			"No strike against %s until Day %d",
			promisee or "the other class",
			spec.untilDay
		)
	end
	return string.format(
		"Alliance with %s kept until Day %d",
		promisee or "the other class",
		spec.untilDay
	)
end

-- When the audit happens (GAME_DESIGN 8.3).
function PromiseBuilder.auditText(spec: PromiseSpec): string
	if spec.kind == "Deliver" or spec.kind == "VoteYes" then
		return string.format("Audited at the Closing Bell of Day %d", spec.byDay)
	end
	return string.format("Audited at every Closing Bell until Day %d", spec.untilDay)
end

function PromiseBuilder.render(props: PromiseBuilderProps): any
	local promise = props.promise
	local children: { any } = {}

	if promise == nil then
		table.insert(
			children,
			React.createElement(Text.render, {
				text = "No promise attached",
				tone = "muted",
				size = "xs",
				position = UDim2.fromOffset(0, 0),
				size2 = UDim2.fromOffset(WIDTH, 18),
			})
		)
	else
		-- the kind row: four 96 px buttons
		for index, entry in KINDS do
			local kind: PromiseKind = entry.kind :: any
			local disabled = kind == "NoStrike" and props.viewer ~= "Working"
			table.insert(
				children,
				React.createElement(Button.render, {
					text = entry.label,
					variant = if promise.kind == kind then "primary" else "secondary",
					size = "s",
					disabled = disabled,
					position = UDim2.fromOffset((index - 1) * 98, 0),
					size2 = UDim2.fromOffset(96, 26),
					onClick = function()
						local nextSpec = PromiseBuilder.defaultSpec(
							kind,
							props.target,
							props.day,
							props.rounds,
							props.policies
						)
						if nextSpec ~= nil then
							props.onChange(nextSpec)
						end
					end,
				})
			)
		end

		local summaryY = 0
		if promise.kind == "Deliver" then
			for index, rawResourceId in Types.RESOURCE_IDS do
				local resourceId: ResourceId = rawResourceId :: any
				local column = (index - 1) % 3
				local row = math.floor((index - 1) / 3)
				table.insert(
					children,
					React.createElement(Button.render, {
						text = (ConfigResources :: any)[resourceId].name,
						variant = if promise.resource == resourceId then "primary" else "secondary",
						size = "s",
						position = UDim2.fromOffset(column * 124, 30 + row * 28),
						size2 = UDim2.fromOffset(120, 26),
						onClick = function()
							props.onChange({
								kind = "Deliver",
								resource = resourceId,
								amount = promise.amount,
								to = promise.to,
								byDay = promise.byDay,
							})
						end,
					})
				)
			end
			table.insert(
				children,
				React.createElement(Stepper.render, {
					value = promise.amount,
					min = 1,
					max = MAX_PROMISE_AMOUNT,
					position = UDim2.fromOffset(0, 90),
					onChange = function(value)
						props.onChange({
							kind = "Deliver",
							resource = promise.resource,
							amount = math.max(1, value),
							to = promise.to,
							byDay = promise.byDay,
						})
					end,
				})
			)
			table.insert(
				children,
				React.createElement(Text.render, {
					text = "Amount",
					tone = "muted",
					size = "xs",
					position = UDim2.fromOffset(156, 96),
					size2 = UDim2.fromOffset(120, 16),
				})
			)
			table.insert(
				children,
				React.createElement(Stepper.render, {
					value = promise.byDay,
					min = props.day,
					max = props.rounds,
					position = UDim2.fromOffset(0, 120),
					onChange = function(value)
						props.onChange({
							kind = "Deliver",
							resource = promise.resource,
							amount = promise.amount,
							to = promise.to,
							byDay = value,
						})
					end,
				})
			)
			table.insert(
				children,
				React.createElement(Text.render, {
					text = "By Day",
					tone = "muted",
					size = "xs",
					position = UDim2.fromOffset(156, 126),
					size2 = UDim2.fromOffset(120, 16),
				})
			)
			summaryY = 154
		elseif promise.kind == "VoteYes" then
			local enabled: { PolicyId } = {}
			for _, rawPolicyId in Types.POLICY_IDS do
				local policyId: PolicyId = rawPolicyId :: any
				if (props.policies :: any)[policyId] ~= nil then
					table.insert(enabled, policyId)
				end
			end
			for index, rawPolicyId in enabled do
				local policyId: PolicyId = rawPolicyId :: any
				local column = (index - 1) % 3
				local row = math.floor((index - 1) / 3)
				table.insert(
					children,
					React.createElement(Button.render, {
						text = ConfigPolicies.tracks[policyId].name,
						variant = if promise.policyId == policyId then "primary" else "secondary",
						size = "s",
						position = UDim2.fromOffset(column * 132, 30 + row * 28),
						size2 = UDim2.fromOffset(128, 26),
						onClick = function()
							local current = (props.policies :: any)[policyId] :: number
							props.onChange({
								kind = "VoteYes",
								policyId = policyId,
								level = defaultLevel(policyId, current),
								byDay = promise.byDay,
							})
						end,
					})
				)
			end
			local current = (props.policies :: any)[promise.policyId] :: number
			local low, high = Bills.targetBounds(promise.policyId, current)
			table.insert(
				children,
				React.createElement(Stepper.render, {
					value = promise.level,
					min = low,
					max = high,
					position = UDim2.fromOffset(0, 120),
					onChange = function(value)
						props.onChange({
							kind = "VoteYes",
							policyId = promise.policyId,
							level = value,
							byDay = promise.byDay,
						})
					end,
				})
			)
			table.insert(
				children,
				React.createElement(Text.render, {
					text = "Level: " .. levelLabel(promise.policyId, promise.level),
					tone = "muted",
					size = "xs",
					position = UDim2.fromOffset(156, 126),
					size2 = UDim2.fromOffset(220, 16),
				})
			)
			table.insert(
				children,
				React.createElement(Stepper.render, {
					value = promise.byDay,
					min = props.day,
					max = props.rounds,
					position = UDim2.fromOffset(0, 150),
					onChange = function(value)
						props.onChange({
							kind = "VoteYes",
							policyId = promise.policyId,
							level = promise.level,
							byDay = value,
						})
					end,
				})
			)
			table.insert(
				children,
				React.createElement(Text.render, {
					text = "By Day",
					tone = "muted",
					size = "xs",
					position = UDim2.fromOffset(156, 156),
					size2 = UDim2.fromOffset(120, 16),
				})
			)
			summaryY = 184
		else
			table.insert(
				children,
				React.createElement(Stepper.render, {
					value = promise.untilDay,
					min = props.day,
					max = props.rounds,
					position = UDim2.fromOffset(0, 30),
					onChange = function(value)
						props.onChange(withUntil(promise.kind, value))
					end,
				})
			)
			table.insert(
				children,
				React.createElement(Text.render, {
					text = "Until Day",
					tone = "muted",
					size = "xs",
					position = UDim2.fromOffset(156, 36),
					size2 = UDim2.fromOffset(120, 16),
				})
			)
			summaryY = 62
		end

		table.insert(
			children,
			React.createElement(Text.render, {
				text = PromiseBuilder.describeSpec(promise, props.target),
				tone = "secondary",
				size = "xs",
				position = UDim2.fromOffset(0, summaryY),
				size2 = UDim2.fromOffset(WIDTH, 16),
			})
		)
		table.insert(
			children,
			React.createElement(Text.render, {
				text = PromiseBuilder.auditText(promise),
				tone = "muted",
				size = "xs",
				position = UDim2.fromOffset(0, summaryY + 18),
				size2 = UDim2.fromOffset(WIDTH, 16),
			})
		)
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(WIDTH, PromiseBuilder.HEIGHT),
		Position = props.position or UDim2.fromOffset(0, 0),
	}, children)
end

return PromiseBuilder
