--!strict
-- CELLMATES: critters that follow you and help. Every one has a known price (no random crates:
-- Noodles can be bought with Robux, so nothing random is ever sold). The price is `blocks` of the
-- rubble of the zone you must have reached (`zone`). A pet levels up as you break blocks with it
-- equipped; its perk grows with the level: base + perLevel * (level - 1).
--
-- perks: value = +share Noodles from rubble · power = +share punch power · finds = +share find
-- chance · vacuum = auto-vacuum, +share vacuum range · dig = punches a block next to yours every
-- DigInterval s for (perk x your punch power) · gold = +share gold / jackpot payout

export type Pet = {
	id: string,
	name: string,
	emoji: string,
	desc: string,
	perk: string,
	base: number,
	perLevel: number,
	zone: number,
	blocks: number,
	exclusive: boolean?, -- PRISON PASS reward: never sold
}

local Pets = {
	MaxLevel = 10,
	-- XP (blocks broken while equipped) to go from level L to L + 1: XpBase * L ^ XpPower
	XpBase = 80,
	XpPower = 1.7,
	-- slots: 1, +1 after your first escape, +1 after your third
	SlotRebirths = { 0, 1, 3 },
	DigInterval = 2.5,
	DigActive = 6, -- the dig pet only helps while you punched in the last few seconds
	List = {
		{
			id = "Rat",
			name = "Sewer Rat",
			emoji = "🐀",
			desc = "Sniffs out the good rubble.",
			perk = "value",
			base = 0.06,
			perLevel = 0.01,
			zone = 1,
			blocks = 250,
		},
		{
			id = "Roach",
			name = "Roach Swarm",
			emoji = "🪳",
			desc = "Drags every pebble to you.",
			perk = "vacuum",
			base = 0.05,
			perLevel = 0.05,
			zone = 2,
			blocks = 300,
		},
		{
			id = "Cat",
			name = "Alley Cat",
			emoji = "🐈",
			desc = "Claws the wall with you.",
			perk = "power",
			base = 0.06,
			perLevel = 0.01,
			zone = 3,
			blocks = 500,
		},
		{
			id = "Pigeon",
			name = "Carrier Pigeon",
			emoji = "🐦",
			desc = "Spots shiny things in the rock.",
			perk = "finds",
			base = 0.1,
			perLevel = 0.02,
			zone = 4,
			blocks = 600,
		},
		{
			id = "Badger",
			name = "Tunnel Badger",
			emoji = "🦡",
			desc = "Digs right next to you.",
			perk = "dig",
			base = 0.6,
			perLevel = 0.08,
			zone = 5,
			blocks = 700,
		},
		{
			id = "Parrot",
			name = "Pirate Parrot",
			emoji = "🦜",
			desc = "Loves gold. Squawks for more.",
			perk = "gold",
			base = 0.25,
			perLevel = 0.05,
			zone = 6,
			blocks = 800,
		},
		{
			id = "Bulldog",
			name = "Warden's Bulldog",
			emoji = "🐶",
			desc = "Stole it from the warden. Bites rock.",
			perk = "power",
			base = 0.12,
			perLevel = 0.015,
			zone = 7,
			blocks = 900,
		},
		{
			id = "GoldRat",
			name = "Golden Rat",
			emoji = "🐀",
			desc = "A legend of the sewers.",
			perk = "value",
			base = 0.15,
			perLevel = 0.02,
			zone = 8,
			blocks = 1000,
		},
		{
			id = "Jailbird",
			name = "Jailbird",
			emoji = "🐦",
			desc = "Prison Pass exclusive. Did time, knows the good spots.",
			perk = "value",
			base = 0.12,
			perLevel = 0.02,
			zone = 1,
			blocks = 0,
			exclusive = true,
		},
	} :: { Pet },
}

return Pets
