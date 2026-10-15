--!strict
-- Finds hidden in ore blocks, per zone. `weight` = relative chance inside that zone's ore blocks.
-- `value` = Noodles The Fence pays. Kid-friendly items only (no tobacco, drugs or weapons).

export type Find = {
	id: string,
	name: string,
	emoji: string,
	zone: number,
	rarity: string,
	weight: number,
	value: number,
}

local List: { Find } = {
	-- 1 Plaster
	{
		id = "OldCoin",
		name = "Old Coin",
		emoji = "🪙",
		zone = 1,
		rarity = "Common",
		weight = 40,
		value = 15,
	},
	{
		id = "Marble",
		name = "Lost Marble",
		emoji = "🔮",
		zone = 1,
		rarity = "Common",
		weight = 30,
		value = 20,
	},
	{
		id = "RustyKey",
		name = "Rusty Key",
		emoji = "🗝️",
		zone = 1,
		rarity = "Uncommon",
		weight = 22,
		value = 60,
	},
	{
		id = "SecretNote",
		name = "Secret Note",
		emoji = "📜",
		zone = 1,
		rarity = "Rare",
		weight = 8,
		value = 250,
	},
	-- 2 Brick
	{
		id = "BrassButton",
		name = "Brass Button",
		emoji = "🔘",
		zone = 2,
		rarity = "Common",
		weight = 40,
		value = 60,
	},
	{
		id = "ToySoldier",
		name = "Toy Soldier",
		emoji = "💂",
		zone = 2,
		rarity = "Common",
		weight = 30,
		value = 80,
	},
	{
		id = "Harmonica",
		name = "Old Harmonica",
		emoji = "🎵",
		zone = 2,
		rarity = "Uncommon",
		weight = 22,
		value = 250,
	},
	{
		id = "SilverSpoon",
		name = "Silver Spoon",
		emoji = "🥄",
		zone = 2,
		rarity = "Rare",
		weight = 8,
		value = 1000,
	},
	-- 3 Concrete
	{
		id = "Wristwatch",
		name = "Wristwatch",
		emoji = "⌚",
		zone = 3,
		rarity = "Common",
		weight = 40,
		value = 250,
	},
	{
		id = "LuckyDice",
		name = "Lucky Dice",
		emoji = "🎲",
		zone = 3,
		rarity = "Common",
		weight = 30,
		value = 320,
	},
	{
		id = "GuardBadge",
		name = "Guard's Badge",
		emoji = "📛",
		zone = 3,
		rarity = "Uncommon",
		weight = 22,
		value = 1000,
	},
	{
		id = "GoldRing",
		name = "Gold Ring",
		emoji = "💍",
		zone = 3,
		rarity = "Rare",
		weight = 8,
		value = 4000,
	},
	-- 4 Reinforced Concrete
	{
		id = "HardHat",
		name = "Hard Hat",
		emoji = "⛑️",
		zone = 4,
		rarity = "Common",
		weight = 38,
		value = 600,
	},
	{
		id = "Lunchbox",
		name = "Old Lunchbox",
		emoji = "🍱",
		zone = 4,
		rarity = "Common",
		weight = 30,
		value = 750,
	},
	{
		id = "BrassCompass",
		name = "Brass Compass",
		emoji = "🧭",
		zone = 4,
		rarity = "Uncommon",
		weight = 20,
		value = 2500,
	},
	{
		id = "PocketWatch",
		name = "Pocket Watch",
		emoji = "⏱️",
		zone = 4,
		rarity = "Rare",
		weight = 9,
		value = 10000,
	},
	{
		id = "GoldenWrench",
		name = "Golden Wrench",
		emoji = "🔧",
		zone = 4,
		rarity = "Epic",
		weight = 3,
		value = 40000,
	},
	-- 5 Clay & Pipes
	{
		id = "RubberDuck",
		name = "Rubber Duck",
		emoji = "🦆",
		zone = 5,
		rarity = "Common",
		weight = 38,
		value = 2400,
	},
	{
		id = "ClayPot",
		name = "Clay Pot",
		emoji = "🏺",
		zone = 5,
		rarity = "Common",
		weight = 30,
		value = 3000,
	},
	{
		id = "BottleNote",
		name = "Message in a Bottle",
		emoji = "🍾",
		zone = 5,
		rarity = "Uncommon",
		weight = 20,
		value = 10000,
	},
	{
		id = "PirateCoin",
		name = "Pirate Coin",
		emoji = "🏴‍☠️",
		zone = 5,
		rarity = "Rare",
		weight = 9,
		value = 40000,
	},
	{
		id = "FossilFish",
		name = "Fossil Fish",
		emoji = "🐟",
		zone = 5,
		rarity = "Epic",
		weight = 3,
		value = 160000,
	},
	-- 6 Sewer
	{
		id = "LostSneaker",
		name = "Lost Sneaker",
		emoji = "👟",
		zone = 6,
		rarity = "Common",
		weight = 38,
		value = 9000,
	},
	{
		id = "ToyRobot",
		name = "Toy Robot",
		emoji = "🤖",
		zone = 6,
		rarity = "Common",
		weight = 30,
		value = 11400,
	},
	{
		id = "DiamondRing",
		name = "Diamond Ring",
		emoji = "💎",
		zone = 6,
		rarity = "Uncommon",
		weight = 20,
		value = 36000,
	},
	{
		id = "TreasureChest",
		name = "Treasure Chest",
		emoji = "🧰",
		zone = 6,
		rarity = "Rare",
		weight = 9,
		value = 150000,
	},
	{
		id = "GoldenCrown",
		name = "Golden Crown",
		emoji = "👑",
		zone = 6,
		rarity = "Epic",
		weight = 3,
		value = 600000,
	},
}

local ById: { [string]: Find } = {}
local ByZone: { [number]: { Find } } = {}
for _, f in List do
	ById[f.id] = f
	local z = ByZone[f.zone]
	if not z then
		z = {}
		ByZone[f.zone] = z
	end
	table.insert(z, f)
end

return {
	List = List,
	ById = ById,
	ByZone = ByZone,
}
