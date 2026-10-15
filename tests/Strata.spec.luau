--!strict
local Strata = require("../src/shared/Strata")
local Progression = require("../src/shared/Progression")
local Zones = require("../src/shared/Config/Zones")
local World = require("../src/shared/Config/World")

return function()
	-- the back wall stays one seamless surface
	for x = 0, World.TunnelWidth - 1 do
		for y = 0, World.TunnelHeight - 1 do
			assert(Strata.featureAt(x, y, 0) == nil, "feature on the back wall")
		end
	end
	-- every feature has a look, every zone has some features, and none covers most of a zone
	for zone = 1, #Zones do
		local z0 = Progression.zoneStart(zone)
		local total, featured = 0, 0
		for z = math.max(1, z0), z0 + Zones[zone].depth - 1 do
			for x = 0, World.TunnelWidth - 1 do
				for y = 0, World.TunnelHeight - 1 do
					local f = Strata.featureAt(x, y, z)
					total += 1
					if f then
						featured += 1
						assert(Strata.Looks[f], "no look for " .. f)
					end
				end
			end
		end
		local share = featured / total
		assert(share > 0.004, "zone " .. zone .. " has almost no features")
		assert(share < 0.2, "zone " .. zone .. " is mostly features: " .. share)
	end
	-- deterministic
	assert(Strata.featureAt(3, 4, 300) == Strata.featureAt(3, 4, 300), "not deterministic")
end
