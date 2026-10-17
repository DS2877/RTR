--!strict
-- LIFER'S LOCKER (prestige meta): every escape earns FREEDOM POINTS (🗝️ FP), spent on permanent
-- perks at the steel locker in your cell (Services/Locker, Shared/Locker). Perks survive every
-- escape. FP can't be bought with Robux: you only get them by escaping.
--
-- A perk level's `value` means (Shared/Locker turns it into an effect):
--   HeadStart     the run starts with these upgrade levels already owned (`start`)
--   MuscleMemory  share of your strength kept on escape
--   QuickHands    extra punch power (0.1 = +10%)
--   DeepPockets   extra find slots
--   Bargain       share off every upgrade price (Tool Crib + Commissary, the catalog too)
--   NightOwl      extra finds when you dig at night, on top of Cycle.NightFindBonus

export type PerkLevel = {
	cost: number, -- FP for this level
	value: number,
	text: string, -- what this level does (the locker panel)
	start: { [string]: number }?, -- HeadStart only: upgrade track -> level owned at the start
}

export type Perk = {
	id: string,
	name: string,
	emoji: string,
	levels: { PerkLevel },
}

local Locker = {
	-- Freedom Points per escape: Base always, +Gold for a GOLD breakout medal, +Fast when the run
	-- (playtime since the last escape, offline time doesn't count) took at most FastMinutes
	Points = {
		Base = 1,
		Gold = 1,
		Fast = 1,
		FastMinutes = 75,
	},

	-- studs from the locker (the prompt reaches this far; the server allows a little slack)
	Range = 8,

	Perks = {
		{
			id = "HeadStart",
			name = "Head Start",
			emoji = "🎒",
			levels = {
				{
					cost = 1,
					value = 1,
					text = "Start each run with a Spoon + Sock",
					start = { Tools = 2, Backpack = 2 },
				},
				{
					cost = 2,
					value = 2,
					text = "...plus a Cross brush + Hand Vac",
					start = { Tools = 2, Backpack = 2, Brushes = 2, Vacuum = 2 },
				},
				{
					cost = 3,
					value = 3,
					text = "...plus a Shovel, Pillowcase + Fanny Pack",
					start = { Tools = 3, Backpack = 3, Brushes = 2, Vacuum = 2, FindSlots = 2 },
				},
			},
		},
		{
			id = "MuscleMemory",
			name = "Muscle Memory",
			emoji = "💪",
			levels = {
				{ cost = 2, value = 0.1, text = "Keep 10% of your strength when you escape" },
				{ cost = 4, value = 0.2, text = "Keep 20% of your strength when you escape" },
				{ cost = 6, value = 0.3, text = "Keep 30% of your strength when you escape" },
			},
		},
		{
			id = "QuickHands",
			name = "Quick Hands",
			emoji = "👊",
			levels = {
				{ cost = 2, value = 0.1, text = "+10% punch power" },
				{ cost = 3, value = 0.2, text = "+20% punch power" },
				{ cost = 5, value = 0.3, text = "+30% punch power" },
			},
		},
		{
			id = "DeepPockets",
			name = "Deep Pockets",
			emoji = "👖",
			levels = {
				{ cost = 1, value = 1, text = "+1 find slot" },
				{ cost = 2, value = 2, text = "+2 find slots" },
				{ cost = 3, value = 3, text = "+3 find slots" },
			},
		},
		{
			id = "Bargain",
			name = "Bargain Hunter",
			emoji = "🏷️",
			levels = {
				{ cost = 3, value = 0.1, text = "-10% on every upgrade" },
				{ cost = 5, value = 0.2, text = "-20% on every upgrade" },
			},
		},
		{
			id = "NightOwl",
			name = "Night Owl",
			emoji = "🦉",
			levels = {
				{ cost = 1, value = 0.15, text = "+15% more finds at night" },
				{ cost = 3, value = 0.3, text = "+30% more finds at night" },
			},
		},
	} :: { Perk },
}

return Locker
