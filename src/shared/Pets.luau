--!strict
-- Pet math (no Roblox APIs): levels from XP, perk strength, slots, prices, a loadout's bonuses.
-- Server (Services/Pets), client (Controllers/Pets) and the balance sim all use it.

local function config(name: string): any
	if script then
		return (require :: any)((script :: any).Parent.Config[name])
	end
	return (require :: any)("./Config/" .. name)
end
local Config = config("Pets")
local Zones = config("Zones")

local Pets = {}

local byId: { [string]: any } = {}
for _, p in Config.List do
	byId[p.id] = p
end

function Pets.get(id: string): any
	return byId[id]
end

-- XP to go from `level` to `level + 1`.
function Pets.xpFor(level: number): number
	return math.floor(Config.XpBase * level ^ Config.XpPower)
end

-- (level, xp into this level, xp needed for the next) from total XP.
function Pets.level(xp: number): (number, number, number)
	local level, left = 1, math.max(0, xp)
	while level < Config.MaxLevel and left >= Pets.xpFor(level) do
		left -= Pets.xpFor(level)
		level += 1
	end
	return level, left, if level >= Config.MaxLevel then 0 else Pets.xpFor(level)
end

-- The pet's perk at a level (a share: 0.1 = +10 %, or the dig pet's punch-power multiple).
function Pets.perk(id: string, level: number): number
	local p = byId[id]
	if not p then
		return 0
	end
	return p.base + p.perLevel * (math.clamp(level, 1, Config.MaxLevel) - 1)
end

function Pets.slots(rebirths: number): number
	local n = 0
	for _, r in Config.SlotRebirths do
		if rebirths >= r then
			n += 1
		end
	end
	return n
end

function Pets.price(id: string): number
	local p = byId[id]
	if not p then
		return math.huge
	end
	return p.blocks * Zones[math.clamp(p.zone, 1, #Zones)].rubble
end

-- Total bonus of one perk over the equipped pets ({ id = xp } owned, { id } equipped).
function Pets.bonus(owned: { [string]: number }, equipped: { string }, perk: string): number
	local sum = 0
	for _, id in equipped do
		local p = byId[id]
		if p and p.perk == perk and owned[id] then
			sum += Pets.perk(id, (Pets.level(owned[id])))
		end
	end
	return sum
end

-- How a short perk text reads in the shop ("+12% punch power").
function Pets.perkText(id: string, level: number): string
	local p = byId[id]
	if not p then
		return ""
	end
	local v = Pets.perk(id, level)
	local pct = math.floor(v * 100 + 0.5)
	if p.perk == "value" then
		return "+" .. pct .. "% Noodles from rubble"
	elseif p.perk == "power" then
		return "+" .. pct .. "% punch power"
	elseif p.perk == "finds" then
		return "+" .. pct .. "% find chance"
	elseif p.perk == "vacuum" then
		return "auto-vacuum, +" .. pct .. "% range"
	elseif p.perk == "dig" then
		return string.format("digs a block every %gs (%d%% power)", config("Pets").DigInterval, pct)
	elseif p.perk == "gold" then
		return "+" .. pct .. "% gold payout"
	end
	return ""
end

return Pets
