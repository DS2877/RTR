--!strict
-- Every upgrade track. Level 1 is what a new prisoner starts with (cost 0).
-- Workshop: Tools, Brushes. Commissary: Backpack, FindSlots, Vacuum.
-- `Open` = highest level that can be bought right now (raised with each milestone).

export type Level = {
	name: string,
	emoji: string,
	cost: number,
	value: number, -- tool: punch multiplier, backpack: rubble capacity, slots: find slots, vacuum: studs
}

export type Brush = {
	name: string,
	emoji: string,
	cost: number,
	-- cells in the face plane (u = across, v = up) relative to the aimed block
	cells: { { number } },
}

local function square(r: number): { { number } }
	local out = {}
	for v = -r, r do
		for u = -r, r do
			table.insert(out, { u, v })
		end
	end
	return out
end

local cross = { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local square3cross = square(1)
for _, c in { { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 } } do
	table.insert(square3cross, c)
end

local Upgrades = {
	Tools = {
		{ name = "Fists", emoji = "👊", cost = 0, value = 1 },
		{ name = "Spoon", emoji = "🥄", cost = 15, value = 2 },
		{ name = "Shovel", emoji = "🪏", cost = 300, value = 4 },
		{ name = "Pickaxe", emoji = "⛏️", cost = 3000, value = 9 },
		{ name = "Jackhammer", emoji = "🔨", cost = 45000, value = 25 },
		{ name = "Drill", emoji = "🪛", cost = 700000, value = 70 },
		{ name = "Laser", emoji = "🔦", cost = 12000000, value = 200 },
	} :: { Level },

	Brushes = {
		{ name = "Single", emoji = "▪️", cost = 0, cells = { { 0, 0 } } },
		{ name = "Cross", emoji = "➕", cost = 150, cells = cross },
		{ name = "3x3", emoji = "🔳", cost = 2500, cells = square(1) },
		{ name = "Big Cross", emoji = "✳️", cost = 40000, cells = square3cross },
		{ name = "5x5", emoji = "⬛", cost = 600000, cells = square(2) },
	} :: { Brush },

	Backpack = {
		{ name = "Pockets", emoji = "👖", cost = 0, value = 20 },
		{ name = "Sock", emoji = "🧦", cost = 60, value = 60 },
		{ name = "Pillowcase", emoji = "🛏️", cost = 400, value = 130 },
		{ name = "Laundry Bag", emoji = "🧺", cost = 2200, value = 280 },
		{ name = "Duffel Bag", emoji = "👜", cost = 12000, value = 600 },
		{ name = "Mail Cart", emoji = "🛒", cost = 70000, value = 1300 },
		{ name = "Dumpster", emoji = "🗑️", cost = 400000, value = 3000 },
	} :: { Level },

	FindSlots = {
		{ name = "3 Slots", emoji = "🎒", cost = 0, value = 3 },
		{ name = "5 Slots", emoji = "🎒", cost = 200, value = 5 },
		{ name = "8 Slots", emoji = "🎒", cost = 1500, value = 8 },
		{ name = "12 Slots", emoji = "🎒", cost = 12000, value = 12 },
		{ name = "20 Slots", emoji = "🎒", cost = 100000, value = 20 },
	} :: { Level },

	Vacuum = {
		{ name = "Straw", emoji = "🥤", cost = 0, value = 10 },
		{ name = "Hand Vac", emoji = "🌀", cost = 100, value = 14 },
		{ name = "Shop Vac", emoji = "🌪️", cost = 900, value = 19 },
		{ name = "Turbo Vac", emoji = "💨", cost = 6000, value = 26 },
		{ name = "Black Hole", emoji = "🕳️", cost = 50000, value = 36 },
	} :: { Level },

	-- highest buyable level per track (M1: 3 tools + 2 brushes on top of the free ones)
	Open = {
		Tools = 4,
		Brushes = 3,
		Backpack = 5,
		FindSlots = 4,
		Vacuum = 4,
	} :: { [string]: number },

	-- which shop sells which track
	Shops = {
		Workshop = { "Tools", "Brushes" },
		Commissary = { "Backpack", "FindSlots", "Vacuum" },
	} :: { [string]: { string } },
}

return Upgrades
