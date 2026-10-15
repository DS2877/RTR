--!strict
local Progression = require("../src/shared/Progression")
local Voxel = require("../src/shared/Voxel")
local Zones = require("../src/shared/Config/Zones")
local Finds = require("../src/shared/Config/Finds")
local Rarity = require("../src/shared/Config/Rarity")
local Upgrades = require("../src/shared/Config/Upgrades")
local World = require("../src/shared/Config/World")
local Economy = require("../src/shared/Config/Economy")

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
	check(Progression.bestStation(0) == 1 and Progression.bestStation(1e9) == #Economy.Gym, "gym stations")
end
