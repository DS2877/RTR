--!strict
-- Robux items. An id of 0 means "not created on Roblox yet": the shop shows it as "Soon" and
-- nothing can be bought. Push a branch named ops/* to create them on Roblox: the ops workflow
-- (tools/ops/roblox_setup.py) creates missing ones by name, syncs prices and writes the ids back.
-- Rules: known contents for everything bought with Robux, no random rewards for Robux.

export type Pass = { key: string, id: number, name: string, emoji: string, price: number, desc: string }
export type Product = {
	key: string,
	id: number,
	name: string,
	emoji: string,
	price: number,
	desc: string,
	kind: string, -- "speed" (treadmill seconds) | "cash" (seconds of current income)
	amount: number,
}

local Products = {
	Passes = {
		{
			key = "DoubleCash",
			id = 0,
			name = "2x Cash",
			emoji = "💵",
			price = 199,
			desc = "Everything on your plot earns double, forever.",
		},
		{
			key = "DoubleSpeed",
			id = 0,
			name = "2x Treadmill",
			emoji = "⚡",
			price = 149,
			desc = "Your treadmill gives double speed points, forever.",
		},
		{
			key = "LongLock",
			id = 0,
			name = "Mega Lock",
			emoji = "🔒",
			price = 99,
			desc = "Your base lock lasts 2x longer.",
		},
	} :: { Pass },
	Items = {
		{
			key = "Speed10",
			id = 0,
			name = "Speed Pack",
			emoji = "👟",
			price = 29,
			desc = "+10 minutes of treadmill points instantly.",
			kind = "speed",
			amount = 600,
		},
		{
			key = "Cash30",
			id = 0,
			name = "Cash Bag",
			emoji = "💰",
			price = 49,
			desc = "+30 minutes of your current income instantly.",
			kind = "cash",
			amount = 1800,
		},
	} :: { Product },
}

return Products
