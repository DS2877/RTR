--!strict
-- WORK DETAIL: three daily jobs (easy / medium / hard), the same for a player all day (picked from
-- the day + the player's seed, Shared/Missions). Rewards are known up front: Noodles = reward blocks
-- of rubble from your deepest zone x the tier's multiplier. Finish all three for a bonus.

export type Job = {
	id: string,
	text: string, -- "%d" = the goal
	stat: string, -- what counts (Services/Missions.count)
	goals: { number }, -- per tier (easy, medium, hard)
	reward: number, -- blocks of rubble (x tier multiplier)
	emoji: string,
}

local Missions = {
	PerDay = 3,
	TierMult = { 1, 1.6, 2.4 },
	BonusBlocks = 450, -- all three jobs done
	Pool = {
		{
			id = "Blocks",
			text = "Break %d blocks",
			stat = "Blocks",
			goals = { 120, 300, 600 },
			reward = 120,
			emoji = "🧱",
		},
		{
			id = "Finds",
			text = "Dig up %d finds",
			stat = "Finds",
			goals = { 2, 5, 9 },
			reward = 150,
			emoji = "💎",
		},
		{
			id = "Dumps",
			text = "Dump rubble %d times",
			stat = "Dumps",
			goals = { 2, 4, 7 },
			reward = 140,
			emoji = "🚛",
		},
		{
			id = "Lifts",
			text = "Lift %d reps at the gym",
			stat = "Lifts",
			goals = { 25, 60, 110 },
			reward = 100,
			emoji = "💪",
		},
		{
			id = "Perfects",
			text = "Hit %d PERFECT lifts",
			stat = "Perfects",
			goals = { 8, 20, 40 },
			reward = 120,
			emoji = "🏋️",
		},
		{
			id = "Crits",
			text = "Land %d CRIT punches",
			stat = "Crits",
			goals = { 8, 20, 40 },
			reward = 110,
			emoji = "💥",
		},
		{
			id = "Depth",
			text = "Dig %dm deeper",
			stat = "Depth",
			goals = { 4, 10, 18 },
			reward = 170,
			emoji = "⛏️",
		},
		{
			id = "Sells",
			text = "Sell %d finds at The Fence",
			stat = "Sells",
			goals = { 2, 5, 9 },
			reward = 130,
			emoji = "💰",
		},
		{
			id = "Combo",
			text = "Reach a %d-hit combo",
			stat = "Combo", -- the best chain today (Services/Missions.reach)
			goals = { 25, 60, 120 },
			reward = 130,
			emoji = "🔥",
		},
		{
			id = "Gold",
			text = "Break %d gold blocks",
			stat = "Gold",
			goals = { 2, 5, 10 },
			reward = 150,
			emoji = "🪙",
		},
	} :: { Job },
}

return Missions
