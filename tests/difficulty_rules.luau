--!nocheck
-- Lint-style rule from AGENTS.md / ROADMAP M5-T3: game code never compares
-- difficulty names — it reads the typed flags through RuleSet. The names
-- live only in the difficulty matrix (Config/Difficulty) and its enum
-- mirror (Game/Types); everywhere else a quoted name or a comparison
-- against a difficulty field is a finding.

local fs = require("@lune/fs")

local DifficultyRules = {}

export type Finding = { path: string, line: number, rule: string, text: string }

local ALLOWED = {
	["src/shared/Config/Difficulty.luau"] = true,
	["src/shared/Game/Types.luau"] = true,
}

local NAMES = { '"Easy"', '"Normal"', '"Hard"', '"Extreme"' }

local function stripComment(line: string): string
	return (string.gsub(line, "%-%-.*$", ""))
end

local function check(path: string, lineNumber: number, line: string, findings: { Finding })
	if ALLOWED[path] then
		return
	end
	local code = stripComment(line)
	if code == "" then
		return
	end

	local function add(rule: string)
		table.insert(findings, { path = path, line = lineNumber, rule = rule, text = line })
	end

	for _, name in NAMES do
		if string.find(code, name, 1, true) then
			add("difficulty-name-literal: the names live in Config/Difficulty; read a RuleSet flag")
			break
		end
	end
	if string.find(code, "difficulty%s*[=~]=") then
		add("difficulty-comparison: read a RuleSet flag, never compare the difficulty field")
	end
end

local function walk(dir: string, findings: { Finding })
	for _, entry in ipairs(fs.readDir(dir)) do
		local full = `{dir}/{entry}`
		if fs.isDir(full) then
			if entry ~= "Packages" then
				walk(full, findings)
			end
		elseif string.match(entry, "%.luau$") or string.match(entry, "%.fixture$") then
			local number = 0
			for line in string.gmatch(fs.readFile(full) .. "\n", "(.-)\n") do
				number += 1
				check(full, number, line, findings)
			end
		end
	end
end

function DifficultyRules.scan(root: string): { Finding }
	local findings: { Finding } = {}
	if fs.isDir(root) then
		walk(root, findings)
	end
	return findings
end

function DifficultyRules.format(findings: { Finding }): string
	local lines = {}
	for _, f in findings do
		table.insert(lines, `{f.path}:{f.line}  [{f.rule}]  {string.gsub(f.text, "^%s+", "")}`)
	end
	return table.concat(lines, "\n")
end

return DifficultyRules
