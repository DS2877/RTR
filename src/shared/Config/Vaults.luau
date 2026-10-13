--!strict
-- The zones along Rich Street, ordered by distance from home: farther = richer, faster guard,
-- higher Speed requirement (about x6-10 per zone, like the genre). Every zone has ONE guard that
-- sleeps beside the crates and wakes when someone steals one. The loot is crates
-- ("<zone> Crate"); the appraiser at your base opens them.
-- Each zone has one item per rarity (Common..Mythic). Income = baseIncome * Rarity.mult * mutation.

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
	color: { number }, -- the zone's main color (walls)
	trim: { number }, -- its accent (gate, trim, name banner)
	tint: { number }, -- the light tint while you're in the zone (each zone has its own mood)
	baseIncome: number, -- $/s for a Common item from this zone
	speedRequired: number, -- Speed (treadmill points) to pass the zone's gate
	guard: string, -- "dog" | "butler" | "security" | "robot" | "captain" | "croupier" | "billionaire" | "ai"
	guardName: string,
	guardSpeed: number,
	guardScale: number, -- guards get bigger (and scarier) farther out
	items: { Item }, -- index = rarity order (1 Common .. 6 Mythic)
}

local function item(id: string, name: string, emoji: string, shape: string, color: { number }): Item
	return { id = id, name = name, emoji = emoji, shape = shape, color = color }
end

