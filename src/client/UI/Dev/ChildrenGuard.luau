--!strict
-- Dev-time guard for react-lua issue #42 and stray text children.
--
-- React-Lua shows "UNIMPLEMENTED ERROR: createTextInstance" for two reasons:
--   1. A string or number is rendered as a child (Roblox has no text nodes).
--   2. A plain table of children sits inside another children table (or next
--      to other child arguments), and React-Lua writes a `key` field into it,
--      which is then read as a text child. This is issue #42.
--
-- install() wraps React.createElement and warns, with the call site, whenever
-- one of those patterns is used, so the error names a line instead of a symptom.
-- Use it in Studio only (see the fix-react-unimplemented-error skill).

local ChildrenGuard = {}

export type Sink = (message: string, traceback: string) -> ()

local function isElement(value: any): boolean
	return typeof(value) == "table" and (value :: any)["$$typeof"] ~= nil
end

local function describeType(elementType: any): string
	local kind = typeof(elementType)
	if kind == "string" then
		return elementType
	elseif kind == "function" then
		local ok, name = pcall(function(): any return debug.info(elementType :: any, "n") end)
		if ok and type(name) == "string" and name ~= "" then return name end
		return "<anonymous component>"
	elseif kind == "table" then
		local named = (elementType :: any).name or (elementType :: any).displayName
		if type(named) == "string" then return named end
	end
	return tostring(elementType)
end

local function checkContainer(container: any, owner: string, problems: { string })
	for key, child in pairs(container) do
		local kind = typeof(child)
		if kind == "string" or kind == "number" then
			table.insert(
				problems,
				`<{owner}>: child "{tostring(key)}" is a {kind} ({tostring(child)}). `
					.. "Put text in a TextLabel's Text prop; Roblox has no text nodes."
			)
		elseif kind == "table" and not isElement(child) then
			table.insert(
				problems,
				`<{owner}>: child "{tostring(key)}" is a raw table inside a children table `
					.. "(react-lua issue #42). Wrap it: "
					.. "React.createElement(React.Fragment, nil, <table>)."
			)
		end
	end
end

-- Pure check. Returns a list of problems (empty when everything is fine).
function ChildrenGuard.check(elementType: any, props: any, ...: any): { string }
	local problems: { string } = {}
	local owner = describeType(elementType)

	if type(props) == "table" and type((props :: any).children) == "table" then
		local propChildren = (props :: any).children
		if not isElement(propChildren) then checkContainer(propChildren, owner, problems) end
	end

	local count = select("#", ...)
	if count == 1 then
		local only = ...
		local kind = typeof(only)
		if kind == "string" or kind == "number" then
			table.insert(
				problems,
				`<{owner}>: a {kind} was passed as the child ({tostring(only)}).`
			)
		elseif kind == "table" and not isElement(only) then
			checkContainer(only, owner, problems)
		end
	elseif count > 1 then
		for index = 1, count do
			local child = select(index, ...)
			local kind = typeof(child)
			if kind == "string" or kind == "number" then
				table.insert(
					problems,
					`<{owner}>: child argument #{index} is a {kind} ({tostring(child)}).`
				)
			elseif kind == "table" and not isElement(child) then
				table.insert(
					problems,
					`<{owner}>: child argument #{index} is a raw table next to other child arguments `
						.. "(react-lua issue #42). Put the table of children alone, or wrap it in a Fragment."
				)
			end
		end
	end

	return problems
end

local original: any = nil
local installedOn: any = nil

-- Wrap React.createElement. Returns false when React is read-only.
function ChildrenGuard.install(React: any, sink: Sink?): boolean
	if original ~= nil then return true end
	local seen: { [string]: boolean } = {}
	local report: Sink = sink
		or function(message: string, traceback: string)
			warn(`[ChildrenGuard] {message}\n{traceback}`)
		end

	local base = React.createElement
	local function guarded(elementType: any, props: any, ...: any)
		local problems = ChildrenGuard.check(elementType, props, ...)
		if #problems > 0 then
			local trace = debug.traceback("", 2)
			for _, message in problems do
				local key = message .. trace
				if not seen[key] then
					seen[key] = true
					report(message, trace)
				end
			end
		end
		return base(elementType, props, ...)
	end

	local ok = pcall(function() React.createElement = guarded end)
	if not ok then
		warn("[ChildrenGuard] React.createElement is read-only; guard not installed.")
		return false
	end
	original = base
	installedOn = React
	return true
end

function ChildrenGuard.uninstall()
	if original ~= nil and installedOn ~= nil then
		pcall(function() installedOn.createElement = original end)
	end
	original = nil
	installedOn = nil
end

return ChildrenGuard
