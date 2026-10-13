--!strict
-- Robux items. An id of 0 means "not created on Roblox yet": the shop shows it as "Soon" and
-- nothing can be bought. Push a branch named ops/* to create them on Roblox: the ops workflow
-- (tools/ops/roblox_setup.py) creates missing ones by name, syncs prices and writes the ids back
-- (`id` for the pass/product itself, `giftId` for the developer product that gifts a pass).
-- Rules: known contents for everything bought with Robux, no random rewards for Robux, no fake
-- timers or fake "limited" labels. "BEST VALUE" is computed from the real amounts.

export type Pass = {
	key: string,
	id: number,
	giftId: number,
	name: string,
	emoji: string,
	price: number,
	desc: string,
}
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
			key = "VIP",
			id = 2026682948,
			giftId = 3717978609,
			name = "VIP",
			emoji = "💎",
			price = 299,
			desc = "+25% cash forever, a golden VIP tag over your head and a VIP chat tag.",
		},
		{
			key = "DoubleCash",
			id = 2026352893,
			giftId = 3717978612,
			name = "2x Cash",
			emoji = "💵",
			price = 199,
			desc = "Everything on your plot earns double, forever.",
		},
		{
			key = "AutoCollect",
			id = 2025980943,
			giftId = 3717978623,
			name = "Auto Collect",
			emoji = "🧲",
			price = 149,
			desc = "Your cash goes straight to your wallet every second. No more walking to the pad.",
		},
		{
			key = "DoubleSpeed",
			id = 2026682939,
			giftId = 3717978626,
			name = "2x Treadmill",
			emoji = "⚡",
			price = 149,
			desc = "Your treadmill gives double speed points, forever.",
		},
		{
			key = "QuickHands",
			id = 2026184973,
			giftId = 3717978633,
			name = "Quick Hands",
			emoji = "🧤",
			price = 99,
			desc = "Steal instantly: no more holding the STEAL button.",
		},
		{
			key = "RainbowTrail",
			id = 2025284943,
			giftId = 3717980845,
			name = "Rainbow Trail",
			emoji = "🌈",
			price = 79,
			desc = "A rainbow trail + x5 treadmill Speed while equipped. Equip it in the Trails shop.",
		},
		{
			key = "LongLock",
			id = 2026112940,
			giftId = 3717978641,
			name = "Mega Lock",
			emoji = "🔒",
			price = 99,
			desc = "Your base lock lasts 2x longer.",
		},
	} :: { Pass },
	Items = {
		{
			key = "Speed10",
			id = 3717972926,
			name = "Speed Pack",
			emoji = "👟",
			price = 29,
			desc = "+10 minutes of treadmill points instantly.",
			kind = "speed",
			amount = 600,
		},
		{
			key = "Speed60",
			id = 3717978642,
			name = "Mega Speed Pack",
			emoji = "🚀",
			price = 129,
			desc = "+60 minutes of treadmill points instantly.",
			kind = "speed",
			amount = 3600,
		},
		{
			key = "Cash30",
			id = 3717972928,
			name = "Cash Bag",
			emoji = "💰",
			price = 49,
			desc = "+30 minutes of your current income instantly.",
			kind = "cash",
			amount = 1800,
		},
		{
			key = "Cash180",
			id = 3717978646,
			name = "Cash Vault",
			emoji = "🏦",
			price = 199,
			desc = "+3 hours of your current income instantly.",
			kind = "cash",
			amount = 10800,
		},
	} :: { Product },

	-- Pass effects (balance lives here, the code reads these)
	VipCashBonus = 1.25,
	PremiumCashBonus = 1.1, -- Roblox Premium members
	MinCashProduct = 1000, -- a cash product always gives at least this much
}

-- Robux per unit of `amount` for each product kind; the cheapest per unit gets "BEST VALUE".
function Products.bestValue(): { [string]: string }
	local best: { [string]: { key: string, perUnit: number } } = {}
	for _, p in Products.Items do
		local perUnit = p.price / p.amount
		local b = best[p.kind]
		if not b or perUnit < b.perUnit then
			best[p.kind] = { key = p.key, perUnit = perUnit }
		end
	end
	local out = {}
	for kind, b in best do
		out[kind] = b.key
	end
	return out
end

function Products.pass(key: string): Pass?
	for _, p in Products.Passes do
		if p.key == key then
			return p
		end
	end
	return nil
end

return Products
