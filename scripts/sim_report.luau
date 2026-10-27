--!nocheck
-- M10-T2 balance report entrypoint. Run through scripts/sim_report; the core
-- is sim_lib.luau so the report can be tested without spawning a process.

local process = require("@lune/process")
local Sim = require("./sim_lib")

local okArgs, options = pcall(Sim.parseReportArgs, process.args)
if not okArgs then
	print(`sim_report: {tostring(options)}`)
	print(Sim.helpReport())
	process.exit(1)
end
if options.help then
	print(Sim.helpReport())
	return
end

local okRun, report = pcall(Sim.runReport, options)
if not okRun then
	print(`sim_report: {tostring(report)}`)
	process.exit(1)
end

local okWrite, paths = pcall(Sim.writeReport, report, options)
if not okWrite then
	print(`sim_report: {tostring(paths)}`)
	process.exit(1)
end

print(Sim.formatReport(report, paths))
