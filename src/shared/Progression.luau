--!strict
-- Pure balance and digging math (no Roblox APIs) so Lune can test it and simulate it.

-- Works in Roblox (script.Parent) and in Lune (relative path requires).
local function shared(name: string): any
	if script then
		return (require :: any)((script :: any).Parent[name])
	end
	return (require :: any)("./" .. name)
end
local function config(name: string): any
	if script then
		return (require :: any)((script :: any).Parent.Config[name])
	end
	return (require :: any)("./Config/" .. name)
end

local Voxel = shared("Voxel")
local World = config("World")
local Zones = config("Zones")
local Finds = config("Finds")
local Upgrades = config("Upgrades")
local Economy = config("Economy")
local Extras = config("Extras")

local Progression = {}

-- ===== zones =====

local zoneStart: { number } = {}
do
	local z = 0
	for i, zone in Zones do
		zoneStart[i] = z
		z += zone.depth
	end
	assert(z == World.TunnelDepth, "zone depths must add up to World.TunnelDepth")
end

function Progression.zoneStart(index: number): number
	return zoneStart[index] or World.TunnelDepth
end

-- Zone index of a depth layer (z).
function Progression.zoneAt(z: number): number
	for i = #Zones, 1, -1 do
		if z >= zoneStart[i] then
			return i
		end
	end
	return 1
end

