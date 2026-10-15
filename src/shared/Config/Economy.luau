--!strict
-- Economy numbers that are not an upgrade track. Re-run `lune run tools/simulate` after changes.

local Economy = {
	DataStoreName = "DigOut_v1", -- never reuse the Rob the Rich store
	ProfileVersion = 1,

	OpenZones = 3, -- zones that can be dug right now (raised with the milestones)

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
	},

	-- what the game passes do (M4; the simulator already uses them)
	PassEffects = {
		DoubleNoodles = 2, -- Noodles from dumping and selling
		DoubleStrength = 2, -- gym gains
		HugeBackpack = 2, -- rubble capacity
	},

	DumpRange = 14, -- studs from the Yard dump
	ShopRange = 14, -- studs from a shop counter
}

return Economy
