--!strict
local Breakout = require("../src/shared/Breakout")
local Config = require("../src/shared/Config/Breakout")

return function()
	-- searchlights stay inside the yard
	for t = 0, 600, 0.37 do
		for i = 1, Breakout.LightCount do
			local x, z = Breakout.light(i, t)
			assert(x >= 110 and x <= 210, "light " .. i .. " x in the yard: " .. x)
			assert(math.abs(z) <= Breakout.HalfWidth - 4, "light " .. i .. " z in the yard: " .. z)
		end
		assert(math.abs(Breakout.towerLight(t)) <= Breakout.HalfWidth, "tower light on the wall")
	end
	-- a light's own spot is spotted; the sewer and the spawns never are
	local lx, lz = Breakout.light(1, 12.5)
	assert(Breakout.spotted(lx, Breakout.YardY + 2, lz, 12.5), "standing in a light = spotted")
	for t = 0, 120, 0.5 do
		assert(not Breakout.spotted(40, 2, 0, t), "the sewer is dark")
		local sp = Breakout.Spawns[2]
		assert(not Breakout.spotted(sp.x, sp.y, sp.z, t), "the manhole exit is never lit")
	end
	-- the yard is crossable: most of the time a dark lane runs all the way across it
	local open, samples = 0, 0
	for t = 0, 300, 1 do
		samples += 1
		for z = -34, 34, 2 do
			local dark = true
			for x = 110, 212, 2 do
				if Breakout.spotted(x, Breakout.YardY + 2, z, t) then
					dark = false
					break
				end
			end
			if dark then
				open += 1
				break
			end
		end
	end
	assert(open / samples >= 0.6, "a dark lane across the yard most of the time: " .. open / samples)
	-- checkpoints in order only
	local c2 = Breakout.Checkpoints[2]
	assert(Breakout.checkpointAt(1, c2.x0 + 1, c2.y0 + 1, 0) == 2, "checkpoint 2 from 1")
	assert(Breakout.checkpointAt(2, c2.x0 + 1, c2.y0 + 1, 0) == nil, "no going back")
	local c3 = Breakout.Checkpoints[3]
	assert(Breakout.checkpointAt(1, c3.x0 + 1, c3.y0 + 1, 0) == nil, "no skipping the yard")
	assert(Breakout.checkpointAt(2, c3.x0 + 1, c3.y0 + 1, 0) == 3, "checkpoint 3 from 2")
	-- falling
	assert(Breakout.fell(25, -3, 0), "into the sewer water")
	assert(not Breakout.fell(10, 1, 0), "on the walkway")
	assert(not Breakout.fell(150, Breakout.YardY + 3, 0), "on the yard")
	assert(Breakout.fell(150, 5, 0), "off the course")
	-- finish
	assert(Breakout.atFinish(Breakout.Car.x, Breakout.YardY + 3, Breakout.Car.z), "the car is the finish")
	assert(not Breakout.atFinish(250, Breakout.YardY + 3, 0), "not before the car")
	-- medals: faster and cleaner = better, cash goes up with the medal
	assert(Breakout.medal(60, 0).id == "gold", "gold")
	assert(Breakout.medal(60, 1).id == "silver", "spotted once: silver")
	assert(Breakout.medal(200, 9).id == "bronze", "slow: bronze")
	for i = 2, #Config.Medals do
		assert(Config.Medals[i].cash < Config.Medals[i - 1].cash, "better medal pays more")
	end
	-- spawns sit on solid ground
	assert(Breakout.Spawns[1].y > 0 and Breakout.Spawns[2].y > Breakout.YardY, "spawns above ground")
end
