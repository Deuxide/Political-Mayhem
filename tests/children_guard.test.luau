--!nocheck
local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

function M.run()
	print("children guard (react-lua issue #42)")
	local Guard = Loader.require(Loader.mount("src/client/UI/Dev").ChildrenGuard)

	local function element()
		return { ["$$typeof"] = "react.element" }
	end

	Lib.test("keyed table of elements is fine", function()
		Lib.eq(#Guard.check("Frame", {}, { Header = element(), Body = element() }), 0)
	end)

	Lib.test("false / nil values inside a keyed table are fine", function()
		Lib.eq(#Guard.check("Frame", {}, { Header = element(), Maybe = false }), 0)
	end)

	Lib.test("a single element child is fine", function()
		Lib.eq(#Guard.check("Frame", {}, element()), 0)
	end)

	Lib.test("a Fragment-wrapped table is fine (the documented fix)", function()
		Lib.eq(#Guard.check("Frame", {}, { Content = element() }), 0)
	end)

	Lib.test("raw children table nested inside a children table is flagged (issue #42)", function()
		local problems = Guard.check(
			"Frame",
			{},
			{ UIGradient = element(), Children = { A = element() } }
		)
		Lib.eq(#problems, 1)
		Lib.contains(problems[1], "issue #42")
		Lib.contains(problems[1], "Children")
	end)

	Lib.test("a string child is flagged", function()
		local problems = Guard.check("Frame", {}, { Label = "hello" })
		Lib.eq(#problems, 1)
		Lib.contains(problems[1], "TextLabel")
	end)

	Lib.test("a number child (even 0) is flagged", function()
		Lib.eq(#Guard.check("Frame", {}, { Count = 0 }), 1)
	end)

	Lib.test("a string passed as the only child argument is flagged", function()
		Lib.eq(#Guard.check("Frame", {}, "hello"), 1)
	end)

	Lib.test("falsy child followed by a raw table of children is flagged", function()
		local problems = Guard.check("Frame", {}, false, { A = element() })
		Lib.eq(#problems, 1)
		Lib.contains(problems[1], "child argument #2")
	end)

	Lib.test("table of children first, conditional child after, is fine", function()
		Lib.eq(#Guard.check("Frame", {}, element(), false), 0)
	end)

	Lib.test("props.children that nests a raw table is flagged", function()
		Lib.eq(#Guard.check("Frame", { children = { Inner = { A = element() } } }), 1)
	end)

	Lib.test("install wraps createElement and reports once per call site", function()
		Guard.uninstall()
		local reports = {}
		local fake = {
			createElement = function(elementType, props, ...)
				return { ["$$typeof"] = "react.element", type = elementType }
			end,
		}
		Lib.truthy(Guard.install(fake, function(message)
			table.insert(reports, message)
		end))
		for _ = 1, 3 do
			fake.createElement("Frame", {}, { Label = "x" }) -- one call site, three renders
		end
		Guard.uninstall()
		Lib.eq(#reports, 1, "same call site should be reported once")
	end)

	Lib.test("install reports failure instead of crashing when React is read-only", function()
		Guard.uninstall()
		local frozen = table.freeze({ createElement = function() end })
		Lib.eq(Guard.install(frozen), false)
	end)
end

return M
