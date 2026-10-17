--!strict
-- LIFER'S LOCKER math (no Roblox APIs): perk levels -> effects, costs, Freedom Points per escape.
-- `perks` is { [perkId]: level } (the profile's Locker.Perks, or built from the Perk<id> player
-- attributes on the client). Same answers on server, client and in Lune.

local function config(name: string): any
	if script then
		return (require :: any)((script :: any).Parent.Config[name])
	end
	return (require :: any)("./Config/" .. name)
end
local Config = config("Locker")

export type Perks = { [string]: number }

local Locker = {}

local byId: { [string]: any } = {}
for _, p in Config.Perks do
	byId[p.id] = p
end

function Locker.perk(id: string): any
	return byId[id]
end

-- Player attribute that mirrors a perk's level (Services/Locker writes it).
function Locker.attr(id: string): string
	return "Perk" .. id
end

-- Level 0..max of a perk (anything odd counts as 0).
function Locker.level(perks: Perks?, id: string): number
	local p = byId[id]
	local n = perks and perks[id]
	if not p or typeof(n) ~= "number" or n ~= n then
		return 0
	end
	return math.clamp(math.floor(n), 0, #p.levels)
end

-- The value of the perk's current level (0 when not owned).
function Locker.value(perks: Perks?, id: string): number
	local lv = Locker.level(perks, id)
	if lv <= 0 then
		return 0
	end
	return byId[id].levels[lv].value
end

-- FP for the next level, or nil when maxed / unknown.
function Locker.nextCost(perks: Perks?, id: string): number?
	local p = byId[id]
	if not p then
		return nil
	end
	local nxt = p.levels[Locker.level(perks, id) + 1]
	return if nxt then nxt.cost else nil
end

-- Only known perks with whole levels in range survive (profile load).
function Locker.sanitize(perks: any): Perks
	local out: Perks = {}
	if typeof(perks) ~= "table" then
		return out
	end
	for id in perks do
		if typeof(id) == "string" and byId[id] then
			local lv = Locker.level(perks, id)
			if lv > 0 then
				out[id] = lv
			end
		end
	end
	return out
end

-- ===== effects =====

function Locker.powerMult(perks: Perks?): number
	return 1 + Locker.value(perks, "QuickHands")
end

function Locker.slotBonus(perks: Perks?): number
	return Locker.value(perks, "DeepPockets")
end

-- Multiplier on upgrade prices (Bargain Hunter).
function Locker.priceMult(perks: Perks?): number
	return 1 - Locker.value(perks, "Bargain")
end

function Locker.keepStrength(perks: Perks?): number
	return Locker.value(perks, "MuscleMemory")
end

function Locker.nightBonus(perks: Perks?): number
	return Locker.value(perks, "NightOwl")
end

-- Upgrade levels a run starts with (Head Start): track -> level ({} without the perk).
function Locker.headStart(perks: Perks?): { [string]: number }
	local lv = Locker.level(perks, "HeadStart")
	if lv <= 0 then
		return {}
	end
	return byId.HeadStart.levels[lv].start or {}
end

-- Strength after an escape: the kept share (never under the starting strength).
function Locker.strengthAfterEscape(perks: Perks?, strength: number, starting: number): number
	return math.max(starting, math.floor(strength * Locker.keepStrength(perks)))
end

-- ===== Freedom Points =====

-- FP an escape earns right away: base, +fast when the run took at most FastMinutes of playtime.
function Locker.escapePoints(runMinutes: number): number
	local p = Config.Points
	return p.Base + (if runMinutes >= 0 and runMinutes <= p.FastMinutes then p.Fast else 0)
end

-- FP THE BREAKOUT's medal adds on top.
function Locker.medalPoints(medal: string): number
	return if medal == "gold" then Config.Points.Gold else 0
end

-- FP still needed to buy every perk to the max.
function Locker.remainingCost(perks: Perks?): number
	local total = 0
	for _, p in Config.Perks do
		for i = Locker.level(perks, p.id) + 1, #p.levels do
			total += p.levels[i].cost
		end
	end
	return total
end

return Locker