local Vaults: { Vault } = {
	{
		id = "Suburbs",
		name = "Suburbs",
		emoji = "🏡",
		color = { 120, 190, 90 }, -- green lawns, villas
		trim = { 255, 255, 255 },
		tint = { 255, 255, 245 },
		baseIncome = 5,
		speedRequired = 0,
		guard = "dog",
		guardName = "Guard Dog",
		guardSpeed = 12,
		guardScale = 1,
		items = {
			item("Wrench", "Rusty Wrench", "🔧", "bar", { 140, 90, 60 }),
			item("Radio", "Old Radio", "📻", "box", { 120, 80, 50 }),
			item("GardenGnome", "Garden Gnome", "🧙", "tall", { 220, 60, 60 }),
			item("LawnMower", "Golden Lawn Mower", "🚜", "box", { 255, 200, 60 }),
			item("CarKeys", "Vintage Car Keys", "🔑", "gem", { 230, 190, 60 }),
			item("GoldWatch", "Gold Watch", "⌚", "orb", { 255, 200, 40 }),
		},
	},
	{
		id = "PoolVillas",
		name = "Pool Villas",
		emoji = "🏊",
		color = { 240, 248, 250 }, -- white villas, turquoise water
		trim = { 40, 200, 210 },
		tint = { 225, 250, 255 },
		baseIncome = 35,
		speedRequired = 35,
		guard = "butler",
		guardName = "The Butler",
		guardSpeed = 22,
		guardScale = 1.1,
		items = {
			item("BeachBall", "Beach Ball", "🏐", "orb", { 255, 120, 120 }),
			item("Flamingo", "Flamingo Float", "🦩", "egg", { 255, 130, 190 }),
			item("SilverTray", "Silver Tray", "🍽️", "frame", { 210, 210, 220 }),
			item("Champagne", "Champagne Tower", "🍾", "tall", { 240, 230, 160 }),
			item("PoolCrown", "Diamond Pool Float", "💎", "gem", { 120, 230, 255 }),
			item("GoldDuck", "Gold Rubber Duck", "🦆", "egg", { 255, 215, 0 }),
		},
	},
	{
		id = "Mansion",
		name = "Mansion",
		emoji = "🏰",
		color = { 150, 96, 56 }, -- warm wood, gold
		trim = { 255, 196, 60 },
		tint = { 255, 236, 205 },
		baseIncome = 245,
		speedRequired = 250,
		guard = "security",
		guardName = "Security",
		guardSpeed = 34,
		guardScale = 1.15,
		items = {
			item("Candlestick", "Silver Candlestick", "🕯️", "tall", { 220, 220, 230 }),
			item("Vase", "Antique Vase", "🏺", "tall", { 200, 120, 70 }),
			item("Painting", "Mona Llama Painting", "🖼️", "frame", { 160, 120, 60 }),
			item("Chandelier", "Crystal Chandelier", "💡", "orb", { 200, 240, 255 }),
			item("Statue", "Marble Bust", "🗿", "tall", { 235, 232, 222 }),
			item("RoyalCrown", "Royal Crown", "👑", "gem", { 255, 200, 40 }),
		},
	},
	{
		id = "BankVault",
		name = "Bank Vault",
		emoji = "🏦",
		color = { 150, 156, 166 }, -- steel, green lasers
		trim = { 70, 255, 120 },
		tint = { 225, 255, 230 },
		baseIncome = 1700,
		speedRequired = 1500,
		guard = "robot",
		guardName = "Robo-Guard",
		guardSpeed = 48,
		guardScale = 1.25,
		items = {
			item("CashStack", "Cash Stack", "💵", "box", { 90, 200, 90 }),
			item("CoinBag", "Coin Bag", "💰", "orb", { 200, 160, 80 }),
			item("GoldBar", "Gold Bar", "🧈", "bar", { 255, 205, 50 }),
			item("DepositBox", "Deposit Box", "🗃️", "box", { 120, 130, 140 }),
			item("DiamondCase", "Diamond Briefcase", "💼", "box", { 150, 230, 255 }),
			item("VaultKey", "Master Vault Key", "🗝️", "gem", { 255, 220, 120 }),
		},
	},
	{
		id = "YachtHarbor",
		name = "Yacht Harbor",
		emoji = "🛥️",
		color = { 30, 50, 110 }, -- navy blue, sunset
		trim = { 255, 150, 70 },
		tint = { 255, 215, 185 },
		baseIncome = 12000,
		speedRequired = 12000,
		guard = "captain",
		guardName = "The Captain",
		guardSpeed = 64,
		guardScale = 1.35,
		items = {
			item("CaptainHat", "Captain's Hat", "🧢", "box", { 255, 255, 255 }),
			item("LifeRing", "Life Ring", "🛟", "orb", { 255, 80, 60 }),
			item("Compass", "Silver Compass", "🧭", "orb", { 200, 200, 210 }),
			item("ShipWheel", "Golden Ship Wheel", "☸️", "orb", { 255, 200, 40 }),
			item("JetSki", "Jet Ski", "🚤", "box", { 40, 120, 220 }),
			item("BlackPearl", "Black Pearl", "⚫", "orb", { 40, 30, 60 }),
		},
	},
	{
		id = "Casino",
		name = "Casino",
		emoji = "🎰",
		color = { 30, 20, 26 }, -- black + neon red
		trim = { 255, 40, 70 },
		tint = { 255, 205, 215 },
		baseIncome = 84000,
		speedRequired = 120000,
		guard = "croupier",
		guardName = "Croupier Boss",
		guardSpeed = 82,
		guardScale = 1.45,
		items = {
			item("PokerChips", "Poker Chips", "🪙", "tall", { 220, 40, 50 }),
			item("GoldenDice", "Golden Dice", "🎲", "box", { 255, 210, 60 }),
			item("SlotMachine", "Slot Machine", "🎰", "box", { 200, 30, 40 }),
			item("Roulette", "Roulette Wheel", "🎡", "orb", { 30, 140, 60 }),
			item("RoyalFlush", "Royal Flush", "🃏", "frame", { 255, 255, 255 }),
			item("JackpotEgg", "Jackpot Egg", "🥚", "egg", { 255, 60, 120 }),
		},
	},
	{
		id = "PrivateIsland",
		name = "Private Island",
		emoji = "🏝️",
		color = { 240, 214, 150 }, -- tropical sand, gold
		trim = { 255, 200, 40 },
		tint = { 255, 245, 210 },
		baseIncome = 588000,
		speedRequired = 1e6,
		guard = "billionaire",
		guardName = "The Billionaire",
		guardSpeed = 98,
		guardScale = 1.55,
		items = {
			item("Coconut", "Golden Coconut", "🥥", "orb", { 160, 110, 60 }),
			item("TikiMask", "Tiki Mask", "🗿", "tall", { 170, 100, 50 }),
			item("GoldStatue", "Gold Statue", "🏆", "tall", { 255, 200, 40 }),
			item("IslandDeed", "Island Deed", "📜", "frame", { 230, 210, 160 }),
			item("GoldLambo", "Golden Supercar", "🏎️", "box", { 255, 200, 40 }),
			item("BillionEgg", "Billion Dollar Egg", "🥚", "egg", { 255, 230, 60 }),
		},
	},
	{
		id = "SpaceVault",
		name = "Space Vault",
		emoji = "🚀",
		color = { 40, 22, 70 }, -- purple, stars
		trim = { 190, 110, 255 },
		tint = { 225, 210, 255 },
		baseIncome = 4100000,
		speedRequired = 10e6,
		guard = "ai",
		guardName = "A.I. Sentinel",
		guardSpeed = 116,
		guardScale = 1.7,
		items = {
			item("MoonRock", "Moon Rock", "🌑", "orb", { 170, 170, 180 }),
			item("AstroHelmet", "Astro Helmet", "👨‍🚀", "orb", { 240, 240, 250 }),
			item("Rocket", "Mini Rocket", "🚀", "tall", { 230, 230, 240 }),
			item("QuantumChip", "Quantum Chip", "💾", "gem", { 0, 255, 200 }),
			item("Meteorite", "Living Meteorite", "☄️", "egg", { 255, 110, 40 }),
			item("GalaxyGem", "Galaxy Gem", "🌌", "gem", { 170, 80, 255 }),
		},
	},
}

return Vaults
