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
