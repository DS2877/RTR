--!strict
-- Game passes and developer products. Known contents only, no paid randomness.
-- tools/ops/roblox_setup.py creates every entry on Roblox and writes the ids back here.
-- Anything on Roblox that is NOT listed here (the old Rob the Rich products) is set off sale.
-- Keep each entry on the `key = .., id = .., name = .., emoji = .., price = .., desc = ..` form.

export type Product = {
	key: string,
	id: number,
	name: string,
	emoji: string,
	price: number,
	desc: string,
}

local Products = {
	Passes = {
		{
			key = "DoubleNoodles",
			id = 2039846388,
			name = "2x Noodles",
			emoji = "🍜",
			price = 199,
			desc = "Double Noodles from dumping rubble and selling finds. Forever.",
		},
		{
			key = "AutoVacuum",
			id = 2039576400,
			name = "Auto-Vacuum",
			emoji = "🌀",
			price = 149,
			desc = "Your vacuum runs by itself: rubble flies into your backpack while you punch.",
		},
		{
			key = "HugeBackpack",
			id = 2036384610,
			name = "Huge Backpack",
			emoji = "🎒",
			price = 149,
			desc = "Your backpack holds twice as much rubble. Fewer trips to the Yard!",
		},
		{
			key = "DoubleStrength",
			id = 2038250596,
			name = "2x Strength",
			emoji = "💪",
			price = 199,
			desc = "Every gym rep gives double strength. Forever.",
		},
		{
			key = "VIP",
			id = 2038340615,
			name = "VIP Prisoner",
			emoji = "⭐",
			price = 299,
			desc = "+10% Noodles forever, gold fists, a VIP chat tag and the VIP lounge in the Common Room.",
		},
	} :: { Product },
	Items = {
		{
			key = "Dynamite",
			id = 3718744920,
			name = "Dynamite",
			emoji = "🧨",
			price = 49,
			desc = "One stick of dynamite: blows up a huge sphere of blocks in your tunnel.",
		},
		{
			key = "NoodlesSmall",
			id = 3718744921,
			name = "Noodle Crate",
			emoji = "🍜",
			price = 39,
			desc = "A crate of Noodles. The exact amount is shown in the Store before you buy.",
		},
		{
			key = "NoodlesBig",
			id = 3718744924,
			name = "Noodle Truck",
			emoji = "🚚",
			price = 149,
			desc = "A truck full of Noodles (6x a crate). The exact amount is shown in the Store.",
		},
		{
			key = "StarterPack",
			id = 3719132943,
			name = "Starter Pack",
			emoji = "🎁",
			price = 79,
			desc = "Once per prisoner: 3 Dynamite, 30 minutes of NOODLE RUSH (2x Noodles), the Fresh Fish uniform and a Noodle Crate.",
		},
		{
			key = "NoodleRush",
			id = 3719132947,
			name = "Noodle Rush",
			emoji = "⚡",
			price = 49,
			desc = "2x Noodles from rubble for 30 minutes (adds up if you buy more).",
		},
		{
			key = "NoodlesHuge",
			id = 3719132950,
			name = "Noodle Train",
			emoji = "🚂",
			price = 449,
			desc = "A whole train of Noodles (24x a crate). The exact amount is shown in the Store.",
		},
		{
			key = "PrisonPass",
			id = 3719132958,
			name = "Prison Pass Premium",
			emoji = "🎫",
			price = 399,
			desc = "This season's Prison Pass premium track: every premium reward listed in the Pass panel (Riot Gear, Lightning Fists, the Kingpin uniform and more) plus +25% pass XP. Lasts this season.",
		},
		{
			key = "InstantEmpty",
			id = 3718744929,
			name = "Instant Backpack Empty",
			emoji = "💨",
			price = 25,
			desc = "Dump your whole backpack right where you stand, for full Noodles.",
		},
	} :: { Product },

	-- what the developer products give
	DynamiteRadius = 4, -- blocks
	RushSeconds = 30 * 60, -- NOODLE RUSH length (Starter Pack + the Noodle Rush product)
	StarterDynamite = 3,
	-- Noodle packs = this many blocks of rubble from your deepest zone (shown in the Store)
	NoodlesSmallBlocks = 2500,
	NoodlesBigBlocks = 15000,
	NoodlesHugeBlocks = 60000,
}

return Products
