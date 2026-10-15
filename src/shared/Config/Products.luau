--!strict
-- Game passes and developer products (M4). Known contents only, no paid randomness.
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
	Passes = {} :: { Product },
	Items = {} :: { Product },
}

return Products
