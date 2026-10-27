--!nocheck
-- M10-T1 simulator entrypoint. Run through scripts/sim, which sets the project
-- root; the core lives in sim_lib.luau so tests can exercise it directly.

local process = require("@lune/process")
local Sim = require("./sim_lib")

local okArgs, options = pcall(Sim.parseArgs, process.args)
if not okArgs then
	print(`sim: {tostring(options)}`)
	print(Sim.help())
	process.exit(1)
end
if options.help then
	print(Sim.help())
	return
end

local okRun, result = pcall(Sim.run, options)
if not okRun then
	print(`sim: {tostring(result)}`)
	process.exit(1)
end

local okWrite, paths = pcall(Sim.writeOutputs, result, options)
if not okWrite then
	print(`sim: {tostring(paths)}`)
	process.exit(1)
end

print(Sim.formatSummary(result.summary, options, paths))
