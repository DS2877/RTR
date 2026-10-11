--!strict
local Cosmetics = require("../src/shared/Config/Cosmetics")
local Products = require("../src/shared/Config/Products")

local function check(ok: boolean, what: string)
	if not ok then
		error(what, 2)
	end
end

return function()
	-- Halloween: Oct 1 .. Nov 3, every year
	check(not Cosmetics.seasonActive({ month = 9, day = 30 }), "Sep 30 is not Halloween")
	check(Cosmetics.seasonActive({ month = 10, day = 1 }), "Oct 1 starts Halloween")
	check(Cosmetics.seasonActive({ month = 10, day = 31 }), "Oct 31 is Halloween")
	check(Cosmetics.seasonActive({ month = 11, day = 3 }), "Nov 3 is the last day")
	check(not Cosmetics.seasonActive({ month = 11, day = 4 }), "Nov 4 is over")

	-- every trail is valid; pass trails point at a real pass
	local ids: { [string]: boolean } = {}
	for _, t in Cosmetics.Trails do
		check(not ids[t.id], "duplicate trail " .. t.id)
		ids[t.id] = true
		check(#t.colors >= 1, t.id .. " has no colors")
		check(t.currency == "cash" or t.currency == "candy" or t.currency == "pass", t.id .. " currency")
		if t.currency == "pass" then
			check(t.pass ~= nil and Products.pass(t.pass :: string) ~= nil, t.id .. " pass missing")
		else
			check(t.price > 0, t.id .. " needs a price")
		end
	end
	-- cash trails get more expensive down the list
	local last = 0
	for _, t in Cosmetics.Trails do
		if t.currency == "cash" then
			check(t.price > last, t.id .. " should cost more than the previous trail")
			last = t.price
		end
	end
end
