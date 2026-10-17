--!strict
-- Economy numbers that are not an upgrade track. Re-run `lune run tools/simulate` after changes.

local Economy = {
	DataStoreName = "DigOut_v1", -- never reuse the Rob the Rich store
	ProfileVersion = 1,

	OpenZones = 10, -- zones that can be dug right now (raised with the milestones)

	StartingNoodles = 0,
	StartingStrength = 10,
	-- CREW: dig in a friend's tunnel. Everyone in a crew earns +CrewBonus Noodles per other member
	-- (+CrewFriendBonus more for each Roblox friend among them), at most CrewBonusMax.
	CrewMaxGuests = 3,
	CrewBonus = 0.15,
	CrewFriendBonus = 0.1,
	CrewBonusMax = 0.75,
	CrewInviteSeconds = 30,
	WalkSpeed = 20,

	-- PRISON GYM in the Yard: tap a station to hoist the thing over your head, then tap LIFT when the
	-- needle of the timing meter is in the green zone (perfect = gold center). Strength is earned
	-- with time. meter = needle sweeps per second, zone = green width, perfect = gold width (0..1).
	LiftInterval = 0.45, -- seconds between counted reps
	GymRange = 10, -- studs from the station
	LiftPerfect = 2, -- gain multiplier for a perfect rep
	LiftComboStep = 0.1, -- +10% per perfect in a row...
	LiftComboMax = 2, -- ...up to x2 on top
	LiftShift = 0.2, -- the green zone jumps up to this far from the middle after every rep
	LiftSetReps = 10, -- reps in a row without a miss = a SET...
	LiftSetBonus = 5, -- ...worth this many base reps on top
	LiftTiers = { -- perfect-combo milestones (names shown on the meter)
		{ combo = 3, name = "WARMING UP", color = { 255, 214, 90 } },
		{ combo = 6, name = "ON FIRE 🔥", color = { 255, 150, 60 } },
		{ combo = 10, name = "BEAST MODE", color = { 255, 80, 80 } },
		{ combo = 16, name = "YARD LEGEND", color = { 200, 120, 255 } },
	},
	Gym = {
		{
			id = "Toilet",
			name = "Toilet Curl",
			emoji = "🚽",
			gain = 1,
			minStrength = 0,
			meter = 0.8,
			zone = 0.36,
			perfect = 0.09,
			line = "Don't ask whose it was.",
		},
		{
			id = "Mattress",
			name = "Mattress Stack",
			emoji = "🛏️",
			gain = 3,
			minStrength = 100,
			meter = 0.95,
			zone = 0.32,
			perfect = 0.08,
			line = "Still warm.",
		},
		{
			id = "Vending",
			name = "Vending Machine",
			emoji = "🥫",
			gain = 10,
			minStrength = 600,
			meter = 1.1,
			zone = 0.28,
			perfect = 0.07,
			line = "Shake it for free snacks.",
		},
		{
			id = "Guard",
			name = "Sleeping Guard",
			emoji = "👮",
			gain = 40,
			minStrength = 4000,
			meter = 1.25,
			zone = 0.25,
			perfect = 0.06,
			line = "Shh... don't wake him.",
		},
		{
			id = "Washer",
			name = "Washing Machine",
			emoji = "🧺",
			gain = 150,
			minStrength = 15000,
			meter = 1.4,
			zone = 0.22,
			perfect = 0.055,
			line = "Still on spin cycle.",
		},
		{
			id = "Desk",
			name = "Warden's Desk",
			emoji = "🗄️",
			gain = 600,
			minStrength = 60000,
			meter = 1.55,
			zone = 0.2,
			perfect = 0.05,
			line = "With the warden's lunch on it.",
		},
		{
			id = "Bus",
			name = "Prison Bus",
			emoji = "🚌",
			gain = 2500,
			minStrength = 250000,
			meter = 1.7,
			zone = 0.18,
			perfect = 0.045,
			line = "The whole bus. Yes.",
		},
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
	ReferralDynamite = 2, -- a friend you invited joins for the first time: you both get this many 🧨
	VipBonus = 0.1, -- VIP pass: +10% Noodles
	PremiumBonus = 0.1, -- Roblox Premium members: +10% Noodles
	CatalogMarkup = 1.2, -- the CELL CATALOG (upgrades from your cell during LOCKDOWN) costs this x
	DailyBlocks = 300, -- daily reward = this many blocks of rubble from your deepest zone x streak (max 7)
	DailyMaxStreak = 7,
	DailyMaxDynamite = 1, -- sticks of dynamite on top at a full streak (every day of it)
	DailyUniform = "Lifer", -- Laundry exclusive given once, the first time you reach a full streak
	GiftMinutes = 10, -- a playtime gift every N minutes
	GiftBlocks = 200,
	-- WHILE YOU SLEPT: your bunkmate digs while you're offline (at least CellmateMinMinutes away)
	-- and pays you CellmatePerMinute blocks of your deepest zone's rubble per minute, x
	-- CellmateValue, for up to CellmateMaxHours
	CellmatePerMinute = 8,
	CellmateMinMinutes = 10,
	CellmateMaxHours = 12,
	CellmateValue = 1,

	DumpRange = 14, -- studs from the Yard dump
	FlushRate = 0.6, -- at night (doors locked) your cell toilet takes rubble for this share of its value
	FlushRange = 8,
	ShopRange = 14, -- studs from a shop counter
}

return Economy
