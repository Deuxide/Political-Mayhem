--!strict
-- Test runner entry point for Lune.

local TestHarness = require("./harness")
local Real = require("./real")

local harnessOk, harnessErr = pcall(TestHarness.run)
local realFailures = Real.run()

if not harnessOk then print("legacy harness failed: " .. tostring(harnessErr)) end
if not harnessOk or realFailures > 0 then error("Some tests failed", 0) end
