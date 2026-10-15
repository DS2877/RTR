--!strict
-- Server-wide day/night cycle. Night: doors locked, everyone in their own cell, safe digging with
-- bonus finds. Day: doors open, shops open, free movement (PvP from M3).

local Cycle = {
	NightSeconds = 300,
	DaySeconds = 180,
	LightsOutWarning = 10, -- "LIGHTS OUT!" countdown before the doors lock
	NightFindBonus = 0.25, -- +25% finds at night (bonus finds in plain blocks)
	DayClock = 14, -- Lighting.ClockTime
	NightClock = 0.5,
	-- the prison look: grey, overcast and cold; night is dark (colors are RGB)
	Look = {
		Day = { brightness = 1.15, ambient = { 62, 64, 68 }, outdoor = { 92, 94, 100 } },
		Night = { brightness = 0.18, ambient = { 30, 32, 38 }, outdoor = { 22, 24, 34 } },
		Tunnel = { ambient = { 38, 38, 44 } },
	},

	-- guard inspections at night: every InspectEvery seconds a prisoner may get a visit
	InspectEvery = 40,
	InspectChance = 0.3, -- per check, per prisoner (snitched prisoners: always)
	InspectWarning = 5, -- seconds to tap HIDE
	BribeBlocks = 150, -- bribe = this many blocks of rubble from your deepest zone
	SnitchBlocks = 300, -- snitching costs this many blocks of rubble from the TARGET's zone

	-- server events (random, every EventMin..EventMax seconds)
	EventMin = 900,
	EventMax = 1500,
	Events = {
		BLACKOUT = { name = "BLACKOUT", seconds = 120, text = "All walls are 2x weaker!" },
		RIOT = { name = "RIOT", seconds = 90, text = "The doors are open tonight!" },
		INSPECTION = {
			name = "INSPECTION DAY",
			seconds = 60,
			text = "Be in your cell with an empty backpack!",
		},
		TREASURE = { name = "TREASURE RACE", seconds = 180, text = "First to dig to the treasure wins!" },
	} :: { [string]: { name: string, seconds: number, text: string } },
	InspectionDayBlocks = 80, -- reward for a tidy cell
	TreasureBlocks = 600, -- treasure prize (plus the best find of your zone)
}

return Cycle
