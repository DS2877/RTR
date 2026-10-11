--!strict
-- Rarity tiers: spawn weight in vault pedestals, income multiplier inside a vault, colors.

export type Tier = {
	id: string,
	weight: number, -- relative spawn weight on a vault pedestal
	mult: number, -- income multiplier on top of the vault's base income
	color: { number },
	glow: boolean, -- light + sparkles on the item model
}

local Rarity = {
	Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" },
	Tiers = {
		Common = { id = "Common", weight = 55, mult = 1, color = { 200, 200, 205 }, glow = false },
		Uncommon = { id = "Uncommon", weight = 25, mult = 2.5, color = { 90, 220, 110 }, glow = false },
		Rare = { id = "Rare", weight = 12, mult = 6, color = { 70, 160, 255 }, glow = false },
		Epic = { id = "Epic", weight = 5.5, mult = 15, color = { 180, 90, 255 }, glow = true },
		Legendary = { id = "Legendary", weight = 2, mult = 40, color = { 255, 190, 40 }, glow = true },
		Mythic = { id = "Mythic", weight = 0.5, mult = 120, color = { 255, 70, 140 }, glow = true },
	} :: { [string]: Tier },
}

return Rarity
