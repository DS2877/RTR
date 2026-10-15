--!strict
local Audio = require("../src/shared/Config/Audio")
local Zones = require("../src/shared/Config/Zones")

return function()
	for _, zone in Zones do
		local spec = Audio.Zone[zone.id]
		assert(spec, "no sound set for zone " .. zone.id)
		local m = Audio.Materials[spec.material]
		assert(m, "unknown material " .. spec.material)
		assert(Audio.Banks[m.hit] and Audio.Banks[m.breakBank], "missing banks for " .. spec.material)
		assert(m.extra == nil or Audio.Banks[m.extra], "missing extra bank for " .. spec.material)
		assert(Audio.Loops[spec.ambience], "missing ambience " .. spec.ambience)
	end
	for name, bank in Audio.Banks do
		assert(#bank > 0, "empty bank " .. name)
		for _, id in bank do
			assert(string.match(id, "^rbxassetid://%d+$"), "bad id in " .. name)
		end
	end
end
