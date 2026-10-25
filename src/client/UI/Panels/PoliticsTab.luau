--!strict
-- PoliticsTab: the political half of the action dock (UI_SPEC 4.2) — the
-- policy board, the propose-a-bill form, the live bills and the viewer's
-- ballot. A ballot is a draft field (debounced like every other draft edit);
-- a bill proposal is a live Bill_Propose intent (NETWORKING 3.1). The server
-- owns every rule; this panel only shows the state and sends the intent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Game.Types)
local ConfigPolicies = require(ReplicatedStorage.Shared.Config.Policies)
local ConfigClasses = require(ReplicatedStorage.Shared.Config.Classes)
local Bills = require(ReplicatedStorage.Shared.Game.Ops.Bills)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)
local Text = require(script.Parent.Parent.Primitives.Text)
local Button = require(script.Parent.Parent.Primitives.Button)
local Stepper = require(script.Parent.Parent.Composites.Stepper)
local Card = require(script.Parent.Parent.Composites.Card)
local PolicyBoard = require(script.Parent.PolicyBoard)

type ActionDraft = Types.ActionDraft
type Bill = Types.Bill
type BillId = Types.BillId
type ClassId = Types.ClassId
type PlayerView = Types.PlayerView
type PolicyId = Types.PolicyId
type VoteSide = Types.VoteSide

export type SyncState = "clean" | "pending" | "rejected"

export type PoliticsTabProps = {
	view: PlayerView,
	draft: ActionDraft,
	syncState: SyncState,
	phase: Types.Phase,
	endsAt: number,
	serverOffset: number,
	notices: { any },
	onVote: (BillId, VoteSide?, number) -> (),
	onProposeBill: ((requestId: string, policyId: PolicyId, level: number) -> ())?,
}

local PoliticsTab = {}

local PAD = 12
local HEADER = 24
local ROW = 28
local SECTION = 20
local WIDTH = 392
local CARD_HEIGHT = 104

-- One request id per proposal click. The server echoes it in a refusal, so
-- the form can show the matching Notice instead of a generic error.
local requestCounter = 0

local function syncLabel(syncState: SyncState): (string, string)
	if syncState == "pending" then
		return "saving", "warning"
	elseif syncState == "rejected" then
		return "rejected", "danger"
	end
	return "saved", "success"
end

local function firstEnabled(policies: { [PolicyId]: number }): PolicyId?
	for _, rawPolicyId in Types.POLICY_IDS do
		local policyId: PolicyId = rawPolicyId :: any
		if policies[policyId] ~= nil then
			return policyId
		end
	end
	return nil
end

-- The legal target levels for one bill (GAME_DESIGN 7.3) come from the same
-- helper the server's validation uses, so the rule lives in one place.
local function defaultTarget(policyId: PolicyId, current: number): number
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

-- The seconds left in the Window from the same server clock as the
-- Countdown (NETWORKING 5). The panel only needs the proposal cutoff, so it
-- ticks once a second instead of on every frame like the top bar's clock.
local function useSecondsLeft(endsAt: number, serverOffset: number): number
	local now, setNow = React.useState(os.clock())
	React.useEffect(function()
		local cancelled = false
		task.spawn(function()
			while not cancelled do
				task.wait(1)
				if not cancelled then
					setNow(os.clock())
				end
			end
		end)
		return function()
			cancelled = true
		end
	end, {})
	return math.max(0, endsAt - (now + serverOffset))
end

