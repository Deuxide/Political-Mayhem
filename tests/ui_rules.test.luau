--!nocheck
local Lib = require("./lib")
local UiRules = require("./ui_rules")

local M = {}

function M.run()
	print("ui rules")

	Lib.test("flags every forbidden pattern in the bad fixture", function()
		local text = UiRules.format(UiRules.scan("tests/fixtures/ui_bad"))
		Lib.contains(text, "no-rounded-corners")
		Lib.contains(text, "no-shadows")
		Lib.contains(text, "tokens-only")
		Lib.contains(text, "gradient-only-in-Surface")
		Lib.contains(text, "react-lua-issue-42")
	end)

	Lib.test("accepts the good fixture (Theme tokens, Surface white base, Fragment)", function()
		local findings = UiRules.scan("tests/fixtures/ui_good")
		Lib.eq(#findings, 0, UiRules.format(findings))
	end)
end

return M
