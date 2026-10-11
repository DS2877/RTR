--!strict
-- Every balance number. Logic reads these; never hardcode balance in services.

local Economy = {
	DataStoreName = "RTR_Player_v1",
	ProfileVersion = 1,

	StartingCash = 0,
	StarterItem = "Wrench", -- free item on the first join so the plot is never empty

	-- Speed: points come from the treadmill; WalkSpeed = Base + PerDoubling * log2(1 + points / Unit)
	Speed = {
		Base = 16,
		PerDoubling = 6,
		Unit = 20,
		Max = 200,
		SlowMode = 16, -- walk speed with Slow Mode on (for moving around your base)
	},

	-- Treadmill: points per second at level L = Rate * Growth^(L - 1); cost of level L -> L+1
	Treadmill = {
		Rate = 2,
		Growth = 1.4,
		MaxLevel = 30,
		Cost = 60,
		CostGrowth = 2.8,
		BeltSpeed = 12, -- studs/s the stripes scroll (visual only: standing on it = running, AFK ok)
	},

	-- Express lanes: moving walkways along the plaza + Rich Street (one each way)
	Lanes = {
		Speed = 18, -- studs/s added to whoever stands on them (players and guards alike)
		Width = 7,
	},

	-- Plot: pedestals at level L = Start + PerLevel * (L - 1), capped by the base layout
	Plot = {
		StartPedestals = 6,
		PerLevel = 2,
		MaxLevel = 13, -- 30 pedestals
		Cost = 400,
		CostGrowth = 3.6,
	},

	CarrySlowdown = { -- walk speed multiplier while carrying, by rarity
		Common = 0.9,
		Uncommon = 0.88,
		Rare = 0.86,
		Epic = 0.84,
		Legendary = 0.8,
		Mythic = 0.75,
	} :: { [string]: number },

	SellSeconds = 60, -- an item sells for this many seconds of its income
	VaultRespawnSeconds = { 6, 12 }, -- random range before an emptied vault pedestal refills

	-- Your own base
	LockSeconds = 60,
	LockCooldown = 30, -- after a lock ends, before you can lock again
	StunSeconds = 1.5, -- after a guard catches you or someone slaps you
	SlapRange = 10,
	SlapCooldown = 1.0,

	OfflineRate = 0.5, -- fraction of income earned while offline
	OfflineMaxHours = 12,

	-- 👑 THE RICHEST (the twist)
	Richest = {
		MinPlayers = 2, -- the crown needs a rival on the server
		CheckSeconds = 2,
		Hysteresis = 1.05, -- a challenger must be 5% richer to take the crown
		IncomeBonus = 1.5, -- the richest earns more...
		CanLock = false, -- ...but can never lock their base
		BountySeconds = 120, -- robbing the richest pays this many seconds of THEIR income (paid by the game)
		MinBounty = 500,
		-- the longer the reign, the bigger the crown and the bounty: +GrowthPerMinute per minute
		GrowthPerMinute = 0.15,
		MaxGrowth = 3, -- bounty multiplier cap (reached after ~13 min)
	},

	-- Server events: one every EverySeconds (random pick), lasting Duration seconds
	Events = {
		EverySeconds = { 600, 900 },
		FirstAfter = 240, -- first event a few minutes into a fresh server
		Duration = 90,
		List = {
			{
				id = "GoldRush",
				name = "GOLD RUSH",
				emoji = "✨",
				desc = "4x mutation chance in every vault!",
				color = { 255, 210, 60 },
			},
			{
				id = "GuardStrike",
				name = "GUARD STRIKE",
				emoji = "😴",
				desc = "The guards are asleep. Steal anything!",
				color = { 120, 200, 255 },
			},
			{
				id = "CashFrenzy",
				name = "CASH FRENZY",
				emoji = "💸",
				desc = "Every plot earns 2x cash!",
				color = { 110, 255, 130 },
			},
		} :: { { id: string, name: string, emoji: string, desc: string, color: { number } } },
		GoldRushMult = 4,
		CashFrenzyMult = 2,
	},
}

return Economy
