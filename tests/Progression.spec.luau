--!strict
local Progression = require("../src/shared/Progression")
local Voxel = require("../src/shared/Voxel")
local Zones = require("../src/shared/Config/Zones")
local Finds = require("../src/shared/Config/Finds")
local Rarity = require("../src/shared/Config/Rarity")
local Upgrades = require("../src/shared/Config/Upgrades")
local World = require("../src/shared/Config/World")
local Economy = require("../src/shared/Config/Economy")
local Extras = require("../src/shared/Config/Extras")

local function check(cond: boolean, msg: string)
	if not cond then
		error(msg, 2)
	end
end

return function()
	-- zones
	check(#Zones == 10, "10 zones")
	check(Progression.zoneAt(0) == 1, "z0 is plaster")
	check(Progression.zoneAt(Progression.zoneStart(2)) == 2, "zone 2 start")
	check(Progression.zoneAt(Progression.zoneStart(2) - 1) == 1, "zone 1 end")
	check(Progression.zoneAt(World.TunnelDepth - 1) == 10, "last layer is ruins")
	for i, z in Zones do
		check(z.index == i, "zone index " .. i)
		check(#z.palette >= 1, "palette " .. z.id)
		if i > 1 then
			check(z.hp > Zones[i - 1].hp, "zones get harder: " .. z.id)
			check(z.chamber ~= nil, "zone " .. i .. " has a chamber")
			local c = z.chamber :: any
			check(
				c.width <= World.TunnelWidth - 2 and c.height <= World.TunnelHeight - 2,
				"chamber fits " .. z.id
			)
			check(c.depth < z.depth, "chamber shorter than zone " .. z.id)
		end
	end

	-- hits
	check(Progression.hitsToBreak(30, 10) == 3, "30/10 = 3 hits")
	check(Progression.hitsToBreak(30, 11) == 3, "ceil")
	check(Progression.hitsToBreak(30, 30) == 1, "one hit")
	check(Progression.hitsToBreak(30, 1e9) == 1, "at least one hit")
	check(Progression.punchPower(10, 2, 0) == 20, "spoon doubles")
	check(Progression.crackStage(30, 30) == 0 and Progression.crackStage(1, 30) == 3, "crack stages")

	-- hashing is deterministic and roughly uniform
	check(Progression.hash01(5, 1, 2, 3, 1) == Progression.hash01(5, 1, 2, 3, 1), "deterministic")
	local sum, n = 0, 0
	for x = 0, 17 do
		for z = 0, 99 do
			sum += Progression.hash01(12345, x, 3, z, 1)
			n += 1
		end
	end
	check(math.abs(sum / n - 0.5) < 0.03, "hash mean ~0.5, got " .. sum / n)

	-- finds: every zone in the loot table has finds, rarities known, ore share near oreChance
	for _, f in Finds.List do
		check(Rarity.Tiers[f.rarity] ~= nil, "rarity " .. f.rarity)
		check(f.value > 0, "value " .. f.id)
	end
	local ore, total = 0, 0
	for x = 0, 17 do
		for y = 0, 11 do
			for z = 0, 24 do
				total += 1
				local id = Progression.findAt(999, x, y, z)
				if id then
					ore += 1
					check(Finds.ById[id].zone == 1, "plaster find from zone 1")
				end
			end
		end
	end
	check(math.abs(ore / total - Zones[1].oreChance) < 0.02, "ore share " .. ore / total)

	-- chambers
	for i = 2, #Zones do
		local b = Progression.chamberBox(i) :: any
		check(b ~= nil, "chamber box " .. i)
		check(Progression.chamberAt(b.x0, 0, b.z0) == i, "inside chamber " .. i)
		check(Progression.chamberAt(b.x0 - 1, 0, b.z0) == nil, "outside chamber " .. i)
		check(Progression.findAt(1, b.x0, 0, b.z0) == nil, "no finds in chambers")
	end

	-- brushes: sizes on a flat wall
	local g = Voxel.new(18, 12, 600, 8)
	local sizes = { 1, 5, 9, 13, 25 }
	for level, size in sizes do
		local t = Progression.brushTargets(g, 8, 5, 0, 6, level)
		check(#t == size, string.format("brush %d hits %d, got %d", level, size, #t))
	end
	-- at an edge the brush is clipped by the bedrock
	check(#Progression.brushTargets(g, 0, 0, 0, 6, 2) == 3, "corner cross = 3")
	-- a cross into a hole digs the block behind the hole
	Voxel.dig(g, 9, 5, 0)
	local t = Progression.brushTargets(g, 8, 5, 0, 6, 2)
	local behind = false
	for _, p in t do
		if p[1] == 9 and p[3] == 1 then
			behind = true
		end
	end
	check(behind, "brush reaches behind a hole")
	-- canDig filter
	check(#Progression.brushTargets(g, 8, 5, 0, 6, 1, function()
		return false
	end) == 0, "filtered")

	-- upgrades: costs rise, first upgrade is cheap
	for track, list in
		{
			Tools = Upgrades.Tools,
			Backpack = Upgrades.Backpack,
			FindSlots = Upgrades.FindSlots,
			Vacuum = Upgrades.Vacuum,
		} :: any
	do
		check(list[1].cost == 0, track .. " level 1 is free")
		for i = 2, #list do
			check(list[i].cost > list[i - 1].cost, track .. " costs rise")
			check(list[i].value > list[i - 1].value, track .. " values rise")
		end
	end
	check(Progression.nextCost("Tools", 1) == Upgrades.Tools[2].cost, "next cost")
	check(Progression.nextCost("Tools", Upgrades.Open.Tools) == nil, "closed levels can't be bought")
	-- collection sets
	check(#Progression.completedSets({}) == 0 and Progression.collectionMultiplier({}) == 1, "no sets")
	local z1: { [string]: boolean } = {}
	for _, f in Finds.ByZone[1] do
		z1[f.id] = true
	end
	check(#Progression.completedSets(z1) == 1, "zone 1 set complete")
	check(math.abs(Progression.collectionMultiplier(z1) - (1 + Economy.CollectionBonus)) < 1e-9, "set bonus")
	check(Progression.pickFind(1, 0) == Finds.ByZone[1][1].id, "pick first")
	check(Progression.pickFind(1, 0.9999) == Finds.ByZone[1][#Finds.ByZone[1]].id, "pick last")
	for zone = 1, Economy.OpenZones do
		check(Finds.ByZone[zone] ~= nil, "open zone " .. zone .. " has finds")
	end
	-- extras
	local stock = Progression.marketStock(20000)
	check(#stock == 3 and stock[1] ~= stock[2] and stock[2] ~= stock[3], "3 different market items")
	check(table.concat(stock) == table.concat(Progression.marketStock(20000)), "same stock all day")
	local differs = false
	for day = 20001, 20010 do
		if table.concat(Progression.marketStock(day)) ~= table.concat(stock) then
			differs = true
		end
	end
	check(differs, "stock rotates")
	check(Progression.itemPrice({ cost = 5 }, 9) == 5, "fixed price")
	check(Progression.itemPrice({ blocks = 10 }, 2) == 10 * Zones[2].rubble, "zone price")
	-- daily streak
	check(Progression.dailyStreak(0, 0, 100) == 1, "first daily = day 1")
	check(Progression.dailyStreak(99, 3, 100) == 4, "next day: streak +1")
	check(Progression.dailyStreak(99, Economy.DailyMaxStreak, 100) == Economy.DailyMaxStreak, "streak capped")
	check(Progression.dailyStreak(97, 6, 100) == 4, "a missed day halves the streak")
	check(Progression.dailyNoodles(3, 2) == Economy.DailyBlocks * Zones[2].rubble * 3, "daily noodles")
	local cal = Progression.dailyCalendar(1, false)
	check(#cal == Economy.DailyMaxStreak, "a pip per streak day")
	check(
		cal[#cal].uniform == Economy.DailyUniform and cal[#cal].dynamite > 0,
		"last day: uniform + dynamite"
	)
	check(cal[1].uniform == nil and cal[1].dynamite == 0, "day 1: only Noodles")
	check(cal[2].noodles == 2 * cal[1].noodles, "day 2 pays twice day 1")
	check(Progression.dailyCalendar(1, true)[Economy.DailyMaxStreak].uniform == nil, "uniform only once")
	local daily: any = nil
	for _, it in Extras.Uniforms do
		if it.id == Economy.DailyUniform then
			daily = it
		end
	end
	check(daily ~= nil and daily.daily == true, "the daily uniform exists and is never sold")
	-- unique find ids
	local seen = {}
	for _, f in Finds.List do
		check(not seen[f.id], "duplicate find id " .. f.id)
		seen[f.id] = true
	end
	-- every rarity appears somewhere
	for _, r in Rarity.Order do
		local any = false
		for _, f in Finds.List do
			if f.rarity == r then
				any = true
			end
		end
		check(any, "rarity in loot tables: " .. r)
	end
	-- gym meter
	check(Progression.meterPos(0, 1) == 0 and Progression.meterPos(0.5, 1) == 0.5, "meter sweeps")
	check(
		math.abs(Progression.meterPos(1.5, 1) - 0.5) < 1e-9 and Progression.meterPos(2, 1) == 0,
		"meter comes back"
	)
	check(Progression.liftQuality(0.5, 1) == "perfect", "center = perfect")
	check(Progression.liftQuality(0.5 + Economy.Gym[1].zone / 2 - 0.01, 1) == "good", "green = good")
	check(Progression.liftQuality(0.02, 1) == "miss", "edge = miss")
	check(Progression.liftReward(1, "miss", 5, 0) == 0, "miss gives nothing")
	check(Progression.liftReward(1, "good", 0, 0) == 1, "good = base")
	check(Progression.liftReward(1, "perfect", 0, 0) == 2, "perfect = x2")
	check(Progression.liftReward(3, "perfect", 100, 0) == 10 * 2 * Economy.LiftComboMax, "combo capped")
	check(Progression.liftCenter(1, 0) == 0.5, "first rep centered")
	local moved = false
	for station = 1, #Economy.Gym do
		for rep = 1, 200 do
			local c = Progression.liftCenter(station, rep)
			check(c >= 0.5 - Economy.LiftShift and c <= 0.5 + Economy.LiftShift, "center in range")
			check(
				c - Economy.Gym[station].zone / 2 > 0.02 and c + Economy.Gym[station].zone / 2 < 0.98,
				"zone on the bar"
			)
			moved = moved or math.abs(c - 0.5) > 0.1
		end
	end
	check(moved, "the zone moves")
	check(Progression.liftQuality(0.7, 1, 0.7) == "perfect", "moved center = perfect")
	check(Progression.liftQuality(0.5, 1, 0.75) == "miss", "old center misses")
	check(select(1, Progression.liftTier(0)) == 0, "no tier at 0")
	check(select(1, Progression.liftTier(Economy.LiftTiers[2].combo)) == 2, "tier 2")
	for i = 2, #Economy.Gym do
		check(Economy.Gym[i].zone < Economy.Gym[i - 1].zone, "heavier = harder")
	end
	check(Progression.bestStation(0) == 1 and Progression.bestStation(1e9) == #Economy.Gym, "gym stations")

	-- combo tiers: start at x1, climb in order, never drop while the chain grows
	check(Progression.comboMult(0) == 1, "no combo = x1")
	local lastMult = 0
	for hits = 0, 400 do
		local m = Progression.comboMult(hits)
		check(m >= lastMult, "combo multiplier never drops as the chain grows")
		lastMult = m
	end
	for i = 2, #World.ComboTiers do
		local t = World.ComboTiers[i]
		check(t.hits > World.ComboTiers[i - 1].hits, "combo tiers in order")
		check(Progression.comboTier(t.hits) == i, "tier " .. i .. " starts at its hit count")
		check(Progression.comboTier(t.hits - 1) == i - 1, "tier " .. i .. " not before it")
	end

	-- gold: deterministic, about the configured rate, never in a find or a chamber
	local gold, jackpots, n = 0, 0, 0
	for z = 0, 299 do
		for y = 0, World.TunnelHeight - 1 do
			for x = 0, World.TunnelWidth - 1 do
				local g = Progression.goldAt(4242, x, y, z)
				check(g == Progression.goldAt(4242, x, y, z), "goldAt is deterministic")
				if g then
					check(Progression.findAt(4242, x, y, z) == nil, "gold is never a find block")
					check(Progression.chamberAt(x, y, z) == nil, "gold is never in a chamber")
				end
				gold += if g == "gold" then 1 else 0
				jackpots += if g == "jackpot" then 1 else 0
				n += 1
			end
		end
	end
	local rate = gold / n
	check(
		rate > World.GoldChance * 0.6 and rate < World.GoldChance * 1.3,
		"gold rate near GoldChance: " .. rate
	)
	check(
		jackpots > 0 and jackpots < n * World.JackpotChance * 2.5,
		"some jackpots, not too many: " .. jackpots
	)
	check(Progression.goldBlocks("jackpot") > Progression.goldBlocks("gold"), "a jackpot beats gold")
	check(Progression.goldFactor() > 0 and Progression.goldFactor() < 0.5, "gold adds a modest share")

	-- cave-ins
	check(Progression.caveInChance(0) == 0, "nothing broken = no cave-in")
	check(Progression.caveInChance(9) > Progression.caveInChance(1), "more broken = likelier")
	check(Progression.caveInChance(9) < 0.5, "cave-ins stay rare")
	check(Progression.caveInFactor() > 1 and Progression.caveInFactor() < 1.3, "cave-ins: a modest speedup")

	-- vault doors: one per chamber zone, tougher and richer the deeper you go
	check(Progression.bossHp(1) == 0, "no door before zone 2")
	for zone = 3, #Zones do
		check(Progression.bossHp(zone) > Progression.bossHp(zone - 1), "doors get tougher: " .. zone)
		check(Progression.bossReward(zone) > Progression.bossReward(zone - 1), "doors pay more: " .. zone)
	end
	-- pity: an unfound find of the zone, never one you have; nil once the set is complete
	do
		local Finds = require("../src/shared/Config/Finds")
		local list = Finds.ByZone[1]
		local found: { [string]: boolean } = {}
		for k = 1, #list - 1 do
			found[list[k].id] = true
		end
		for _, roll in { 0, 0.5, 0.999 } do
			check(Progression.pickUnfound(1, found, roll) == list[#list].id, "pity picks the missing one")
		end
		check(Progression.missingInSet(1, found) == 1, "one missing")
		found[list[#list].id] = true
		check(Progression.pickUnfound(1, found, 0.3) == nil, "nothing left to pity")
		check(Progression.missingInSet(1, found) == 0, "set complete")
	end
end
