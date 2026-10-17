--!strict
-- The 9 rarity tiers of finds. `glow` = light + glint on the ore block and the find card.

export type Tier = {
	id: string,
	rank: number,
	color: { number },
	glow: boolean,
}

local Rarity = {
	Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Cosmic", "Divine" },
	Tiers = {
		Common = { id = "Common", rank = 1, color = { 205, 205, 210 }, glow = false },
		Uncommon = { id = "Uncommon", rank = 2, color = { 90, 225, 110 }, glow = false },
		Rare = { id = "Rare", rank = 3, color = { 70, 160, 255 }, glow = true },
		Epic = { id = "Epic", rank = 4, color = { 185, 90, 255 }, glow = true },
		Legendary = { id = "Legendary", rank = 5, color = { 255, 190, 40 }, glow = true },
		Mythic = { id = "Mythic", rank = 6, color = { 255, 70, 140 }, glow = true },
		Secret = { id = "Secret", rank = 7, color = { 235, 235, 240 }, glow = true },
		Cosmic = { id = "Cosmic", rank = 8, color = { 80, 230, 255 }, glow = true },
		Divine = { id = "Divine", rank = 9, color = { 255, 250, 200 }, glow = true },
	} :: { [string]: Tier },
}

return Rarity
