--!strict
-- Client entry point: mounts the React root.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local React = require(ReplicatedStorage.Packages.react)

-- Temporary diagnostic for the unsupported primitive-text host operation.
local originalCreateElement = React.createElement
local function scanReactChild(
	child: any,
	path: string,
	seen: { [any]: boolean },
	parentType: string,
	source: string,
	line: number
)
	local childType = type(child)
	if childType == "string" or childType == "number" then
		warn(
			string.format(
				"[ReactTextChildDiagnostic] primitive child %q (%s) in %s at %s:%d, child path %s\n%s",
				tostring(child),
				childType,
				parentType,
				source,
				line,
				path,
				debug.traceback("", 2)
			)
		)
	elseif childType == "table" and not seen[child] then
		seen[child] = true
		if child["$$typeof"] == nil then
			for key, nestedChild in child do
				scanReactChild(
					nestedChild,
					path .. "." .. tostring(key),
					seen,
					parentType,
					source,
					line
				)
			end
		end
	end
end

React.createElement = function(type_, props, ...)
	local source, line = debug.info(2, "sl")
	local parentType = if type(type_) == "string"
		then type_
		elseif type(type_) == "function" then debug.info(type_, "n") or "<function>"
		else tostring(type_)
	local seen = {}
	local childCount = select("#", ...)
	if childCount > 0 then
		for index = 1, childCount do
			scanReactChild(
				select(index, ...),
				"child[" .. index .. "]",
				seen,
				parentType,
				source,
				line
			)
		end
	elseif props and props.children ~= nil then
		scanReactChild(props.children, "props.children", seen, parentType, source, line)
	end
	return originalCreateElement(type_, props, ...)
end

local ReactRoblox = require(ReplicatedStorage.Packages["react-roblox"])
local App = require(script.UI.App)

local root = ReactRoblox.createRoot(Players.LocalPlayer.PlayerGui)
root:render(React.createElement(App))

print("Client booted")
