--!strict
local ChamberSets = require("../src/shared/ChamberSets")
local Progression = require("../src/shared/Progression")
local Zones = require("../src/shared/Config/Zones")

return function()
	for zone = 2, #Zones do
		local b = Progression.chamberBox(zone)
		assert(b, "zone " .. zone .. " has no chamber")
		local w, h, d = (b.x1 - b.x0 + 1) * 2, (b.y1 - b.y0 + 1) * 2, (b.z1 - b.z0 + 1) * 2
		local specs = ChamberSets.specs(zone, w, h, d)
		assert(specs and #specs >= 3, "zone " .. zone .. " has an empty chamber")
		for i, s in specs do
			-- props stay inside the room (centers within the box)
			assert(
				math.abs(s.pos[1]) <= w / 2 + 0.01,
				string.format("zone %d prop %d sticks out sideways", zone, i)
			)
			assert(
				s.pos[2] >= -0.01 and s.pos[2] <= h + 0.01,
				string.format("zone %d prop %d out of height", zone, i)
			)
			assert(
				s.pos[3] >= -0.01 and s.pos[3] <= d + 0.01,
				string.format("zone %d prop %d out of depth", zone, i)
			)
		end
	end
end
