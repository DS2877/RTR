--!strict
-- PRISON PASS: a 28-day season of 30 tiers. Pass XP comes from digging, daily jobs, the daily
-- reward, vault doors and breakouts. Every tier has a FREE reward; the PREMIUM track (the
-- "PrisonPass" developer product in Config/Products, bought for the current season) adds a bigger
-- one. Every reward is listed in the panel before you buy (known contents, nothing random).
--
-- reward kinds: noodles (n = blocks of rubble of your deepest zone), dynamite (n sticks),
-- uniform / fist (an exclusive Laundry item id), pet (an exclusive cellmate id)

export type Reward = { kind: string, n: number?, id: string? }

local function tier(free: Reward, premium: Reward): { free: Reward, premium: Reward }
	return { free = free, premium = premium }
end

local function noodles(n: number): Reward -- n blocks of rubble (~1-10 min of digging)
	return { kind = "noodles", n = n }
end

local function dynamite(n: number): Reward
	return { kind = "dynamite", n = n }
end

local Pass = {
	-- season 1 started Monday 2026-10-12 00:00 UTC; each season is SeasonDays long
	Epoch = 1791763200,
	SeasonDays = 28,
	TierXp = 250,
	PremiumXpBoost = 0.25, -- premium earns +25 % pass XP
	Xp = {
		BlocksPerXp = 25, -- 1 XP per this many blocks broken
		Mission = 60, -- each WORK DETAIL job claimed
		MissionBonus = 100, -- all three done
		Daily = 40, -- the daily reward
		Vault = 80, -- a vault door cracked
		Breakout = 200, -- a breakout finished with a medal
		Gold = 5, -- each gold block (a jackpot counts 10x)
	},
	Tiers = {
		tier(noodles(400), noodles(1200)),
		tier(noodles(500), dynamite(2)),
		tier(dynamite(1), noodles(1500)),
		tier(noodles(600), noodles(1600)),
		tier(noodles(700), dynamite(2)),
		tier(noodles(800), noodles(1800)),
		tier(dynamite(1), noodles(2000)),
		tier(noodles(900), dynamite(3)),
		tier(noodles(1000), noodles(2200)),
		tier(noodles(1100), { kind = "uniform", id = "Riot" }),
		tier(dynamite(1), noodles(2400)),
		tier(noodles(1200), dynamite(3)),
		tier(noodles(1300), noodles(2600)),
		tier(noodles(1400), noodles(2800)),
		tier(dynamite(2), dynamite(4)),
		tier(noodles(1500), noodles(3000)),
		tier(noodles(1600), noodles(3200)),
		tier(noodles(1700), dynamite(4)),
		tier(dynamite(2), noodles(3500)),
		tier(noodles(1800), { kind = "fist", id = "Lightning" }),
		tier(noodles(1900), noodles(3800)),
		tier(noodles(2000), dynamite(5)),
		tier(dynamite(2), noodles(4000)),
		tier(noodles(2200), noodles(4200)),
		tier(noodles(2400), dynamite(5)),
		tier(noodles(2600), noodles(4500)),
		tier(dynamite(3), noodles(4800)),
		tier(noodles(2800), dynamite(6)),
		tier(noodles(3000), noodles(5200)),
		tier({ kind = "fist", id = "Spark" }, { kind = "pet", id = "Jailbird" }),
	},
}

return Pass
