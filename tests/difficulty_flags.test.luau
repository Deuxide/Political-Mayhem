--!nocheck
-- Difficulty flags wired everywhere (M5-T3; GAME_DESIGN 12): game code reads
-- the typed flags through RuleSet and never compares difficulty names, and
-- every flag in the difficulty matrix has a RuleSet accessor that returns the
-- configured value. The state the factory builds carries exactly the policy
-- tracks the difficulty enables. The src scan and the fixtures exercise the
-- real scanners and the real RuleSet/StateFactory via tests/loader.luau.

local Lib = require("./lib")
local Loader = require("./loader")
local DifficultyRules = require("./difficulty_rules")

local M = {}

local SEATS: { [string]: { string } } = {
	Working = { "Seat-Working" },
	Middle = { "Seat-Middle" },
	Capitalist = { "Seat-Capitalist" },
	State = { "Seat-State" },
}

-- The two names that do not follow the switch's own name: the config lists
-- the enabled policies as an array, the accessor asks per policy (7.3, D-041).
local ACCESSOR: { [string]: string } = {
	policiesEnabled = "isPolicyEnabled",
}

function M.run()
	print("difficulty flags")
	local shared = Loader.mount("src/shared")
	local Types = Loader.require(shared.Game.Types)
	local RuleSet = Loader.require(shared.Game.RuleSet)
	local StateFactory = Loader.require(shared.Game.State.StateFactory)
	local ConfigDifficulty = Loader.require(shared.Config.Difficulty)

	Lib.test("the lint flags a name literal and a difficulty comparison", function()
		local findings = DifficultyRules.scan("tests/fixtures/difficulty_bad")
		local text = DifficultyRules.format(findings)
		Lib.contains(text, "difficulty-name-literal", text)
		Lib.contains(text, "difficulty-comparison", text)
	end)

	Lib.test("the lint accepts flag reads and names in comments", function()
		local findings = DifficultyRules.scan("tests/fixtures/difficulty_good")
		Lib.eq(#findings, 0, DifficultyRules.format(findings))
	end)

	Lib.test("no src file compares difficulty names (M5-T3)", function()
		local findings = DifficultyRules.scan("src")
		Lib.eq(#findings, 0, DifficultyRules.format(findings))
	end)

	Lib.test(
		"every difficulty flag has a RuleSet accessor that returns the config value (12)",
		function()
			for _, difficulty in Types.DIFFICULTIES do
				local ruleSet = RuleSet.new(difficulty)
				local entry = ConfigDifficulty[difficulty]
				Lib.truthy(entry ~= nil, `Config has an entry for {difficulty}`)

				for key, value in entry do
					if key ~= "policiesEnabled" then
						local accessor: string = ACCESSOR[key] or key
						Lib.eq(
							type(ruleSet[accessor]),
							"function",
							`{difficulty}: RuleSet.{accessor} exists for Config {key}`
						)
						Lib.eq(
							ruleSet[accessor](ruleSet),
							value,
							`{difficulty}: RuleSet:{accessor}() returns Config {key}`
						)
					end
				end

				-- the array flag, asked per policy
				for _, policyId in Types.POLICY_IDS do
					local expected = false
					for _, enabled in entry.policiesEnabled do
						if enabled == policyId then
							expected = true
						end
					end
					Lib.eq(
						ruleSet:isPolicyEnabled(policyId),
						expected,
						`{difficulty}: isPolicyEnabled({policyId}) matches Config`
					)
				end
			end
		end
	)

	Lib.test("the state carries exactly the policy tracks the difficulty enables (12)", function()
		for _, difficulty in Types.DIFFICULTIES do
			local ruleSet = RuleSet.new(difficulty)
			local state = StateFactory.create(difficulty, SEATS, 41)
			for _, policyId in Types.POLICY_IDS do
				Lib.eq(
					state.policies[policyId] ~= nil,
					ruleSet:isPolicyEnabled(policyId),
					`{difficulty}: {policyId} track presence`
				)
			end
		end
	end)
end

return M
