--!strict
-- CityViewport: the React host for the 3D city. React owns the ViewportFrame's
-- lifecycle; CityView owns the camera, WorldModel and line Instances inside it.
-- The component passes the replicated PlayerView plus the report/phase needed
-- for the Reveal reaction, so the city stays a pure function of what the server
-- allowed this player to see.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Game.Types)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)
local CityView = require(script.Parent.Parent.Parent.City.CityView)
local RevealEvents = require(script.Parent.Parent.Parent.State.RevealEvents)

export type CityViewportProps = {
	view: Types.PlayerView?,
	reveal: Remotes.RevealReportPayload?,
	phase: Types.Phase?,
	day: number?,
	matchEnded: boolean?,
}

local CityViewport = {}

function CityViewport.render(props: CityViewportProps): any
	local theme = ThemeContext.useTheme()
	local viewportRef = React.useRef(nil :: any)
	local cityRef = React.useRef(nil :: any)
	local pendingRevealRef = React.useRef(nil :: any)

	React.useEffect(function()
		local viewport = viewportRef.current
		if viewport == nil then
			return
		end
		local city = CityView.new(viewport, theme)
		cityRef.current = city
		return function()
			cityRef.current = nil
			city:destroy()
		end
	end, { theme } :: { any })

	-- The phase clock, not a local timer, selects the day/dusk/night look and the
	-- camera. The effect runs only when the phase or Day changes.
	React.useEffect(function()
		local city = cityRef.current
		if city ~= nil then
			city:setPhase(props.phase or "Window", props.day)
		end
	end, { props.phase, props.day, theme } :: { any })

	-- Keep the report until the Evening Report closes. The report overlay covers
	-- the city (UI_SPEC 2), so playing its events under the overlay would hide
	-- the reaction; the city plays them when the next Window opens and the
	-- report is gone. A report can arrive before its view snapshot, and
	-- CityView parks a NewBuild until sync has created the line.
	React.useEffect(function()
		if props.matchEnded == true then
			pendingRevealRef.current = nil
		elseif props.reveal ~= nil then
			pendingRevealRef.current = props.reveal
		end
	end, { props.reveal, props.matchEnded } :: { any })

	React.useEffect(function()
		local city = cityRef.current
		if city == nil then
			return
		end
		city:sync(props.view)
		if props.phase == "Window" then
			local report = pendingRevealRef.current
			if report ~= nil then
				pendingRevealRef.current = nil
				city:playReveal(RevealEvents.build(report), report.day)
			end
		end
	end, { props.view, props.phase, theme } :: { any })

	return React.createElement("ViewportFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = 1,
		ref = viewportRef,
	})
end

return CityViewport
