--!strict
-- Laundry (cosmetics), Black Market (rotating daily stock), Mess Hall (buffs for the coming night)
-- and tunnel decorations. Prices in Noodles. `blocks` prices = that many blocks of rubble from
-- your deepest zone (so they stay fair at every depth); the exact price is shown before buying.

export type Item = {
	id: string,
	name: string,
	emoji: string,
	desc: string,
	cost: number?, -- fixed price
	blocks: number?, -- or: price in blocks of your zone's rubble
	color: { number }?,
	buff: string?, -- buff id it gives
	seconds: number?, -- buff length (nil = until the next morning)
}

local Extras = {
	-- LAUNDRY: prison uniforms (replace your shirt + pants) and fist trails
	Uniforms = {
		{
			id = "Orange",
			name = "Classic Orange",
			emoji = "🟧",
			desc = "The classic.",
			cost = 0,
			color = { 255, 120, 30 },
		},
		{
			id = "Stripes",
			name = "Old Stripes",
			emoji = "🦓",
			desc = "Black and white, old school.",
			cost = 3000,
			color = { 235, 235, 235 },
		},
		{
			id = "Blue",
			name = "Denim Blue",
			emoji = "🟦",
			desc = "Work-detail blue.",
			cost = 15000,
			color = { 60, 110, 200 },
		},
		{
			id = "Pink",
			name = "Bubblegum",
			emoji = "🩷",
			desc = "Nobody messes with pink.",
			cost = 60000,
			color = { 255, 120, 190 },
		},
		{
			id = "Green",
			name = "Sewer Green",
			emoji = "🟩",
			desc = "Blends in down there.",
			cost = 250000,
			color = { 80, 170, 80 },
		},
		{
			id = "Black",
			name = "Midnight",
			emoji = "⬛",
			desc = "For night diggers.",
			cost = 1000000,
			color = { 30, 30, 36 },
		},
		{
			id = "Gold",
			name = "Golden Uniform",
			emoji = "🟨",
			desc = "Shine bright.",
			cost = 25000000,
			color = { 255, 200, 40 },
		},
	} :: { Item },
	Fists = {
		{
			id = "Fire",
			name = "Fire Fists",
			emoji = "🔥",
			desc = "Flaming trails on your fists.",
			cost = 20000,
			color = { 255, 120, 30 },
		},
		{
			id = "Ice",
			name = "Ice Fists",
			emoji = "❄️",
			desc = "Frosty trails on your fists.",
			cost = 80000,
			color = { 120, 220, 255 },
		},
		{
			id = "Toxic",
			name = "Toxic Fists",
			emoji = "☢️",
			desc = "Glowing green trails.",
			cost = 400000,
			color = { 120, 255, 80 },
		},
		{
			id = "Royal",
			name = "Royal Fists",
			emoji = "👑",
			desc = "Purple and gold.",
			cost = 5000000,
			color = { 190, 90, 255 },
		},
	} :: { Item },

	-- MESS HALL: buffs for the coming night (they end the next morning)
	Meals = {
		{
			id = "Stew",
			name = "Hearty Stew",
			emoji = "🍲",
			desc = "+25% punch power until morning.",
			blocks = 120,
			buff = "Stew",
		},
		{
			id = "Bowl",
			name = "Lucky Noodle Bowl",
			emoji = "🍜",
			desc = "+30% finds until morning.",
			blocks = 160,
			buff = "Bowl",
		},
		{
			id = "Coffee",
			name = "Prison Coffee",
			emoji = "☕",
			desc = "Punch 15% faster until morning.",
			blocks = 140,
			buff = "Coffee",
		},
	} :: { Item },

	-- BLACK MARKET: 3 of these each day (rotates at 00:00 UTC)
	Market = {
		{ id = "Dynamite", name = "Dynamite", emoji = "🧨", desc = "One stick. Big boom.", blocks = 400 },
		{
			id = "Charm",
			name = "Lucky Charm",
			emoji = "🍀",
			desc = "+50% finds for 10 minutes.",
			blocks = 250,
			buff = "Charm",
			seconds = 600,
		},
		{
			id = "Shake",
			name = "Protein Shake",
			emoji = "🥤",
			desc = "+25% punch power for 10 minutes.",
			blocks = 200,
			buff = "Shake",
			seconds = 600,
		},
		{
			id = "Magnet",
			name = "Rubble Magnet",
			emoji = "🧲",
			desc = "Auto-vacuum for 10 minutes.",
			blocks = 150,
			buff = "Magnet",
			seconds = 600,
		},
		{
			id = "Gloves",
			name = "Iron Gloves",
			emoji = "🧤",
			desc = "+50% punch power for 5 minutes.",
			blocks = 300,
			buff = "Gloves",
			seconds = 300,
		},
	} :: { Item },
	MarketSlots = 3,

	-- what each buff does
	Buffs = {
		Stew = { power = 0.25 },
		Shake = { power = 0.25 },
		Gloves = { power = 0.5 },
		Bowl = { finds = 0.3 },
		Charm = { finds = 0.5 },
		Coffee = { speed = 0.15 },
		Magnet = { vacuum = true },
	} :: { [string]: { power: number?, finds: number?, speed: number?, vacuum: boolean? } },

	-- DECOR: show off your tunnel (bought at the Workshop, placed with the 🪔 button in your tunnel)
	Decor = {
		{ id = "Lamp", name = "Tunnel Lamp", emoji = "💡", desc = "A warm light.", cost = 500 },
		{ id = "Rails", name = "Minecart Rails", emoji = "🛤️", desc = "A piece of track.", cost = 800 },
		{ id = "Cart", name = "Minecart", emoji = "🛒", desc = "Full of rubble.", cost = 6000 },
		{ id = "Sign", name = "Wooden Sign", emoji = "🪧", desc = "KEEP OUT!", cost = 1500 },
		{ id = "Barrel", name = "Barrel", emoji = "🛢️", desc = "Just a barrel.", cost = 2500 },
		{ id = "Flag", name = "Freedom Flag", emoji = "🚩", desc = "Plant it deep.", cost = 20000 },
		{
			id = "Trophy",
			name = "Trophy Stand",
			emoji = "🏆",
			desc = "Shows your best find ever.",
			cost = 100000,
		},
	} :: { Item },
	MaxPlaced = 40,
	MaxLamps = 10,
}

return Extras
