--!strict
-- TradeComposer: the offer form of the Diplomacy tab (UI_SPEC 4.2,
-- GAME_DESIGN 8.2). The viewer picks a class, the resources they give and
-- want, and optionally one promise (the PromiseBuilder). The server owns the
-- rules; this form only sends a Trade_Propose intent and shows the refusal
-- that matches its request id.
--
-- The local offer is added to the store by the App before the send, so the
-- outbox shows it immediately; the server's ack then gives it the real id.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Game.Types)
local ConfigResources = require(ReplicatedStorage.Shared.Config.Resources)
local Text = require(script.Parent.Parent.Primitives.Text)
local Button = require(script.Parent.Parent.Primitives.Button)
local Stepper = require(script.Parent.Parent.Composites.Stepper)
local PromiseBuilder = require(script.Parent.PromiseBuilder)
local Store = require(script.Parent.Parent.Parent.State.Store)

type ClassId = Types.ClassId
type Phase = Types.Phase
type PlayerView = Types.PlayerView
type PromiseSpec = Types.PromiseSpec
type ResourceBag = Types.ResourceBag
type ResourceId = Types.ResourceId
type TradeEntry = Store.TradeEntry

export type TradeComposerProps = {
	view: PlayerView,
	phase: Phase,
	notices: { any },
	offers: { TradeEntry },
	onPropose: (
		requestId: string,
		to: ClassId,
		give: ResourceBag,
		want: ResourceBag,
		promises: { PromiseSpec }
	) -> (),
	position: UDim2?,
}

local TradeComposer = {}

local WIDTH = 392
local ROW = 30

-- The vertical plan of the form. The PromiseBuilder area is always reserved,
-- so the Propose button does not jump when a promise is attached.
local TARGET_LABEL_Y = 24
local TARGET_Y = 42
local RESOURCE_HEADER_Y = 70
local ROWS_Y = 88
local PROMISE_Y = 268
local BUILDER_Y = 296
local PROPOSE_Y = 526

TradeComposer.HEIGHT = 564

-- A UI bound for the steppers; the server accepts up to
-- ConfigNetwork.maxResourceAmount, so this only limits clicks.
local MAX_AMOUNT = 99

-- One request id per proposal click. The server echoes it in a refusal, so
-- the form can show the matching Notice instead of a generic error.
local requestCounter = 0

local function withAmount(bag: ResourceBag, resourceId: ResourceId, amount: number): ResourceBag
	local nextBag = table.clone(bag)
	if amount > 0 then
		nextBag[resourceId] = amount
	else
		nextBag[resourceId] = nil
	end
	return nextBag
end

local function hasResources(bag: ResourceBag): boolean
	return next(bag) ~= nil
end