function PoliticsTab.render(props: PoliticsTabProps): any
	local theme = ThemeContext.useTheme()
	local view = props.view
	local viewer: ClassId = view.viewer :: any
	local own = view.own
	local entry = ConfigClasses.entries[viewer]
	local secondsLeft = useSecondsLeft(props.endsAt, props.serverOffset)

	local initialPolicy: PolicyId? = firstEnabled(view.policies) :: any
	local selected, setSelected = React.useState(initialPolicy)
	local currentLevel = if selected ~= nil then view.policies[selected] else nil
	local target, setTarget = React.useState(
		if initialPolicy ~= nil
			then defaultTarget(initialPolicy, view.policies[initialPolicy])
			else 0
	)

	React.useEffect(function()
		if selected ~= nil then
			setTarget(defaultTarget(selected, view.policies[selected]))
		end
	end, { selected, currentLevel } :: { any })

	-- "" means no proposal is in flight; a request id is never empty.
	local pendingId, setPendingId = React.useState("")
	React.useEffect(function()
		setPendingId("")
	end, { view.day })

	local ownProposed = false
	for _, bill in view.bills do
		if bill.proposer == viewer then
			ownProposed = true
			break
		end
	end

	local refusal: any = nil
	if pendingId ~= "" then
		for index = #props.notices, 1, -1 do
			local notice = props.notices[index]
			if notice.requestId == pendingId then
				refusal = notice
				break
			end
		end
	end

	local function proposeReason(): string?
		if props.phase ~= "Window" then
			return "the Window is closed"
		end
		if props.onProposeBill == nil then
			return "proposals are not connected"
		end
		if selected == nil then
			return "no policy track is active"
		end
		if ownProposed then
			return "your class already proposed a bill today"
		end
		if #view.bills >= ConfigPolicies.bills.maxLive then
			return "the table is full"
		end
		local cost = if viewer == "State" then 0 else ConfigPolicies.bills.proposeCost
		if own.influence < cost then
			return "not enough Influence to propose"
		end
		if secondsLeft <= ConfigPolicies.bills.cutoffSeconds then
			return "proposals are closed"
		end
		if target == currentLevel then
			return "choose a different level"
		end
		if pendingId ~= "" and refusal == nil then
			return "sending..."
		end
		return nil
	end

	local reason = proposeReason()

	local function propose()
		if props.onProposeBill == nil or selected == nil or target == currentLevel then
			return
		end
		requestCounter += 1
		local requestId = string.format("bill-%d", requestCounter)
		setPendingId(requestId)
		props.onProposeBill(requestId, selected, target)
	end

	local function selectPolicy(policyId: PolicyId)
		if view.policies[policyId] ~= nil then
			setSelected(policyId)
		end
	end

	local children: { any } = {}
	local syncText, syncTone = syncLabel(props.syncState)

	table.insert(
		children,
		React.createElement(Text.render, {
			text = "Politics",
			tone = "muted",
			size = "xs",
			uppercase = true,
			position = UDim2.fromOffset(PAD, 0),
			size2 = UDim2.fromOffset(120, HEADER),
		})
	)
	table.insert(
		children,
		React.createElement(Text.render, {
			text = syncText,
			tone = syncTone :: any,
			size = "xs",
			align = Enum.TextXAlignment.Right,
			position = UDim2.new(1, -PAD, 0, 0),
			anchorPoint = Vector2.new(1, 0),
			size2 = UDim2.fromOffset(100, HEADER),
		})
	)

	local body: { any } = {}
	local y = 0

	table.insert(
		body,
		React.createElement(PolicyBoard.render, {
			policies = view.policies,
			selected = selected,
			onSelect = selectPolicy,
			position = UDim2.fromOffset(0, y),
		})
	)
	y += PolicyBoard.HEIGHT + 6

	-- The propose form. The client previews the legal levels, the cost, the
	-- one-bill rule and the cutoff; the server re-checks every one of them.
	table.insert(
		body,
		React.createElement(Text.render, {
			text = "Propose a bill",
			tone = "muted",
			size = "xs",
			uppercase = true,
			position = UDim2.fromOffset(0, y),
			size2 = UDim2.fromOffset(WIDTH, SECTION),
		})
	)
	y += SECTION

	local policyName = if selected ~= nil
		then ConfigPolicies.tracks[selected].name
		else "no active track"
	local currentText = if selected ~= nil and currentLevel ~= nil
		then levelLabel(selected, currentLevel)
		else "-"
	local targetText = if selected ~= nil then levelLabel(selected, target) else "-"
	table.insert(
		body,
		React.createElement(Text.render, {
			text = string.format("%s: %s -> %s", policyName, currentText, targetText),
			tone = if selected ~= nil then "secondary" else "muted",
			size = "s",
			position = UDim2.fromOffset(0, y),
			size2 = UDim2.fromOffset(WIDTH, 20),
		})
	)
	y += 20

	local low, high = 0, 0
	if selected ~= nil then
		low, high = Bills.targetBounds(selected, currentLevel or 0)
	end
	table.insert(
		body,
		React.createElement(Stepper.render, {
			value = target,
			min = low,
			max = high,
			disabled = selected == nil or props.phase ~= "Window" or pendingId ~= "" or ownProposed,
			position = UDim2.fromOffset(0, y),
			onChange = setTarget,
		})
	)
	table.insert(
		body,
		React.createElement(Button.render, {
			text = "Propose",
			variant = "primary",
			size = "s",
			disabled = reason ~= nil,
			position = UDim2.fromOffset(WIDTH - 82, y),
			size2 = UDim2.fromOffset(82, 26),
			onClick = propose,
		})
	)
	y += ROW + 2

	local cost = if viewer == "State" then 0 else ConfigPolicies.bills.proposeCost
	local costText = if cost == 0
		then "State proposes for free"
		else string.format("Cost: %d Influence (you hold %d)", cost, own.influence)
	local statusText = if refusal ~= nil
		then refusal.message
		elseif pendingId ~= "" and ownProposed then "proposal accepted"
		elseif reason ~= nil then reason
		else costText
	local statusTone: any = if refusal ~= nil
		then "danger"
		elseif pendingId ~= "" and ownProposed then "success"
		elseif reason ~= nil then "muted"
		else "secondary"
	table.insert(
		body,
		React.createElement(Text.render, {
			text = statusText,
			tone = statusTone,
			size = "xs",
			position = UDim2.fromOffset(0, y),
			size2 = UDim2.new(1, 0, 0, 18),
		})
	)
	y += 18
	table.insert(
		body,
		React.createElement(Text.render, {
			text = "Proposals close "
				.. tostring(ConfigPolicies.bills.cutoffSeconds)
				.. "s before the Closing Bell",
			tone = "muted",
			size = "xs",
			position = UDim2.fromOffset(0, y),
			size2 = UDim2.new(1, 0, 0, 16),
		})
	)
	y += 20

	-- The live bills. The ballots are secret: the panel only shows the
	-- viewer's own side and committed Influence.
	table.insert(
		body,
		React.createElement(Text.render, {
			text = "Live bills",
			tone = "muted",
			size = "xs",
			uppercase = true,
			position = UDim2.fromOffset(0, y),
			size2 = UDim2.fromOffset(WIDTH, SECTION),
		})
	)
	y += SECTION

	if #view.bills == 0 then
		table.insert(
			body,
			React.createElement(Text.render, {
				text = "No bills on the table",
				tone = "muted",
				size = "s",
				position = UDim2.fromOffset(0, y),
				size2 = UDim2.fromOffset(WIDTH, ROW),
			})
		)
		y += ROW
	else
		local sorted: { Bill } = {}
		for _, bill in view.bills do
			table.insert(sorted, bill)
		end
		table.sort(sorted, function(a, b)
			return a.id < b.id
		end)
		for _, bill in sorted do
			local vote = props.draft.votes[bill.id]
			local side: VoteSide? = if vote ~= nil then vote.side else nil
			local influence = if vote ~= nil then vote.influence else 0
			local activeYes = side == "yes"
			local activeNo = side == "no"
			local baseVotes = entry.baseVotes
			local weightText = if vote ~= nil
				then string.format(
					"Base %d + %d Influence = %d votes",
					baseVotes,
					influence,
					baseVotes + influence
				)
				else "No vote yet - your class abstains"
			local canVote = props.phase == "Window"

			local card = React.createElement(React.Fragment, nil, {
				React.createElement(Text.render, {
					text = "Your vote",
					tone = "muted",
					size = "xs",
					position = UDim2.fromOffset(PAD, 8),
					size2 = UDim2.fromOffset(70, 26),
				}),
				React.createElement(Button.render, {
					text = "Yes",
					variant = if activeYes then "primary" else "secondary",
					size = "s",
					disabled = not canVote,
					position = UDim2.fromOffset(PAD + 74, 8),
					size2 = UDim2.fromOffset(54, 26),
					onClick = function()
						if activeYes then
							props.onVote(bill.id, nil, 0)
						else
							props.onVote(bill.id, "yes", influence)
						end
					end,
				}),
				React.createElement(Button.render, {
					text = "No",
					variant = if activeNo then "primary" else "secondary",
					size = "s",
					disabled = not canVote,
					position = UDim2.fromOffset(PAD + 132, 8),
					size2 = UDim2.fromOffset(54, 26),
					onClick = function()
						if activeNo then
							props.onVote(bill.id, nil, 0)
						else
							props.onVote(bill.id, "no", influence)
						end
					end,
				}),
				React.createElement(Stepper.render, {
					value = influence,
					min = 0,
					max = math.min(own.influence, ConfigClasses.influenceCap),
					disabled = side == nil or not canVote,
					position = UDim2.fromOffset(PAD + 200, 8),
					onChange = function(value)
						if side ~= nil then
							props.onVote(bill.id, side, value)
						end
					end,
				}),
				React.createElement(Text.render, {
					text = weightText,
					tone = if vote ~= nil then "secondary" else "muted",
					size = "xs",
					position = UDim2.fromOffset(PAD, 42),
					size2 = UDim2.new(1, -PAD * 2, 0, 18),
				}),
				React.createElement(Text.render, {
					text = "Ballots are secret until the Closing Bell",
					tone = "muted",
					size = "xs",
					position = UDim2.fromOffset(PAD, 60),
					size2 = UDim2.new(1, -PAD * 2, 0, 16),
				}),
			})

			local title = string.format(
				"%s  %s -> %s",
				ConfigPolicies.tracks[bill.policyId].name,
				levelLabel(bill.policyId, view.policies[bill.policyId] or 0),
				levelLabel(bill.policyId, bill.level)
			)
			table.insert(
				body,
				React.createElement(Card.render, {
					title = title,
					subtitle = bill.proposer,
					tone = string.lower(bill.proposer) :: any,
					size = UDim2.fromOffset(WIDTH, CARD_HEIGHT),
					position = UDim2.fromOffset(0, y),
				}, card)
			)
			y += CARD_HEIGHT + 8
		end
	end

	local contentHeight = y + PAD
	local bodyChildren: { any } = {
		React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, contentHeight),
		}, body),
	}

	table.insert(
		children,
		React.createElement("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(PAD, HEADER),
			Size = UDim2.new(1, -PAD * 2, 1, -(HEADER + PAD)),
			CanvasSize = UDim2.new(1, 0, 0, contentHeight),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = theme.colors["line.strong"],
		}, bodyChildren)
	)

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, children)
end

return PoliticsTab
