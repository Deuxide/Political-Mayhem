--!nocheck
-- RevealEvents tests (M11-T2): the city's presentation adapter classifies the
-- four visual event kinds from the public Evening Report. This suite pins the
-- log formats the server writes today and proves unrelated prose is ignored;
-- the tweens themselves are checked in Studio.

local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

local function report(events: { any }): any
	return { day = 7, events = events, deltas = {} }
end

function M.run()
	print("reveal events")
	local root = Loader.mount("src")
	local RevealEvents = Loader.require(root.client.State.RevealEvents)

	Lib.test("a missing report has no visual events", function()
		Lib.eq(#RevealEvents.build(nil), 0, "no report")
	end)

	Lib.test("the four event kinds are classified with their targets", function()
		local events = RevealEvents.build(report({
			{ day = 7, text = "Middle Farm-1 produced 4 Food", actor = "Middle" },
			{
				day = 7,
				text = "Working's strike idles Capitalist: 4 staffed line(s) produce nothing today",
				actor = "Working",
			},
			{ day = 7, text = "Working could not cover 4 Food and 3 Health", actor = "Working" },
			{ day = 7, text = "Middle built Farm-4 for 12 Money", actor = "Middle" },
		}))

		Lib.eq(#events, 4, "one event per matching line")
		Lib.eq(events[1].kind, "Production", "production")
		Lib.eq(events[1].actor, "Middle", "production owner")
		Lib.eq(events[1].lineId, "Farm-1", "production line")
		Lib.eq(events[1].day, 7, "the report Day")

		Lib.eq(events[2].kind, "Strike", "strike")
		Lib.eq(events[2].actor, "Working", "the striker")
		Lib.eq(events[2].target, "Capitalist", "the idled class")

		Lib.eq(events[3].kind, "Protest", "unmet needs become a protest")
		Lib.eq(events[3].actor, "Working", "the protesting class")

		Lib.eq(events[4].kind, "NewBuild", "new build")
		Lib.eq(events[4].lineId, "Farm-4", "the new line")
	end)

	Lib.test("production keeps its no-input suffix", function()
		local events = RevealEvents.build(report({
			{
				day = 3,
				text = "Capitalist Factory-1 produced 8 Goods (no input: output halved)",
				actor = "Capitalist",
			},
		}))
		Lib.eq(#events, 1, "still a production event")
		Lib.eq(events[1].kind, "Production", "production")
		Lib.eq(events[1].lineId, "Factory-1", "the line id")
	end)

	Lib.test("unrelated or unknown prose is ignored", function()
		local events = RevealEvents.build(report({
			{ day = 3, text = "A bill passed", actor = "State" },
			{ day = 3, text = "Nobody built Farm-9 for 1 Money" },
			{ day = 3, text = "Working's strike idles Nobody: 1 staffed line(s)" },
		}))
		Lib.eq(#events, 0, "nothing to animate")
	end)
end

return M
