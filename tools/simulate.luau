--!strict
-- Economy simulation: time to reach each zone for a free player and for a player with every pass.
--   lune run tools/simulate          (zones open right now)
--   lune run tools/simulate all      (pretend every zone and upgrade is open: long-term pacing)
-- Model: dig a 3x3 tunnel at the attack rate, vacuum (unless Auto-Vacuum), walk to the Yard when the
-- backpack is full, dump, lift at the gym for a bit, sell finds, buy the most wanted upgrade.
local process = require("@lune/process")
local Progression = require("../src/shared/Progression")
local Economy = require("../src/shared/Config/Economy")
local Upgrades = require("../src/shared/Config/Upgrades")
local World = require("../src/shared/Config/World")
local Zones = require("../src/shared/Config/Zones")
local Finds = require("../src/shared/Config/Finds")
local Format = require("../src/shared/Format")

local ALL = process.args[1] == "all"
local CROSS = 9 -- blocks per tunnel layer (3 wide x 3 high: room to walk)
local WALK = Economy.WalkSpeed -- studs per second
local BASE_TRIP = 170 -- studs from an average cell to the Yard dump via the Common Room
local GYM_SHARE = 0.15 -- on each trip a player lifts for this share of the time they just dug
local SHOP_TIME = 8 -- seconds per trip at the counters
local LIMIT = if ALL then 60 * 60 * 24 * 30 else 60 * 60 * 6

local function expectedFind(zone: number): number
	local list = Finds.ByZone[zone]
	if not list then
		return 0
	end
	local w, v = 0, 0
	for _, f in list do
		w += f.weight
		v += f.weight * f.value
	end
	return v / w
end

local function open(track: string): number
	return if ALL then #(Upgrades :: any)[track] else Upgrades.Open[track]
end

