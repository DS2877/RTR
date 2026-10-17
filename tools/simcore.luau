--!strict
-- The economy model behind tools/simulate.luau and tools/tune.luau (no printing here).
-- Model: dig a 3x3 tunnel at the attack rate, vacuum (unless Auto-Vacuum), walk to the Yard when the
-- backpack is full, dump, lift at the gym for a bit, sell finds, buy the most wanted upgrade.
local Progression = require("../src/shared/Progression")
local Economy = require("../src/shared/Config/Economy")
local Upgrades = require("../src/shared/Config/Upgrades")
local World = require("../src/shared/Config/World")
local Zones = require("../src/shared/Config/Zones")
local Finds = require("../src/shared/Config/Finds")
local Format = require("../src/shared/Format")

local CROSS = 9 -- blocks per tunnel layer (3 wide x 3 high: room to walk)
local WALK = Economy.WalkSpeed -- studs per second
local BASE_TRIP = 170 -- studs from an average cell to the Yard dump via the Common Room
local GYM_SHARE = 0.15 -- on each trip a player lifts for this share of the time they just dug
local SHOP_TIME = 8 -- seconds per trip at the counters
-- nobody keeps punching one block 40 times: past this many hits a player farms a shallower zone
-- for Noodles (and upgrades) instead of pushing deeper
local MAX_HITS = 15
-- combos: real chains break (aiming, walking along the face), so a chain counts this share of the
-- punches since the last trip
local COMBO_EFF = 0.6

export type Result = {
	reached: { [number]: number }, -- zone -> seconds when first reached
	info: { [number]: string },
	hits: { [number]: { sum: number, n: number } }, -- frontier zone -> hits per punched block
	buys: { string },
	firstBuy: number?,
	finish: number, -- seconds when the run stopped
	farmed: { [number]: number }, -- frontier zone -> blocks farmed in shallower zones
	depth: number,
	strength: number,
	noodles: number,
}

local ALL = true
local LIMIT = 0

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

local function run(passes: boolean): Result
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
	local comboPunches = 0 -- punches since the last trip (the combo chain)
	local hitStats: { [number]: { sum: number, n: number } } = {}
	local farmed: { [number]: number } = {}

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
		local frontier = Progression.zoneAt(depth)
		local power = Progression.punchPower(strength, lv.Tools, 0) * Progression.critFactor()
		-- too tough to push on: farm wider in the deepest zone that still breaks comfortably
		local zone = frontier
		while zone > 1 and Progression.hitsToBreak(Zones[zone].hp, power) > MAX_HITS do
			zone -= 1
		end
		local farming = zone < frontier
		local hp = Zones[zone].hp
		local hits = Progression.hitsToBreak(hp, power)
		local hz = hitStats[frontier]
		if not hz then
			hz = { sum = 0, n = 0 }
			hitStats[frontier] = hz
		end
		hz.sum += hits
		hz.n += 1
		if farming then
			farmed[frontier] = (farmed[frontier] or 0) + 1
		end
		local brush = #Upgrades.Brushes[lv.Brushes].cells
		-- players dig as wide as their brush (more rubble per layer, see layerLeft), 80 % efficient
		local perPunch = brush * (if brush > 1 then 0.8 else 1)
		-- cave-ins bring extra blocks down for free
		local perBlock = hits * World.AttackInterval / perPunch / Progression.caveInFactor()
		-- vacuuming by hand costs time; a bigger vacuum range wastes less of it
		local vacuumCost = if passes then 0 else 0.35 / Progression.vacuumRange(lv.Vacuum) * 10
		perBlock *= 1 + vacuumCost
		local cap = Progression.capacity(lv.Backpack) * bagMult

		-- dig one block
		t += perBlock
		bag += 1
		comboPunches += hits / perPunch / Progression.caveInFactor()
		bagValue += Zones[zone].rubble * Progression.comboMult(comboPunches * COMBO_EFF)
		-- gold and jackpot blocks pay out on the spot
		noodles += Zones[zone].rubble * Progression.goldFactor() * noodleMult
		if findCount < Progression.findSlots(lv.FindSlots) then
			local chance = Zones[zone].oreChance
			findValue += chance * expectedFind(zone)
			findCount += chance
		end
		if not farming then
			layerLeft -= 1
		end
		if layerLeft <= 0 then
			depth += 1
			layerLeft = math.max(CROSS, #Upgrades.Brushes[lv.Brushes].cells)
			local z = Progression.zoneAt(depth)
			if not reached[z] and depth < maxDepth then
				-- the vault door in front of the new zone's chamber: single-target punches
				local doorHp = Progression.bossHp(z)
				if doorHp > 0 then
					t += math.ceil(doorHp / power) * World.AttackInterval
					noodles += Progression.bossReward(z) * noodleMult
				end
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
			comboPunches = 0
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

	return {
		reached = reached,
		info = info,
		hits = hitStats,
		farmed = farmed,
		buys = buys,
		firstBuy = firstBuy,
		finish = t,
		depth = depth,
		strength = strength,
		noodles = noodles,
	}
end

-- all = every zone and upgrade open; limit = seconds before the run gives up
return function(passes: boolean, all: boolean, limit: number): Result
	ALL = all
	LIMIT = limit
	return run(passes)
end
