--!strict
-- Economy numbers that are not an upgrade track. Re-run `lune run tools/simulate` after changes.

local Economy = {
	DataStoreName = "DigOut_v1", -- never reuse the Rob the Rich store
	ProfileVersion = 1,

	OpenZones = 10, -- zones that can be dug right now (raised with the milestones)

	StartingNoodles = 0,
	StartingStrength = 10,
	WalkSpeed = 20,

	-- Gym in the Yard: stand next to a station and tap LIFT. Strength is earned with time.
	LiftInterval = 0.6, -- seconds between counted lifts
	GymRange = 9, -- studs from the station
	Gym = {
		{ name = "Bench", emoji = "🏋️", gain = 1, minStrength = 0 },
		{ name = "Dumbbells", emoji = "💪", gain = 3, minStrength = 100 },
		{ name = "Barbell", emoji = "🏋️", gain = 10, minStrength = 600 },
		{ name = "Tire Flip", emoji = "🛞", gain = 40, minStrength = 4000 },
		{ name = "Pull-up Bar", emoji = "🤸", gain = 150, minStrength = 25000 },
		{ name = "Boulder Lift", emoji = "🪨", gain = 600, minStrength = 150000 },
		{ name = "Bus Pull", emoji = "🚌", gain = 2500, minStrength = 1000000 },
	},

	-- what the game passes do (M4; the simulator already uses them)
	PassEffects = {
		DoubleNoodles = 2, -- Noodles from dumping and selling
		DoubleStrength = 2, -- gym gains
		HugeBackpack = 2, -- rubble capacity
	},

	-- every completed zone set in the collection: +10% Noodles from dumping and selling, forever
	CollectionBonus = 0.1,

	-- members of the experience's group: +10% Noodles
	GroupBonus = 0.1,

	-- ESCAPE (rebirth): break through the last layer, escape, get caught, land in a tougher prison.
	-- Rebirths multiply punch power, gym gains and Noodles (Progression.rebirthMultiplier).
	Prisons = {
		{ name = "STATE PRISON", tint = { 255, 255, 255 } },
		{ name = "HIGH SECURITY", tint = { 200, 215, 255 } },
		{ name = "ISLAND PRISON", tint = { 255, 235, 190 } },
		{ name = "SPACE PRISON", tint = { 210, 180, 255 } },
	},

	-- retention
	DailyBlocks = 60, -- daily reward = this many blocks of rubble from your deepest zone x streak (max 7)
	DailyMaxStreak = 7,
	GiftMinutes = 10, -- a playtime gift every N minutes
	GiftBlocks = 40,
	-- the Cellmate digs while you're away: CellmatePerMinute rubble/min, never more than your free
	-- backpack space, at half the rubble value
	CellmatePerMinute = 2,
	CellmateMaxHours = 8,
	CellmateValue = 0.5,

	DumpRange = 14, -- studs from the Yard dump
	ShopRange = 14, -- studs from a shop counter
}

return Economy