local function run(passes: boolean)
	local noodleMult = if passes then Economy.PassEffects.DoubleNoodles else 1
	local strengthMult = if passes then Economy.PassEffects.DoubleStrength else 1
	local bagMult = if passes then Economy.PassEffects.HugeBackpack else 1
	local maxDepth = if ALL then World.TunnelDepth else Progression.diggableDepth()

	local t, noodles, strength = 0, Economy.StartingNoodles, Economy.StartingStrength
	local lv = { Tools = 1, Brushes = 1, Backpack = 1, FindSlots = 1, Vacuum = 1 }
	local depth, layerLeft = 0, CROSS
	local bag, bagValue, findValue, findCount = 0, 0, 0, 0
	local reached: { [number]: number } = { [1] = 0 }
	local info: { [number]: string } = { [1] = "" }
	local buys: { string } = {}
	local firstBuy: number? = nil
	local lastTrip = 0

	-- the upgrade this player is saving for: (track, cost); tools and brushes count double
	local function wanted(): (string?, number)
		local bestTrack, bestCost, bestScore = nil :: string?, math.huge, math.huge
		for track, level in lv do
			local nxt = (Upgrades :: any)[track][level + 1]
			local score = if nxt
				then nxt.cost * (if track == "Tools" or track == "Brushes" then 0.5 else 1)
				else math.huge
			if nxt and level + 1 <= open(track) and score < bestScore then
				bestTrack, bestCost, bestScore = track, nxt.cost, score
			end
		end
		return bestTrack, bestCost
	end

	while t < LIMIT and depth < maxDepth do
		local zone = Progression.zoneAt(depth)
		local hp = Zones[zone].hp
		local power = Progression.punchPower(strength, lv.Tools, 0)
		local hits = Progression.hitsToBreak(hp, power)
		local brush = #Upgrades.Brushes[lv.Brushes].cells
		local perPunch = math.min(brush, CROSS) * (if brush > 1 then 0.8 else 1)
		local perBlock = hits * World.AttackInterval / perPunch
		-- vacuuming by hand costs time; a bigger vacuum range wastes less of it
		local vacuumCost = if passes then 0 else 0.35 / Progression.vacuumRange(lv.Vacuum) * 10
		perBlock *= 1 + vacuumCost
		local cap = Progression.capacity(lv.Backpack) * bagMult

		-- dig one block
		t += perBlock
		bag += 1
		bagValue += Zones[zone].rubble
		if findCount < Progression.findSlots(lv.FindSlots) then
			local chance = Zones[zone].oreChance
			findValue += chance * expectedFind(zone)
			findCount += chance
		end
		layerLeft -= 1
		if layerLeft <= 0 then
			depth += 1
			layerLeft = CROSS
			local z = Progression.zoneAt(depth)
			if not reached[z] and depth < maxDepth then
				reached[z] = t
				local p = Progression.punchPower(strength, lv.Tools, 0)
				info[z] = string.format(
					"power %s (%s x %s), %d hits/block, %s",
					Format.number(p),
					Format.number(strength),
					Upgrades.Tools[lv.Tools].name,
					Progression.hitsToBreak(Zones[z].hp, p),
					Upgrades.Brushes[lv.Brushes].name
				)
			end
		end

		local _, goal = wanted()
		if bag >= cap or (bag >= 10 and noodles + (bagValue + findValue) * noodleMult >= goal) then
			-- trip: out of the tunnel, Yard (dump + gym), Common Room (sell + shop), back
			-- (the very first trip goes straight to the shop: nobody lifts before their first upgrade)
			local gym = if firstBuy then (t - lastTrip) * GYM_SHARE else 0
			t += (depth * World.BlockSize * 2 + BASE_TRIP * 2) / WALK + gym + SHOP_TIME
			lastTrip = t
			noodles += bagValue * noodleMult + findValue * noodleMult
			bag, bagValue, findValue, findCount = 0, 0, 0, 0
			local station = Progression.bestStation(strength)
			strength += Progression.liftGain(station, 0, strengthMult) * math.floor(
				gym / Economy.LiftInterval
			)
			-- buy the most wanted open upgrade, saving up for it
			while true do
				local bestTrack, bestCost = wanted()
				if not bestTrack or bestCost > noodles then
					break
				end
				noodles -= bestCost
				lv[bestTrack] += 1
				firstBuy = firstBuy or t
				table.insert(
					buys,
					string.format(
						"%7s %-10s %s",
						Format.duration(t),
						bestTrack,
						(Upgrades :: any)[bestTrack][lv[bestTrack]].name
					)
				)
			end
		end
	end

	print(
		if passes
			then "\n== WITH PASSES (2x Noodles, 2x Strength, Huge Backpack, Auto-Vacuum) =="
			else "\n== FREE PLAYER =="
	)
	print(string.format("first upgrade after %s", if firstBuy then Format.duration(firstBuy) else "never"))
	for z = 1, #Zones do
		if reached[z] then
			print(
				string.format(
					"  zone %2d %-20s at %-8s %s",
					z,
					Zones[z].name,
					Format.duration(reached[z]),
					info[z] or ""
				)
			)
		end
	end
	print(
		string.format(
			"  depth %d after %s, strength %s, noodles left %s",
			depth,
			Format.duration(t),
			Format.number(strength),
			Format.number(noodles)
		)
	)
	print("  purchases:")
	for i, line in buys do
		if i <= 40 then
			print("   " .. line)
		end
	end
	return reached, firstBuy
end

local free, firstFree = run(false)
run(true)

-- balance targets (warn only)
local function target(name: string, actual: number?, maxSeconds: number)
	local ok = actual ~= nil and actual <= maxSeconds
	print(
		string.format(
			"%s %-28s %s (target <= %s)",
			if ok then "OK  " else "MISS",
			name,
			if actual then Format.duration(actual) else "never",
			Format.duration(maxSeconds)
		)
	)
end
print("\n== TARGETS (free player) ==")
target("first upgrade", firstFree, 60)
target("zone 2", free[2], 6 * 60)
target("zone 3", free[3], 17 * 60)
