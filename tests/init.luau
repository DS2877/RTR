--!strict
-- Lune test runner: `lune run tests`
local process = require("@lune/process")

local suites = {
	{ name = "Format", run = require("./Format.spec") },
	{ name = "Voxel", run = require("./Voxel.spec") },
	{ name = "Progression", run = require("./Progression.spec") },
	{ name = "Shell", run = require("./Shell.spec") },
	{ name = "Audio", run = require("./Audio.spec") },
	{ name = "Strata", run = require("./Strata.spec") },
	{ name = "Patrol", run = require("./Patrol.spec") },
	{ name = "ChamberSets", run = require("./ChamberSets.spec") },
	{ name = "Quality", run = require("./Quality.spec") },
	{ name = "Missions", run = require("./Missions.spec") },
	{ name = "Breakout", run = require("./Breakout.spec") },
	{ name = "Pass", run = require("./Pass.spec") },
	{ name = "Locker", run = require("./Locker.spec") },
}

local failures = 0
for _, suite in suites do
	local ok, err = pcall(suite.run :: any)
	if ok then
		print("PASS  " .. suite.name)
	else
		failures += 1
		print("FAIL  " .. suite.name .. "\n      " .. tostring(err))
	end
end

if failures > 0 then
	print(string.format("\n%d suite(s) failed", failures))
	process.exit(1)
end
print("\nAll tests passed")
