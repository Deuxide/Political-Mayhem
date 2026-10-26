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
	require("./step_production.test"),
	require("./step_market.test"),
	require("./step_taxes.test"),
	require("./step_public_services.test"),
	require("./step_upkeep.test"),
	require("./step_lock_drafts.test"),
	require("./scenario_s1.test"),
	require("./pipeline.test"),
	require("./step_lobby.test"),
	require("./step_influence.test"),
	require("./bills_ops.test"),
	require("./step_bills.test"),
	require("./scenario_s2.test"),
	require("./scenario_s3.test"),
	require("./transfers.test"),
	require("./trade_ops.test"),
	require("./promises_ops.test"),
	require("./step_promises.test"),
	require("./scoring.test"),
	require("./victory_check.test"),
	require("./difficulty_flags.test"),
	require("./player_view.test"),
	require("./alliances_ops.test"),
	require("./scenario_s4.test"),
	require("./scenario_s5.test"),
	require("./scenario_s6.test"),
	require("./gate_g1.test"),
	require("./net_remotes.test"),
	require("./net_validate.test"),
	require("./client_store.test"),
	require("./client_report.test"),
	require("./lobby_service.test"),
	require("./match_service.test"),
	require("./handlers.test"),
	require("./replication.test"),
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
