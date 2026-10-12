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
		color = { 150, 110, 80 },
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
		id = "Influencer",
		name = "Influencer",
		emoji = "🤳",
		color = { 255, 150, 200 },
		trim = { 200, 70, 150 },
		baseIncome = 35,
		guards = 1,
		guardSpeed = 22,
		aggro = 50,
		leash = 120,
		items = {
			item("RingLight", "Ring Light", "💡", "orb", { 255, 255, 230 }),
			item("Sneakers", "Designer Sneakers", "👟", "box", { 255, 255, 255 }),
			item("ViralPhone", "Viral Phone", "📱", "frame", { 40, 40, 50 }),
			item("SelfieStick", "Diamond Selfie Stick", "🤳", "bar", { 150, 230, 255 }),
			item("PlayButton", "Platinum Play Button", "▶️", "frame", { 220, 225, 235 }),
			item("GoldMic", "Golden Microphone", "🎤", "tall", { 255, 200, 40 }),
		},
	},
	{
		id = "Pirate",
		name = "Pirate Captain",
		emoji = "🏴‍☠️",
		color = { 110, 75, 45 },
		trim = { 30, 30, 35 },
		baseIncome = 245,
		guards = 2,
		guardSpeed = 34,
		aggro = 55,
		leash = 130,
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
		color = { 225, 215, 190 },
		trim = { 120, 110, 90 },
		baseIncome = 1700,
		guards = 2,
		guardSpeed = 48,
		aggro = 60,
		leash = 140,
		items = {
			item("Vase", "Ancient Vase", "🏺", "tall", { 200, 120, 70 }),
			item("Fossil", "Dino Fossil", "🦴", "bar", { 235, 225, 200 }),
			item("Painting", "Mona Llama Painting", "🖼️", "frame", { 160, 120, 60 }),
			item("PharaohMask", "Pharaoh Mask", "🎭", "gem", { 255, 190, 40 }),
			item("CrystalSkull", "Crystal Skull", "💀", "orb", { 180, 240, 255 }),
			item("Meteorite", "Living Meteorite", "☄️", "egg", { 255, 110, 40 }),
		},
	},
	{
		id = "GoldTycoon",
		name = "Gold Tycoon",
		emoji = "💰",
		color = { 255, 210, 70 },
		trim = { 160, 110, 20 },
		baseIncome = 12000,
		guards = 2,
		guardSpeed = 64,
		aggro = 65,
		leash = 150,
		items = {
			item("CoinStack", "Gold Coin Stack", "🪙", "tall", { 255, 200, 40 }),
			item("GoldBar", "Gold Bar", "🧈", "bar", { 255, 205, 50 }),
			item("GoldToilet", "Golden Toilet", "🚽", "box", { 255, 210, 60 }),
			item("GoldDuck", "Gold Rubber Duck", "🦆", "egg", { 255, 215, 0 }),
			item("GoldenGoose", "Golden Goose", "🪿", "egg", { 255, 230, 120 }),
			item("MidasHand", "Midas Hand", "✋", "gem", { 255, 180, 0 }),
		},
	},
	{
		id = "Yacht",
		name = "Yacht Owner",
		emoji = "🛥️",
		color = { 240, 245, 255 },
		trim = { 30, 60, 140 },
		baseIncome = 84000,
		guards = 3,
		guardSpeed = 82,
		aggro = 70,
		leash = 160,
		items = {
			item("CaptainHat", "Captain's Hat", "🧢", "box", { 255, 255, 255 }),
			item("Champagne", "Champagne Tower", "🍾", "tall", { 240, 230, 160 }),
			item("JetSki", "Jet Ski", "🚤", "box", { 40, 120, 220 }),
			item("Anchor", "Diamond Anchor", "⚓", "gem", { 150, 230, 255 }),
			item("YachtWheel", "Golden Yacht Wheel", "☸️", "orb", { 255, 200, 40 }),
			item("IslandDeed", "Private Island Deed", "🏝️", "frame", { 80, 220, 160 }),
		},
	},
	{
		id = "TechBillionaire",
		name = "Tech Billionaire",
		emoji = "🚀",
		color = { 60, 65, 80 },
		trim = { 0, 200, 255 },
		baseIncome = 588000,
		guards = 3,
		guardSpeed = 98,
		aggro = 75,
		leash = 170,
		items = {
			item("GamingPC", "Gaming PC", "🖥️", "box", { 40, 40, 50 }),
			item("RobotDog", "Robot Dog", "🤖", "box", { 200, 210, 220 }),
			item("AIBrain", "AI Brain", "🧠", "orb", { 255, 120, 200 }),
			item("QuantumChip", "Quantum Chip", "💾", "gem", { 0, 255, 200 }),
			item("RocketEngine", "Rocket Engine", "🚀", "tall", { 230, 230, 240 }),
			item("MarsTicket", "Ticket to Mars", "🪐", "frame", { 255, 90, 40 }),
		},
	},
	{
		id = "Billionaire",
		name = "THE BILLIONAIRE",
		emoji = "🤑",
		color = { 30, 25, 35 },
		trim = { 255, 200, 40 },
		baseIncome = 4100000,
		guards = 4,
		guardSpeed = 116,
		aggro = 85,
		leash = 180,
		items = {
			item("DiamondTub", "Diamond Bathtub", "🛁", "box", { 180, 240, 255 }),
			item("MoneyGun", "Money Gun", "💸", "bar", { 90, 220, 90 }),
			item("InfinityGem", "Infinity Gem", "💎", "gem", { 160, 80, 255 }),
			item("GoldLambo", "Golden Supercar", "🏎️", "box", { 255, 200, 40 }),
			item("VaultKey", "Master Vault Key", "🗝️", "gem", { 255, 220, 120 }),
			item("BillionEgg", "Billion Dollar Egg", "🥚", "egg", { 255, 230, 60 }),
		},
	},
}

return Vaults
