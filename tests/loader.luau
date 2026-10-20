--!nocheck
-- Test module loader for Lune.
--
-- Game modules use Roblox-style requires: require(script.Parent.Types).
-- Lune has no `script` object, so this loader builds a virtual instance tree
-- from a source folder (following Rojo's naming rules) and runs the REAL files
-- unchanged. Tests therefore exercise the actual code in src/, not copies.
--
-- The whole tree is scanned eagerly at mount time because Lune's fs calls
-- yield, and yielding inside a metamethod (__index) is not allowed.
--
--   local Loader = require("./loader")
--   local shared = Loader.mount("src/shared")        -- like ReplicatedStorage.Shared
--   local Rng = Loader.require(shared.Game.Rng)

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Loader = {}

local SUFFIXES = { ".server.luau", ".client.luau", ".luau", ".lua" } -- longest first
local INIT_NAMES = { "init.luau", "init.lua", "init.server.luau", "init.client.luau" }

local nodeMeta = {}
local cache: { [string]: any } = {}

nodeMeta.__index = function(self, key)
	local child = rawget(self, "_children")[key]
	if child == nil then
		error(`'{tostring(key)}' is not a valid member of {rawget(self, "Name")}`, 2)
	end
	return child
end

local function stripSuffix(fileName: string): string?
	for _, suffix in ipairs(SUFFIXES) do
		if string.sub(fileName, -#suffix) == suffix then
			return string.sub(fileName, 1, #fileName - #suffix)
		end
	end
	return nil
end

local function isInit(fileName: string): boolean
	for _, name in ipairs(INIT_NAMES) do
		if fileName == name then return true end
	end
	return false
end

local function scan(dirPath: string, name: string, parent: any)
	local node = setmetatable({
		Name = name,
		Parent = parent,
		_file = nil, -- set when the folder has an init file (it becomes a ModuleScript)
		_children = {},
	}, nodeMeta)

	for _, entry in ipairs(fs.readDir(dirPath)) do
		local full = `{dirPath}/{entry}`
		if fs.isDir(full) then
			node._children[entry] = scan(full, entry, node)
		elseif isInit(entry) then
			rawset(node, "_file", full)
		else
			local base = stripSuffix(entry)
			if base then
				node._children[base] = setmetatable({
					Name = base,
					Parent = node,
					_file = full,
					_children = {},
				}, nodeMeta)
			end
		end
	end
	return node
end

-- Mount a source folder as a virtual Folder instance.
function Loader.mount(path: string) return scan(path, path, nil) end

function Loader.require(node)
	local file = rawget(node, "_file")
	if not file then error(`{rawget(node, "Name")} is a Folder, not a ModuleScript`, 2) end
	if cache[file] ~= nil then return cache[file] end

	local env = setmetatable({
		script = node,
		require = function(target)
			if type(target) == "table" and getmetatable(target) == nodeMeta then
				return Loader.require(target)
			end
			error("loader: unsupported require target (use script-relative paths)", 2)
		end,
	}, { __index = _G })

	local chunk = luau.load(fs.readFile(file), { debugName = file, environment = env })
	local result = chunk()
	cache[file] = result
	return result
end

function Loader.clearCache() table.clear(cache) end

return Loader
