--!strict
local Quality = require("../src/shared/Config/Quality")
local World = require("../src/shared/Config/World")

return function()
	local L = Quality.Levels
	for i = 2, #L do
		assert(L[i].stream >= L[i - 1].stream, "stream radius must grow with quality")
		assert(L[i].lights >= L[i - 1].lights, "light budget must grow with quality")
		assert(L[i].debris >= L[i - 1].debris, "debris cap must grow with quality")
		assert(L[i].particles >= L[i - 1].particles, "particles must grow with quality")
	end
	local high = L[#L]
	assert(high.stream == World.StreamRadius, "High = the normal stream radius")
	assert(high.debris == World.MaxDebris, "High = the normal debris cap")
	assert(Quality.DropBelow < Quality.RaiseAbove, "hysteresis")
end
