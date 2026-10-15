--!strict
-- Server-wide day/night cycle. Night: doors locked, everyone in their own cell, safe digging with
-- bonus finds. Day: doors open, shops open, free movement (PvP from M3).

local Cycle = {
	NightSeconds = 300,
	DaySeconds = 180,
	LightsOutWarning = 10, -- "LIGHTS OUT!" countdown before the doors lock
	NightFindBonus = 0.25, -- +25% finds at night (bonus finds in plain blocks)
	DayClock = 13, -- Lighting.ClockTime
	NightClock = 0.5,
}

return Cycle
