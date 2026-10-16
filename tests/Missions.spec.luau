--!strict
local Missions = require("../src/shared/Missions")
local Config = require("../src/shared/Config/Missions")

return function()
	for day = 20000, 20060 do
		for _, seed in { 1, 42, 99999, 123456789 } do
			local a = Missions.pick(day, seed)
			local b = Missions.pick(day, seed)
			assert(#a == Config.PerDay, "three jobs a day")
			local seen: { [string]: boolean } = {}
			for i, job in a do
				assert(job.id == b[i].id and job.goal == b[i].goal, "deterministic")
				assert(not seen[job.id], "no duplicate jobs")
				seen[job.id] = true
				assert(job.goal > 0 and job.reward > 0, "goal + reward")
				assert(not string.find(job.text, "%%"), "text formatted")
			end
			for _, job in Missions.pick(day, seed, true) do
				assert(job.stat ~= "Depth", "no depth job at the bottom")
			end
		end
	end
	-- the jobs change from day to day
	local differs = false
	for day = 20000, 20010 do
		if Missions.pick(day, 7)[1].id ~= Missions.pick(day + 1, 7)[1].id then
			differs = true
		end
	end
	assert(differs, "new jobs every day")
end
