--!strict
-- The rich people along Rich Street, ordered by distance from home (farther = richer + faster).
-- Their loot is crates ("<name> Crate"); the appraiser at your base opens them.
-- Each vault has one item per rarity (Common..Mythic). Income = BaseIncome * Rarity.mult * mutation.

export type Item = {
	id: string,
	name: string,
	emoji: string,
	shape: string, -- "box" | "bar" | "gem" | "orb" | "frame" | "egg" | "tall" (built from parts)
	color: { number },
}

export type Vault = {
	id: string,
	name: string,
	emoji: string,
	color: { number }, -- walls
	trim: { number }, -- roof, pillars, sign
	baseIncome: number, -- $/s for a Common item from this vault
	guards: number,
	guardSpeed: number,
	aggro: number, -- studs from the vault center where guards notice a carrier
	leash: number, -- guards give up beyond this distance from home
	items: { Item }, -- index = rarity order (1 Common .. 6 Mythic)
}

local function item(id: string, name: string, emoji: string, shape: string, color: { number }): Item
	return { id = id, name = name, emoji = emoji, shape = shape, color = color }
end

local Vaults: { Vault } = {
	{
		id = "Grandpa",
		name = "Grandpa",
		emoji = "👴",
		color = { 120, 190, 90 }, -- the village: green brick houses on a grass street
		trim = { 90, 60, 40 },
		baseIncome = 5,
		guards = 1,
		guardSpeed = 12,
		aggro = 45,
		leash = 110,
		items = {
			item("Wrench", "Rusty Wrench", "🔧", "bar", { 140, 90, 60 }),
			item("Radio", "Old Radio", "📻", "box", { 120, 80, 50 }),
			item("Clock", "Antique Clock", "🕰️", "tall", { 170, 120, 70 }),
			item("Dentures", "Golden Dentures", "🦷", "orb", { 255, 220, 120 }),
			item("CarKeys", "Vintage Car Keys", "🔑", "gem", { 230, 190, 60 }),
			item("GoldWatch", "Grandpa's Gold Watch", "⌚", "orb", { 255, 200, 40 }),
		},
	},
	{
		id = "Jeweler",
		name = "Jeweler",
		emoji = "💎",
		color = { 150, 152, 160 }, -- the gray street
		trim = { 120, 220, 255 },
		baseIncome = 35,
		guards = 1,
		guardSpeed = 22,
		aggro = 50,
		leash = 120,
		items = {
			item("SilverRing", "Silver Ring", "💍", "orb", { 210, 210, 220 }),
			item("PearlEarrings", "Pearl Earrings", "🦪", "orb", { 250, 245, 235 }),
			item("RubyBrooch", "Ruby Brooch", "♦️", "gem", { 220, 30, 60 }),
			item("EmeraldNecklace", "Emerald Necklace", "📿", "gem", { 40, 200, 110 }),
			item("SapphireCrown", "Sapphire Tiara", "👑", "tall", { 60, 110, 255 }),
			item("HopeDiamond", "Giant Blue Diamond", "💎", "gem", { 120, 220, 255 }),
		},
	},
	{
		id = "Archeologist",
		name = "Archeologist",
		emoji = "🏺",
		color = { 225, 196, 120 }, -- sandstone
		trim = { 140, 100, 50 },
		baseIncome = 245,
		guards = 2,
		guardSpeed = 34,
		aggro = 55,
		leash = 130,
		items = {
			item("ClayPot", "Clay Pot", "🏺", "tall", { 200, 120, 70 }),
			item("Trowel", "Old Trowel", "🪏", "bar", { 160, 160, 170 }),
			item("Fossil", "Dino Fossil", "🦴", "bar", { 235, 225, 200 }),
			item("ScarabAmulet", "Scarab Amulet", "🪲", "gem", { 40, 180, 160 }),
			item("PharaohMask", "Pharaoh Mask", "🎭", "gem", { 255, 190, 40 }),
			item("TrexEgg", "T-Rex Egg", "🥚", "egg", { 200, 140, 70 }),
		},
	},
	{
		id = "Mafia",
		name = "Mafia Boss",
		emoji = "🕴️",
		color = { 52, 62, 76 }, -- dark warehouse street
		trim = { 230, 70, 80 },
		baseIncome = 1700,
		guards = 2,
		guardSpeed = 48,
		aggro = 60,
		leash = 140,
		items = {
			item("CashStack", "Cash Stack", "💵", "box", { 90, 200, 90 }),
			item("Fedora", "Boss Fedora", "🎩", "tall", { 30, 30, 35 }),
			item("Briefcase", "Money Briefcase", "💼", "box", { 110, 70, 40 }),
			item("GoldenGun", "Golden Tommy Gun", "🔫", "bar", { 255, 200, 40 }),
			item("BossRing", "Boss Signet Ring", "💍", "orb", { 255, 210, 60 }),
			item("VaultSafe", "Diamond Safe", "🔐", "box", { 150, 230, 255 }),
		},
	},
	{
		id = "Celebrity",
		name = "Celebrity",
		emoji = "🌟",
		color = { 240, 200, 80 }, -- yellow checker walls, pink carpets
		trim = { 255, 110, 190 },
		baseIncome = 12000,
		guards = 2,
		guardSpeed = 64,
		aggro = 65,
		leash = 150,
		items = {
			item("Sunglasses", "Star Sunglasses", "🕶️", "box", { 30, 30, 35 }),
			item("RingLight", "Ring Light", "💡", "orb", { 255, 255, 230 }),
			item("ViralPhone", "Viral Phone", "📱", "frame", { 40, 40, 50 }),
			item("GoldMic", "Golden Microphone", "🎤", "tall", { 255, 200, 40 }),
			item("PlayButton", "Diamond Play Button", "▶️", "frame", { 180, 240, 255 }),
			item("StarTrophy", "Walk of Fame Star", "⭐", "gem", { 255, 120, 200 }),
		},
	},
	{
		id = "Pirate",
		name = "Pirate Captain",
		emoji = "☠️",
		color = { 236, 214, 150 }, -- the beach
		trim = { 30, 30, 35 },
		baseIncome = 84000,
		guards = 3,
		guardSpeed = 82,
		aggro = 70,
		leash = 160,
		items = {
			item("RumBarrel", "Rum Barrel", "🛢️", "tall", { 120, 70, 40 }),
			item("Compass", "Silver Compass", "🧭", "orb", { 200, 200, 210 }),
			item("TreasureMap", "Treasure Map", "🗺️", "frame", { 230, 200, 140 }),
			item("Pearls", "Pearl Necklace", "📿", "orb", { 250, 245, 235 }),
			item("Cutlass", "Ruby Cutlass", "🗡️", "bar", { 220, 30, 60 }),
			item("KrakenEgg", "Kraken Egg", "🥚", "egg", { 60, 200, 170 }),
		},
	},
	{
		id = "Museum",
		name = "Museum Owner",
		emoji = "🏛️",
		color = { 110, 120, 60 }, -- green gallery walls, beige checker floor
		trim = { 230, 228, 180 },
		baseIncome = 588000,
		guards = 3,
		guardSpeed = 98,
		aggro = 75,
		leash = 170,
		items = {
			item("Vase", "Ancient Vase", "🏺", "tall", { 200, 120, 70 }),
			item("Painting", "Mona Llama Painting", "🖼️", "frame", { 160, 120, 60 }),
			item("Statue", "Marble Bust", "🗿", "tall", { 235, 232, 222 }),
			item("Sword", "Sword of Kings", "🗡️", "bar", { 220, 220, 230 }),
			item("CrystalSkull", "Crystal Skull", "💀", "orb", { 180, 240, 255 }),
			item("Meteorite", "Living Meteorite", "☄️", "egg", { 255, 110, 40 }),
		},
	},
	{
		id = "GoldTycoon",
		name = "Gold Tycoon",
		emoji = "🏆",
		color = { 30, 70, 80 }, -- dark teal walls with gold gears
		trim = { 255, 200, 40 },
		baseIncome = 4100000,
		guards = 4,
		guardSpeed = 116,
		aggro = 85,
		leash = 180,
		items = {
			item("CoinStack", "Gold Coin Stack", "🪙", "tall", { 255, 200, 40 }),
			item("GoldBar", "Gold Bar", "🧈", "bar", { 255, 205, 50 }),
			item("GoldToilet", "Golden Toilet", "🚽", "box", { 255, 210, 60 }),
			item("GoldenGoose", "Golden Goose", "🪿", "egg", { 255, 230, 120 }),
			item("MidasHand", "Midas Hand", "✋", "gem", { 255, 180, 0 }),
			item("BillionEgg", "Billion Dollar Egg", "🥚", "egg", { 255, 230, 60 }),
		},
	},
}

return Vaults