-- Layers deeper than this can't be dug yet (zones open with the milestones).
function Progression.diggableDepth(): number
	-- ===== extras (Laundry / Mess Hall / Black Market / Decor) =====

	-- Noodles price of an Extras item for someone whose deepest zone is `zone`.
	function Progression.itemPrice(item: any, zone: number): number
		if item.cost then
			return item.cost
		end
		local z = Zones[math.clamp(zone, 1, #Zones)]
		return (item.blocks or 0) * z.rubble
	end

	-- The Black Market's stock on a given day (days since 1970): MarketSlots different item ids.
	function Progression.marketStock(day: number): { string }
		local pool = {}
		for i, item in Extras.Market do
			table.insert(pool, { id = item.id, roll = Progression.hash01(day, i, 0, 0, 77) })
		end
		table.sort(pool, function(a, b)
			return a.roll < b.roll
		end)
		local out = {}
		for i = 1, math.min(Extras.MarketSlots, #pool) do
			table.insert(out, pool[i].id)
		end
		return out
	end

	return Progression.zoneStart(Economy.OpenZones + 1)
end

-- ===== punching =====

function Progression.rebirthMultiplier(rebirths: number): number
	return 1 + rebirths * 0.5
end

function Progression.punchPower(strength: number, toolLevel: number, rebirths: number, boost: number?): number
	local tool = Upgrades.Tools[toolLevel] or Upgrades.Tools[1]
	return strength * tool.value * Progression.rebirthMultiplier(rebirths) * (boost or 1)
end

function Progression.hitsToBreak(hp: number, power: number): number
	if power <= 0 then
		return math.huge
	end
	return math.max(1, math.ceil(hp / power - 1e-9))
end

function Progression.blockHp(z: number): number
	return Zones[Progression.zoneAt(z)].hp
end

-- Crack stage 0..3 shown on a damaged block.
function Progression.crackStage(hpLeft: number, hpMax: number): number
	if hpLeft >= hpMax then
		return 0
	end
	return math.clamp(math.ceil((1 - hpLeft / hpMax) * 3), 1, 3)
end

-- ===== deterministic hashing (finds and block colors) =====

local TWO32 = 4294967296

local function mix(h: number, v: number): number
	h = bit32.bxor(h, v % TWO32)
	h = (h * 1664525 + 1013904223) % TWO32
	return bit32.bxor(h, bit32.rshift(h, 13))
end

-- Uniform 0..1 from (seed, x, y, z, salt). Same answer on server, client and in Lune.
function Progression.hash01(seed: number, x: number, y: number, z: number, salt: number): number
	local h = mix(2166136261, seed)
	h = mix(h, x + 1)
	h = mix(h, y + 7919)
	h = mix(h, z + 104729)
	h = mix(h, salt)
	h = mix(h, salt + 31)
	return h / TWO32
end

-- ===== chambers (the pre-built room at the start of each zone) =====

export type Box = { x0: number, y0: number, z0: number, x1: number, y1: number, z1: number } -- inclusive

local chamberBoxes: { [number]: Box } = {}
for i, zone in Zones do
	local c = zone.chamber
	if c then
		local x0 = (World.TunnelWidth - c.width) // 2
		local z0 = zoneStart[i]
		chamberBoxes[i] = {
			x0 = x0,
			y0 = 0,
			z0 = z0,
			x1 = x0 + c.width - 1,
			y1 = c.height - 1,
			z1 = z0 + c.depth - 1,
		}
	end
end

function Progression.chamberBox(zone: number): Box?
	return chamberBoxes[zone]
end

-- Zone index if (x, y, z) is inside a chamber, else nil.
function Progression.chamberAt(x: number, y: number, z: number): number?
	local zone = Progression.zoneAt(z)
	local b = chamberBoxes[zone]
	if b and x >= b.x0 and x <= b.x1 and y >= b.y0 and y <= b.y1 and z >= b.z0 and z <= b.z1 then
		return zone
	end
	return nil
end

-- ===== finds =====

-- Weighted pick from a zone's loot table with roll in 0..1 (nil if the zone has no finds).
function Progression.pickFind(zoneIndex: number, roll01: number): string?
	local list = Finds.ByZone[zoneIndex]
	if not list then
		return nil
	end
	local total = 0
	for _, f in list do
		total += f.weight
	end
	local roll = roll01 * total
	for _, f in list do
		roll -= f.weight
		if roll < 0 then
			return f.id
		end
	end
	return list[#list].id
end

-- The find inside block (x, y, z) of a tunnel with this seed, or nil. Deterministic.
function Progression.findAt(seed: number, x: number, y: number, z: number): string?
	if Progression.chamberAt(x, y, z) then
		return nil
	end
	local zoneIndex = Progression.zoneAt(z)
	local zone = Zones[zoneIndex]
	if not Finds.ByZone[zoneIndex] or Progression.hash01(seed, x, y, z, 1) >= zone.oreChance then
		return nil
	end
	-- ===== extras (Laundry / Mess Hall / Black Market / Decor) =====

	-- Noodles price of an Extras item for someone whose deepest zone is `zone`.
	function Progression.itemPrice(item: any, zone: number): number
		if item.cost then
			return item.cost
		end
		local z = Zones[math.clamp(zone, 1, #Zones)]
		return (item.blocks or 0) * z.rubble
	end

	-- The Black Market's stock on a given day (days since 1970): MarketSlots different item ids.
	function Progression.marketStock(day: number): { string }
		local pool = {}
		for i, item in Extras.Market do
			table.insert(pool, { id = item.id, roll = Progression.hash01(day, i, 0, 0, 77) })
		end
		table.sort(pool, function(a, b)
			return a.roll < b.roll
		end)
		local out = {}
		for i = 1, math.min(Extras.MarketSlots, #pool) do
			table.insert(out, pool[i].id)
		end
		return out
	end

	return Progression.pickFind(zoneIndex, Progression.hash01(seed, x, y, z, 2))
end

-- Zones whose whole find set is in `found` (the collection album).
function Progression.completedSets(found: { [string]: boolean }): { number }
	local out = {}
	for zone, list in Finds.ByZone do
		local all = #list > 0
		for _, f in list do
			if not found[f.id] then
				all = false
			end
		end
		if all then
			table.insert(out, zone)
		end
	end
	table.sort(out)
	return out
end

-- Permanent Noodles multiplier from completed collection sets.
function Progression.collectionMultiplier(found: { [string]: boolean }): number
	return 1 + #Progression.completedSets(found) * Economy.CollectionBonus
end

function Progression.findValue(id: string): number
	local f = Finds.ById[id]
	return if f then f.value else 0
end

-- ===== brushes =====

-- Plane axes for a face normal: u (across) and v (up) in the face plane.
local function planeAxes(n: { number }): ({ number }, { number })
	if n[1] ~= 0 then
		return { 0, 0, 1 }, { 0, 1, 0 }
	elseif n[2] ~= 0 then
		return { 1, 0, 0 }, { 0, 0, 1 }
	end
	return { 1, 0, 0 }, { 0, 1, 0 }
end

-- Blocks one punch hits: for each brush cell, the first exposed solid block along the punch
-- direction (from one layer in front of the aimed block to BrushDepth layers behind it).
-- `canDig(x, y, z)` filters blocks that may not be dug (too deep, etc.).
function Progression.brushTargets(
	grid: any,
	x: number,
	y: number,
	z: number,
	face: number,
	brushLevel: number,
	canDig: ((number, number, number) -> boolean)?
): { { number } }
	local n = Voxel.Faces[face]
	local brush = Upgrades.Brushes[brushLevel] or Upgrades.Brushes[1]
	local u, v = planeAxes(n)
	local out = {}
	for _, cell in brush.cells do
		local a, b = cell[1], cell[2]
		local bx = x + u[1] * a + v[1] * b
		local by = y + u[2] * a + v[2] * b
		local bz = z + u[3] * a + v[3] * b
		for k = -1, World.BrushDepth - 1 do
			local px, py, pz = bx - n[1] * k, by - n[2] * k, bz - n[3] * k
			if Voxel.isExposed(grid, px, py, pz) and (canDig == nil or canDig(px, py, pz)) then
				table.insert(out, { px, py, pz })
				break
			end
		end
	end
	return out
end

-- ===== upgrades / economy =====

function Progression.upgrade(track: string, level: number): any
	return (Upgrades :: any)[track][level]
end

-- Cost of the next level, or nil when maxed / not open yet.
function Progression.nextCost(track: string, level: number): number?
	local open = Upgrades.Open[track] or 0
	local nextLevel = (Upgrades :: any)[track][level + 1]
	if not nextLevel or level + 1 > open then
		return nil
	end
	return nextLevel.cost
end

function Progression.capacity(level: number): number
	return (Upgrades.Backpack[level] or Upgrades.Backpack[1]).value
end

function Progression.findSlots(level: number): number
	return (Upgrades.FindSlots[level] or Upgrades.FindSlots[1]).value
end

function Progression.vacuumRange(level: number): number
	return (Upgrades.Vacuum[level] or Upgrades.Vacuum[1]).value
end

-- Best gym station this strength may use (index into Economy.Gym).
function Progression.bestStation(strength: number): number
	local best = 1
	for i, st in Economy.Gym do
		if strength >= st.minStrength then
			best = i
		end
	end
	return best
end

-- The gym's timing meter: the needle sweeps 0 -> 1 -> 0 (`speed` sweeps per second).
function Progression.meterPos(elapsed: number, speed: number): number
	local t = (math.max(0, elapsed) * speed) % 2
	return if t < 1 then t else 2 - t
end

-- Where the green zone sits for rep number `rep` (0 = the first rep: dead center). Deterministic,
-- so the server and the client agree without sending it.
function Progression.liftCenter(station: number, rep: number): number
	if rep <= 0 then
		return 0.5
	end
	local h = math.sin(station * 12.9898 + rep * 78.233) * 43758.5453
	local r = h - math.floor(h) -- 0..1
	return 0.5 + (r * 2 - 1) * Economy.LiftShift
end

-- "perfect" (gold center), "good" (green zone) or "miss" for a needle position.
function Progression.liftQuality(pos: number, station: number, center: number?): string
	local st = Economy.Gym[station] or Economy.Gym[1]
	local d = math.abs(pos - (center or 0.5))
	if d <= st.perfect / 2 then
		return "perfect"
	elseif d <= st.zone / 2 then
		return "good"
	end
	return "miss"
end

-- Strength for one rep: miss = 0, good = base, perfect = x LiftPerfect with a combo bonus.
function Progression.liftReward(
	station: number,
	quality: string,
	combo: number,
	rebirths: number,
	multiplier: number?
): number
	if quality == "miss" then
		return 0
	end
	local base = Progression.liftGain(station, rebirths, multiplier)
	if quality == "good" then
		return base
	end
	local comboMult = 1 + math.min(combo * Economy.LiftComboStep, Economy.LiftComboMax - 1)
	return math.floor(base * Economy.LiftPerfect * comboMult)
end

-- Average damage multiplier from CRITs (the balance sim uses it).
function Progression.critFactor(): number
	return 1 + World.CritChance * (World.CritMult - 1)
end

-- The combo milestone reached at `combo` perfects in a row (nil below the first one).
function Progression.liftTier(combo: number): (number, any)
	local found, tier = 0, nil
	for i, t in Economy.LiftTiers do
		if combo >= t.combo then
			found, tier = i, t
		end
	end
	return found, tier
end

function Progression.liftGain(station: number, rebirths: number, multiplier: number?): number
	local st = Economy.Gym[station] or Economy.Gym[1]
	return math.floor(st.gain * Progression.rebirthMultiplier(rebirths) * (multiplier or 1))
end

-- ===== extras (Laundry / Mess Hall / Black Market / Decor) =====

-- Noodles price of an Extras item for someone whose deepest zone is `zone`.
function Progression.itemPrice(item: any, zone: number): number
	if item.cost then
		return item.cost
	end
	local z = Zones[math.clamp(zone, 1, #Zones)]
	return (item.blocks or 0) * z.rubble
end

-- The Black Market's stock on a given day (days since 1970): MarketSlots different item ids.
function Progression.marketStock(day: number): { string }
	local pool = {}
	for i, item in Extras.Market do
		table.insert(pool, { id = item.id, roll = Progression.hash01(day, i, 0, 0, 77) })
	end
	table.sort(pool, function(a, b)
		return a.roll < b.roll
	end)
	local out = {}
	for i = 1, math.min(Extras.MarketSlots, #pool) do
		table.insert(out, pool[i].id)
	end
	return out
end

return Progression
