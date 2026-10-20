--!nocheck
-- Lint-style rules from docs/UI_STYLE.md and the react-lua-ui skill.
-- scan(root) returns a list of findings; an empty list means clean.

local fs = require("@lune/fs")

local UiRules = {}

export type Finding = { path: string, line: number, rule: string, text: string }

local function inTheme(path: string): boolean return string.find(path, "/Theme/", 1, true) ~= nil end

local function isSurface(path: string): boolean
	return string.find(path, "/Primitives/Surface", 1, true) ~= nil
end

local function stripComment(line: string): string return (string.gsub(line, "%-%-.*$", "")) end

local RAW_STYLE = {
	"Color3%.fromRGB",
	"Color3%.new",
	"Color3%.fromHSV",
	"Color3%.fromHex",
	"Enum%.Font",
	"Font%.new",
	"Font%.fromEnum",
	"Font%.fromName",
}

local function check(path: string, lineNumber: number, line: string, findings: { Finding })
	local code = stripComment(line)
	if code == "" then return end
	local function add(rule: string)
		table.insert(findings, { path = path, line = lineNumber, rule = rule, text = line })
	end

	if string.find(code, "UICorner", 1, true) then
		add("no-rounded-corners: UICorner is forbidden")
	end
	if string.find(code, "Shadow", 1, true) or string.find(code, "Glow", 1, true) then
		add("no-shadows: shadows and glows are forbidden")
	end
	if string.find(code, "UIGradient", 1, true) and not inTheme(path) and not isSurface(path) then
		add("gradient-only-in-Surface: only Primitives/Surface may create UIGradient")
	end
	if not inTheme(path) then
		for _, pattern in RAW_STYLE do
			if string.find(code, pattern) then
				local whiteBase = isSurface(path)
					and string.find(code, "Color3%.new%(%s*1%s*,%s*1%s*,%s*1%s*%)")
				if not whiteBase then
					add("tokens-only: raw color/font outside UI/Theme (" .. pattern .. ")")
				end
				break
			end
		end
	end
	if
		string.match(code, "^%s*[%w_]+%s*=%s*props%.children%s*,?%s*$")
		or string.match(code, "^%s*[%w_]+%s*=%s*children%s*,?%s*$")
	then
		add(
			"react-lua-issue-42: raw children table nested in a children table; wrap in React.Fragment"
		)
	end
end

local function walk(dir: string, findings: { Finding })
	for _, entry in ipairs(fs.readDir(dir)) do
		local full = `{dir}/{entry}`
		if fs.isDir(full) then
			if entry ~= "Packages" then walk(full, findings) end
		elseif string.match(entry, "%.luau$") or string.match(entry, "%.fixture$") then
			local number = 0
			for line in string.gmatch(fs.readFile(full) .. "\n", "(.-)\n") do
				number += 1
				check(full, number, line, findings)
			end
		end
	end
end

function UiRules.scan(root: string): { Finding }
	local findings: { Finding } = {}
	if fs.isDir(root) then walk(root, findings) end
	return findings
end

function UiRules.format(findings: { Finding }): string
	local lines = {}
	for _, f in findings do
		table.insert(lines, `{f.path}:{f.line}  [{f.rule}]  {string.gsub(f.text, "^%s+", "")}`)
	end
	return table.concat(lines, "\n")
end

return UiRules
