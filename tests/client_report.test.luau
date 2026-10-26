--!nocheck
-- The Evening Report model (M8-T5): every non-zero delta of the viewer's
-- own class becomes a row with a one-line cause. Exact causes come from the
-- Day's log; a stock change the log does not name falls back to the rule
-- that owns it (D-081). Other classes' deltas never appear, because the
-- server does not send them.

local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

function M.run()
	print("client report")
	local root = Loader.mount("src")
	local Report = Loader.require(root.client.State.Report)

	local function sample()
		return {
			day = 1,
			events = {
				{
					day = 1,
					text = "Middle could not cover 2 Food",
					actor = "Middle",
				},
				{
					day = 1,
					text = "Middle gained 2 Influence",
					actor = "Middle",
				},
				{
					day = 1,
					text = "Middle gained 1 VP (needsMet)",
					actor = "Middle",
				},
				{
					day = 1,
					text = "Middle broke their Deliver promise to Working",
					actor = "Middle",
				},
			},
			deltas = {
				Middle = {
					money = 0,
					influence = 2,
					stock = { food = -2, goods = 0, health = -1, education = 0 },
					vp = 1,
				},
				Capitalist = {
					money = 50,
					influence = 50,
					stock = { food = 50 },
					vp = 50,
				},
			},
		}
	end

	local function byKey(model, key)
		for _, row in model.rows do
			if row.key == key then
				return row
			end
		end
		return nil
	end

	Lib.test("every non-zero own delta has a row and a cause", function()
		local model = Report.build(sample(), "Middle")
		Lib.eq(#model.rows, 4, "influence, Food, Health and VP changed")
		Lib.eq(byKey(model, "Money"), nil, "a zero delta is not a row")
		Lib.eq(byKey(model, "Goods"), nil, "a zero stock delta is not a row")
		Lib.eq(byKey(model, "Education"), nil, "a zero stock delta is not a row")

		local influence = byKey(model, "Influence")
		Lib.eq(influence.amount, 2, "the Influence delta")
		Lib.eq(influence.cause, "Middle gained 2 Influence", "the exact log line")

		local food = byKey(model, "Food")
		Lib.eq(food.amount, -2, "the Food delta")
		Lib.eq(food.cause, "Middle could not cover 2 Food", "the exact log line")

		local health = byKey(model, "Health")
		Lib.eq(health.amount, -1, "the Health delta")
		Lib.truthy(health.cause ~= "", "the fallback still names a cause")

		local vp = byKey(model, "VP")
		Lib.eq(vp.amount, 1, "the VP delta")
		Lib.eq(vp.cause, "Middle gained 1 VP (needsMet)", "the exact log line")

		for _, row in model.rows do
			Lib.truthy(row.cause ~= "", `{row.label} has a cause`)
		end
	end)

	Lib.test("another class's delta never enters the viewer's report", function()
		local model = Report.build(sample(), "Middle")
		for _, row in model.rows do
			Lib.truthy(row.key ~= "Capitalist", "no Capitalist row")
		end
		Lib.eq(#model.rows, 4, "only the Middle's four changes")
	end)

	Lib.test("broken promises are danger and VP gains are success", function()
		local model = Report.build(sample(), "Middle")
		local broken = nil
		local gained = nil
		for _, event in model.events do
			if string.find(event.text, "broke", 1, true) then
				broken = event
			end
			if string.find(event.text, "gained", 1, true) then
				gained = event
			end
		end
		Lib.truthy(broken ~= nil, "the broken promise line")
		Lib.eq(broken.tone, "danger", "a broken promise is highlighted")
		Lib.truthy(gained ~= nil, "the VP line")
		Lib.eq(gained.tone, "success", "a VP gain is highlighted")
	end)

	Lib.test("a report with no delta still carries the public events", function()
		local report = sample()
		report.deltas = {}
		local model = Report.build(report, "Middle")
		Lib.eq(#model.rows, 0, "no own delta")
		Lib.eq(#model.events, 4, "the public story remains")
	end)
end

return M
