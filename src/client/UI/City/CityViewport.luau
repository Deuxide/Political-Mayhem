--!strict
-- CityViewport: the React host for the 3D city. React owns the ViewportFrame's
-- lifecycle; CityView owns the camera, WorldModel and line Instances inside it.
-- The component passes the replicated PlayerView down and nothing else, so the
-- city stays a pure function of what the server allowed this player to see.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Game.Types)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)
local CityView = require(script.Parent.Parent.Parent.City.CityView)

export type CityViewportProps = {
	view: Types.PlayerView?,
}

local CityViewport = {}

function CityViewport.render(props: CityViewportProps): any
	local theme = ThemeContext.useTheme()
	local viewportRef = React.useRef(nil :: any)
	local cityRef = React.useRef(nil :: any)

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

	React.useEffect(function()
		local city = cityRef.current
		if city ~= nil then
			city:sync(props.view)
		end
	end, { props.view, theme } :: { any })

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
