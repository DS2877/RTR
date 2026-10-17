--!strict
-- Server-wide day/night cycle. Night: doors locked, everyone in their own cell, safe digging with
-- bonus finds. Day: doors open, shops open, free movement (PvP from M3).

local Cycle = {
	NightSeconds = 180, -- (was 270: a full backpack left nothing to do; see FlushRate)
	DaySeconds = 200,
	RollCallSeconds = 25,
	LightsOutWarning = 10, -- "LIGHTS OUT!" countdown before the doors lock
	RollCallBlocks = 25, -- in your cell when roll call ends: this many blocks of rubble (deepest zone)

	-- THE PRISON SCHEDULE: the phases in order. Phase ids are what the code checks ("Day" = Yard
	-- Time: doors open, fights on). clock = prison time (Lighting.ClockTime) at the start and end.
	Schedule = {
		{
			id = "RollCall",
			name = "ROLL CALL",
			emoji = "📋",
			clock = { 6, 7.5 },
			rules = "Stay in your cell to be counted",
		},
		{
			id = "Day",
			name = "YARD TIME",
			emoji = "☀️",
			clock = { 7.5, 18 },
			rules = "Doors open · Fights on",
		},
		{
			id = "LightsOut",
			name = "LIGHTS OUT",
			emoji = "🚨",
			clock = { 18, 19 },
			rules = "Back to your cell!",
		},
		{
			id = "Night",
			name = "LOCKDOWN",
			emoji = "🌙",
			clock = { 19, 30 },
			rules = "Doors locked · +25% finds",
		},
	} :: { { id: string, name: string, emoji: string, clock: { number }, rules: string } },
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
	InspectChance = 0.3, -- per check, per prisoner (snitched prisoners: always); one visit a night each
	InspectNewbieMinutes = 15, -- prisoners with less play time than this are never inspected
	InspectWarning = 15, -- seconds from the footsteps to the guard at your door: get in bed + cover up
	InspectWarningMax = 75, -- ...plus the walk back from deep in your tunnel, up to this
	SleepHold = 1.2, -- seconds to hold the bed prompt (getting under the blanket takes a moment)
	CoverHold = 0.8, -- seconds to hold the tapestry prompt
	BribeBlocks = 150, -- bribe = this many blocks of rubble from your deepest zone
	SnitchBlocks = 300, -- snitching costs this many blocks of rubble from the TARGET's zone

	-- server events (random, every EventMin..EventMax seconds; never the same one twice in a row)
	EventMin = 300,
	EventMax = 480,
	Events = {
		BLACKOUT = { name = "BLACKOUT", emoji = "⚡", seconds = 120, text = "All walls are 2x weaker!" },
		RIOT = { name = "RIOT", emoji = "🔓", seconds = 90, text = "The doors are open tonight!" },
		INSPECTION = {
			name = "INSPECTION DAY",
			emoji = "🧹",
			seconds = 60,
			text = "Be in your cell with an empty backpack!",
		},
		TREASURE = {
			name = "TREASURE RACE",
			emoji = "💰",
			seconds = 180,
			text = "First to dig to the treasure wins!",
		},
		GOLDRUSH = { name = "GOLD RUSH", emoji = "💎", seconds = 90, text = "Finds are way more common!" },
		PAYDAY = { name = "PAYDAY", emoji = "🍜", seconds = 120, text = "Dumping and flushing pay 2x!" },
		EARTHQUAKE = {
			name = "EARTHQUAKE",
			emoji = "🌋",
			seconds = 12,
			text = "The ground shakes: free blocks break in every tunnel!",
		},
		SUPPLYDROP = {
			name = "SUPPLY DROP",
			emoji = "📦",
			seconds = 75,
			text = "A crate landed in the Yard: first one there gets it!",
		},
	} :: { [string]: { name: string, emoji: string, seconds: number, text: string } },
	-- which events can happen in each part of the schedule
	EventPools = {
		Day = { "BLACKOUT", "INSPECTION", "TREASURE", "GOLDRUSH", "PAYDAY", "EARTHQUAKE", "SUPPLYDROP" },
		Night = { "BLACKOUT", "RIOT", "TREASURE", "GOLDRUSH", "PAYDAY", "EARTHQUAKE" },
	} :: { [string]: { string } },
	InspectionDayBlocks = 80, -- reward for a tidy cell
	TreasureBlocks = 600, -- treasure prize (plus the best find of your zone)
	GoldRushBonus = 2, -- extra finds in plain blocks: oreChance x this (like the night bonus)
	PaydayMult = 2, -- dump / flush pay
	QuakeBlocks = 24, -- blocks the earthquake breaks at the front of every tunnel
	SupplyBlocks = 400, -- supply crate prize: this many blocks of rubble of the winner's zone
}

return Cycle
