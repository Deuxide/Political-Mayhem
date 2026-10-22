--!strict
-- Countdown: the time left in the current phase, driven by the server's
-- clock (NETWORKING section 5). The client never keeps its own countdown: it
-- compares the server's `endsAt` with the server's time and the offset the
-- store keeps.
--
-- The colors are the countdown states of UI_SPEC section 5: normal, warning
-- at 20 s, urgent at 10 s.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Text = require(script.Parent.Parent.Primitives.Text)

export type CountdownProps = {
	endsAt: number, -- server time
	serverOffset: number, -- serverTime minus the local clock
	label: string?,
}

local Countdown = {}

local WARNING_SECONDS = 20
local URGENT_SECONDS = 10

function Countdown.render(props: CountdownProps): any
	local now, setNow = React.useState(os.clock())

	-- The clock ticks so the countdown moves; the time itself comes from the
	-- server (the offset is what the store keeps).
	React.useEffect(function()
		local connection
		connection = game:GetService("RunService").Heartbeat:Connect(function()
			setNow(os.clock())
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	local secondsLeft = math.max(0, math.floor(props.endsAt - (now + props.serverOffset)))
	local tone = if secondsLeft <= URGENT_SECONDS
		then "danger"
		elseif secondsLeft <= WARNING_SECONDS then "warning"
		else "primary"

	return React.createElement(Text.render, {
		text = if props.label ~= nil
			then props.label
			else string.format("%02d:%02d", math.floor(secondsLeft / 60), secondsLeft % 60),
		tone = tone :: any,
		size = "m",
		size2 = UDim2.fromOffset(90, 24),
	})
end

return Countdown
