--!strict
-- Pure balance math (no Roblox APIs) so Lune can test it.

-- Works in Roblox (script.Parent) and in Lune tests (relative path requires).
local function config(name: string): any
	if script then
		return (require :: any)((script :: any).Parent.Config[name])
	end
	return (require :: any)("./Config/" .. name)
end

local Economy = config("Economy")
local Vaults = config("Vaults")
local Rarity = config("Rarity")
local Mutations = config("Mutations")

local Progression = {}

export type ItemInfo = {
	id: string,
	name: string,
	emoji: string,
	shape: string,
	color: { number },
	rarity: string,
	vault: number,
	baseIncome: number,
}

local byId: { [string]: ItemInfo } = {}
for vaultIndex, vault in Vaults do
	for rarityIndex, it in vault.items do
		local rarity = Rarity.Order[rarityIndex]
		byId[it.id] = {
			id = it.id,
			name = it.name,
			emoji = it.emoji,
			shape = it.shape,
			color = it.color,
			rarity = rarity,
			vault = vaultIndex,
			baseIncome = vault.baseIncome * Rarity.Tiers[rarity].mult,
		}
	end
end

function Progression.item(id: string): ItemInfo?
	return byId[id]
end

function Progression.allItems(): { [string]: ItemInfo }
	return byId
end

-- $/s of one item (before player multipliers)
function Progression.income(id: string, mutation: string?): number
	local info = byId[id]
	if not info then
		return 0
	end
	local m = Mutations.List[mutation or "None"]
	return info.baseIncome * (if m then m.mult else 1)
end

function Progression.sellValue(id: string, mutation: string?): number
	return math.floor(Progression.income(id, mutation) * Economy.SellSeconds)
end

function Progression.walkSpeed(points: number): number
	local s = Economy.Speed
	local v = s.Base + s.PerDoubling * math.log(1 + math.max(0, points) / s.Unit, 2)
	return math.min(s.Max, v)
end

function Progression.treadmillRate(level: number): number
	local t = Economy.Treadmill
	return t.Rate * t.Growth ^ (level - 1)
end

-- Cost to go from `level` to `level + 1`, or nil at max.
function Progression.treadmillCost(level: number): number?
	local t = Economy.Treadmill
	if level >= t.MaxLevel then
		return nil
	end
	return math.floor(t.Cost * t.CostGrowth ^ (level - 1))
end

function Progression.pedestals(level: number): number
	local p = Economy.Plot
	return p.StartPedestals + p.PerLevel * (math.min(level, p.MaxLevel) - 1)
end

function Progression.plotCost(level: number): number?
	local p = Economy.Plot
	if level >= p.MaxLevel then
		return nil
	end
	return math.floor(p.Cost * p.CostGrowth ^ (level - 1))
end

-- Weighted rarity pick. `r` in [0, 1).
function Progression.rollRarity(r: number): string
	local total = 0
	for _, id in Rarity.Order do
		total += Rarity.Tiers[id].weight
	end
	local x = r * total
	for _, id in Rarity.Order do
		x -= Rarity.Tiers[id].weight
		if x < 0 then
			return id
		end
	end
	return Rarity.Order[1]
end

-- Mutation pick (rarest first). `r` in [0, 1).
function Progression.rollMutation(r: number): string
	local acc = 0
	for i = #Mutations.Order, 2, -1 do
		local m = Mutations.List[Mutations.Order[i]]
		acc += m.chance
		if r < acc then
			return m.id
		end
	end
	return "None"
end

-- The item id for a vault + rarity.
function Progression.vaultItem(vaultIndex: number, rarity: string): string
	local vault = Vaults[vaultIndex]
	for i, id in Rarity.Order do
		if id == rarity then
			return vault.items[i].id
		end
	end
	return vault.items[1].id
end

-- Walk speed you need to outrun a vault's guards while carrying its Common loot.
function Progression.speedToOutrun(vaultIndex: number): number
	return Vaults[vaultIndex].guardSpeed / Economy.CarrySlowdown.Common
end

-- Treadmill points needed to reach a walk speed (inverse of walkSpeed).
function Progression.pointsFor(speed: number): number
	local s = Economy.Speed
	return s.Unit * (2 ^ ((speed - s.Base) / s.PerDoubling) - 1)
end

return Progression
