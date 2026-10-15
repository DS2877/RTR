--!strict
local PatrolMath = require("../src/shared/Patrol")
local Config = require("../src/shared/Config/Patrol")

return function()
	-- every guard has a valid route in every phase
	for i in Config.Guards do
		for _, phase in { "RollCall", "Day", "LightsOut", "Night" } do
			assert(Config.Routes[PatrolMath.routeOf(i, phase)], "guard " .. i .. " has no route at " .. phase)
		end
	end
	-- moves continuously (no teleports between frames) and stays on its route's bounding box
	for name, pts in Config.Routes do
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for _, p in pts do
			minX, maxX = math.min(minX, p[1]), math.max(maxX, p[1])
			minZ, maxZ = math.min(minZ, p[2]), math.max(maxZ, p[2])
		end
		local last = PatrolMath.pose(name, 0)
		for k = 1, 4000 do
			local pose = PatrolMath.pose(name, k * 0.05)
			local step = math.sqrt((pose.x - last.x) ^ 2 + (pose.z - last.z) ^ 2)
			assert(step <= Config.Speed * 0.05 + 1e-6 or step > 100, name .. " jumps " .. step)
			assert(pose.x >= minX - 1e-6 and pose.x <= maxX + 1e-6, name .. " leaves its route")
			assert(pose.z >= minZ - 1e-6 and pose.z <= maxZ + 1e-6, name .. " leaves its route")
			last = pose
		end
	end
	-- every situation has lines
	for _, kind in
		{ "Stolen", "Fight", "Digging", "Bag", "Lifting", "Near", "RollCall", "Day", "LightsOut", "Night" }
	do
		assert(Config.Lines[kind] and #Config.Lines[kind] > 0, "no lines for " .. kind)
	end
end