function TradeComposer.render(props: TradeComposerProps): any
	local view = props.view
	local children: { any } = {}

	local initialTarget: ClassId? = nil
	local target, setTarget = React.useState(initialTarget)
	local give, setGive = React.useState({} :: ResourceBag)
	local want, setWant = React.useState({} :: ResourceBag)
	-- The hook's generic does not keep a nil-able union of table shapes here;
	-- keep the raw state loose and hand the form the precise type.
	local promiseState, setPromiseState = React.useState(nil :: any)
	local promise: PromiseSpec? = promiseState
	local setPromise: (PromiseSpec?) -> () = setPromiseState
	local lastRequestId, setLastRequestId = React.useState("")

	table.insert(
		children,
		React.createElement(Text.render, {
			text = "Trade composer",
			tone = "secondary",
			size = "xs",
			uppercase = true,
			position = UDim2.fromOffset(0, 0),
			size2 = UDim2.fromOffset(WIDTH, 16),
		})
	)
	table.insert(
		children,
		React.createElement(Text.render, {
			text = "To",
			tone = "muted",
			size = "xs",
			position = UDim2.fromOffset(0, TARGET_LABEL_Y),
			size2 = UDim2.fromOffset(40, 16),
		})
	)

	local targetIndex = 0
	for _, rawClassId in Types.CLASS_IDS do
		local classId: ClassId = rawClassId :: any
		if classId ~= view.viewer then
			local index = targetIndex
			targetIndex += 1
			table.insert(
				children,
				React.createElement(Button.render, {
					text = classId,
					variant = if target == classId then "primary" else "secondary",
					size = "s",
					position = UDim2.fromOffset(index * 130, TARGET_Y),
					size2 = UDim2.fromOffset(120, 26),
					onClick = function()
						setTarget(classId)
						setLastRequestId("")
						if promise ~= nil and promise.kind == "Deliver" then
							setPromise({
								kind = "Deliver",
								resource = promise.resource,
								amount = promise.amount,
								to = classId,
								byDay = promise.byDay,
							})
						end
					end,
				})
			)
		end
	end

	table.insert(
		children,
		React.createElement(Text.render, {
			text = "Resource",
			tone = "muted",
			size = "xs",
			position = UDim2.fromOffset(0, RESOURCE_HEADER_Y),
			size2 = UDim2.fromOffset(60, 16),
		})
	)
	table.insert(
		children,
		React.createElement(Text.render, {
			text = "Give",
			tone = "muted",
			size = "xs",
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(64, RESOURCE_HEADER_Y),
			size2 = UDim2.fromOffset(150, 16),
		})
	)
	table.insert(
		children,
		React.createElement(Text.render, {
			text = "Want",
			tone = "muted",
			size = "xs",
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(222, RESOURCE_HEADER_Y),
			size2 = UDim2.fromOffset(150, 16),
		})
	)

	for index, rawResourceId in Types.RESOURCE_IDS do
		local resourceId: ResourceId = rawResourceId :: any
		local y = ROWS_Y + (index - 1) * ROW
		table.insert(
			children,
			React.createElement(Text.render, {
				text = (ConfigResources :: any)[resourceId].name,
				tone = "secondary",
				size = "xs",
				position = UDim2.fromOffset(0, y + 6),
				size2 = UDim2.fromOffset(60, 16),
			})
		)
		table.insert(
			children,
			React.createElement(Stepper.render, {
				value = give[resourceId] or 0,
				min = 0,
				max = MAX_AMOUNT,
				position = UDim2.fromOffset(64, y),
				onChange = function(value)
					setGive(withAmount(give, resourceId, value))
					setLastRequestId("")
				end,
			})
		)
		table.insert(
			children,
			React.createElement(Stepper.render, {
				value = want[resourceId] or 0,
				min = 0,
				max = MAX_AMOUNT,
				position = UDim2.fromOffset(222, y),
				onChange = function(value)
					setWant(withAmount(want, resourceId, value))
					setLastRequestId("")
				end,
			})
		)
	end

	if promise == nil then
		table.insert(
			children,
			React.createElement(Button.render, {
				text = "Attach a promise",
				variant = "secondary",
				size = "s",
				disabled = target == nil,
				position = UDim2.fromOffset(0, PROMISE_Y),
				size2 = UDim2.fromOffset(160, 26),
				onClick = function()
					if target == nil then
						return
					end
					local spec: PromiseSpec? = PromiseBuilder.defaultSpec(
						"Deliver",
						target,
						view.day,
						view.rounds,
						view.policies
					)
					if spec ~= nil then
						setPromise(spec)
						setLastRequestId("")
					end
				end,
			})
		)
	else
		table.insert(
			children,
			React.createElement(Button.render, {
				text = "Remove promise",
				variant = "secondary",
				size = "s",
				position = UDim2.fromOffset(0, PROMISE_Y),
				size2 = UDim2.fromOffset(160, 26),
				onClick = function()
					setPromise(nil)
					setLastRequestId("")
				end,
			})
		)
	end

	table.insert(
		children,
		React.createElement(PromiseBuilder.render, {
			viewer = view.viewer,
			target = target,
			day = view.day,
			rounds = view.rounds,
			policies = view.policies,
			promise = promise,
			onChange = function(nextSpec)
				setPromise(nextSpec)
				setLastRequestId("")
			end,
			position = UDim2.fromOffset(0, BUILDER_Y),
		})
	)

	local reason: string? = nil
	if props.phase ~= "Window" then
		reason = "the Window is closed"
	elseif target == nil then
		reason = "choose a class"
	elseif not hasResources(give) and not hasResources(want) and promise == nil then
		reason = "add a resource or a promise"
	end

	local function propose()
		if target == nil or reason ~= nil then
			return
		end
		requestCounter += 1
		local requestId = string.format("trade-%d", requestCounter)
		setLastRequestId(requestId)
		local promises: { PromiseSpec } = {}
		if promise ~= nil then
			table.insert(promises, promise)
		end
		props.onPropose(requestId, target, give, want, promises)
	end

	local refusal: any = nil
	if lastRequestId ~= "" then
		for index = #props.notices, 1, -1 do
			local notice = props.notices[index]
			if notice.requestId == lastRequestId then
				refusal = notice
				break
			end
		end
	end
	local sent = false
	local sending = false
	if lastRequestId ~= "" then
		for _, entry in props.offers do
			if entry.requestId == lastRequestId then
				sent = true
				sending = entry.pendingAck == true
				break
			end
		end
	end

	local statusText: string
	local statusTone: string
	if refusal ~= nil then
		statusText = refusal.message or "the server refused the offer"
		statusTone = "danger"
	elseif sending then
		statusText = "sending..."
		statusTone = "warning"
	elseif sent then
		statusText = "offer sent"
		statusTone = "success"
	elseif reason ~= nil then
		statusText = reason
		statusTone = "muted"
	else
		statusText = "a promise-only offer is allowed"
		statusTone = "secondary"
	end

	table.insert(
		children,
		React.createElement(Text.render, {
			text = statusText,
			tone = statusTone,
			size = "xs",
			position = UDim2.fromOffset(0, PROPOSE_Y + 4),
			size2 = UDim2.fromOffset(260, 18),
		})
	)
	table.insert(
		children,
		React.createElement(Button.render, {
			text = "Propose offer",
			variant = "primary",
			size = "s",
			disabled = reason ~= nil,
			position = UDim2.fromOffset(WIDTH - 120, PROPOSE_Y),
			size2 = UDim2.fromOffset(120, 26),
			onClick = propose,
		})
	)

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(WIDTH, TradeComposer.HEIGHT),
		Position = props.position or UDim2.fromOffset(0, 0),
	}, children)
end

return TradeComposer
