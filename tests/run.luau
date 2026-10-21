--!nocheck
-- Test runner. Run from the project root:  lune run tests/run
-- Add a line to `suites` for every new *.test.luau file.

local process = require("@lune/process")
local Lib = require("./lib")
local UiRules = require("./ui_rules")

local suites = {
	require("./loader.test"),
	require("./shared_smoke.test"),
	require("./code_model.test"),
	require("./serialization.test"),
	require("./config.test"),
	require("./rng.test"),
	require("./state_factory.test"),
	require("./state_ops.test"),
	require("./step_build.test"),
	require("./children_guard.test"),
	require("./ui_rules.test"),
}

for _, suite in suites do
	suite.run()
end

-- Real UI code must satisfy docs/UI_STYLE.md (skipped until src/client exists).
print("ui rules on src/client")
local findings = UiRules.scan("src/client")
Lib.test("src/client has no UI rule violations", function()
	if #findings > 0 then
		error("\n" .. UiRules.format(findings), 0)
	end
end)

if Lib.summary() > 0 then
	process.exit(1)
end
