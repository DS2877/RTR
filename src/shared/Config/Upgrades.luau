--!strict
-- Every upgrade track. Level 1 is what a new prisoner starts with (cost 0).
-- Workshop (Tool Crib): Tools, Brushes, Cart. Commissary: Backpack, FindSlots, Vacuum.
-- `Open` = highest level that can be bought right now (raised with each milestone).

export type Level = {
	name: string,
	emoji: string,
	cost: number,
	value: number, -- tool: punch multiplier, backpack: rubble capacity, slots: find slots, vacuum: studs,
	-- cart: tunnel walk speed multiplier
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
		{ name = "Shovel", emoji = "⚒️", cost = 300, value = 4 },
		{ name = "Pickaxe", emoji = "⛏️", cost = 3000, value = 10 },
		{ name = "Jackhammer", emoji = "🔨", cost = 20000, value = 30 },
		{ name = "Drill", emoji = "⚙️", cost = 250000, value = 100 },
		{ name = "Laser", emoji = "🔦", cost = 3000000, value = 400 },
		{ name = "Plasma Cutter", emoji = "⚡", cost = 30000000, value = 1600 },
		{ name = "Quantum Fist", emoji = "⚛️", cost = 300000000, value = 7000 },
		{ name = "Freedom Fist", emoji = "🗽", cost = 2500000000, value = 30000 },
	} :: { Level },

	Brushes = {
		{ name = "Single", emoji = "▪️", cost = 0, cells = { { 0, 0 } } },
		{ name = "Cross", emoji = "➕", cost = 150, cells = cross },
		{ name = "3x3", emoji = "🔳", cost = 2500, cells = square(1) },
		{ name = "Big Cross", emoji = "✳️", cost = 150000, cells = square3cross },
		{ name = "5x5", emoji = "⬛", cost = 3000000, cells = square(2) },
	} :: { Brush },

	Backpack = {
		{ name = "Pockets", emoji = "👖", cost = 0, value = 40 },
		{ name = "Sock", emoji = "🧦", cost = 80, value = 120 },
		{ name = "Pillowcase", emoji = "🛏️", cost = 400, value = 130 },
		{ name = "Laundry Bag", emoji = "🧺", cost = 2200, value = 280 },
		{ name = "Duffel Bag", emoji = "👜", cost = 12000, value = 600 },
		{ name = "Mail Cart", emoji = "🛒", cost = 150000, value = 1300 },
		{ name = "Dumpster", emoji = "🗑️", cost = 1500000, value = 3000 },
		{ name = "Garbage Truck", emoji = "🚛", cost = 40000000, value = 8000 },
		{ name = "Cargo Train", emoji = "🚂", cost = 1500000000, value = 20000 },
	} :: { Level },

	FindSlots = {
		{ name = "Shirt Pocket", emoji = "👕", cost = 0, value = 3 },
		{ name = "Fanny Pack", emoji = "👝", cost = 200, value = 5 },
		{ name = "Briefcase", emoji = "💼", cost = 1500, value = 8 },
		{ name = "Suitcase", emoji = "🧳", cost = 12000, value = 12 },
		{ name = "Filing Cabinet", emoji = "🗃️", cost = 300000, value = 20 },
		{ name = "Smuggler's Crate", emoji = "📦", cost = 8000000, value = 30 },
	} :: { Level },

	Vacuum = {
		{ name = "Straw", emoji = "🥤", cost = 0, value = 10 },
		{ name = "Hand Vac", emoji = "🧹", cost = 100, value = 14 },
		{ name = "Shop Vac", emoji = "🔌", cost = 900, value = 19 },
		{ name = "Turbo Vac", emoji = "💨", cost = 6000, value = 26 },
		{ name = "Black Hole", emoji = "🕳️", cost = 200000, value = 36 },
		{ name = "Tornado", emoji = "🌪️", cost = 8000000, value = 50 },
	} :: { Level },

	-- CART: how fast you move inside YOUR OWN tunnel (value = walk speed multiplier; Services/Cart
	-- sets it, never in the cell, the corridors, other tunnels, THE BREAKOUT or with a stolen find)
	Cart = {
		{ name = "On Foot", emoji = "🚶", cost = 0, value = 1 },
		{ name = "Wheelbarrow", emoji = "🛞", cost = 2000, value = 1.25 },
		{ name = "Minecart", emoji = "🚃", cost = 40000, value = 1.6 },
		{ name = "Rail Car", emoji = "🚋", cost = 1500000, value = 2 },
		{ name = "Rocket Cart", emoji = "🚀", cost = 60000000, value = 2.5 },
	} :: { Level },

	-- cell defenses against raids (Commissary). Lock: value = seconds to pick the lock.
	Lock = {
		{ name = "No Lock", emoji = "🚪", cost = 0, value = 2 },
		{ name = "Padlock", emoji = "🔒", cost = 2500, value = 5 },
		{ name = "Deadbolt", emoji = "🔐", cost = 25000, value = 8 },
		{ name = "Vault Lock", emoji = "🏦", cost = 250000, value = 12 },
	} :: { Level },
	-- Trap: value 1 = slippery soap in front of the Stash
	Trap = {
		{ name = "No Trap", emoji = "➖", cost = 0, value = 0 },
		{ name = "Slippery Soap", emoji = "🧼", cost = 5000, value = 1 },
	} :: { Level },
	-- Alarm: value 1 = notice + beam to the thief
	Alarm = {
		{ name = "No Alarm", emoji = "➖", cost = 0, value = 0 },
		{ name = "Alarm Bell", emoji = "🔔", cost = 3000, value = 1 },
	} :: { Level },

	-- highest buyable level per track (raised with the milestones; M4 = everything)
	Open = {
		Tools = 10,
		Brushes = 5,
		Backpack = 9,
		FindSlots = 6,
		Vacuum = 6,
		Cart = 5,
		Lock = 4,
		Trap = 2,
		Alarm = 2,
	} :: { [string]: number },

	-- which shop sells which track
	Shops = {
		Workshop = { "Tools", "Brushes", "Cart" },
		Commissary = { "Backpack", "FindSlots", "Vacuum", "Lock", "Trap", "Alarm" },
	} :: { [string]: { string } },
}

return Upgrades
