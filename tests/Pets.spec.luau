--!strict
local Pets = require("../src/shared/Pets")
local Config = require("../src/shared/Config/Pets")

return function()
	-- levels
	assert(Pets.level(0) == 1, "a new pet is level 1")
	assert(Pets.level(Pets.xpFor(1)) == 2, "level 2 after the first threshold")
	assert(Pets.level(Pets.xpFor(1) - 1) == 1, "not before")
	assert(Pets.level(1e12) == Config.MaxLevel, "capped at the max level")
	for l = 2, Config.MaxLevel - 1 do
		assert(Pets.xpFor(l) > Pets.xpFor(l - 1), "each level costs more XP")
	end
	local _, into, need = Pets.level(Pets.xpFor(1) + 5)
	assert(into == 5 and need == Pets.xpFor(2), "xp into the level and the next threshold")
	-- perks grow with the level, every pet has a price and a text
	local seen: { [string]: boolean } = {}
	local lastPrice = 0
	for _, p in Config.List do
		assert(not seen[p.id], "unique pet id " .. p.id)
		seen[p.id] = true
		assert(Pets.perk(p.id, Config.MaxLevel) > Pets.perk(p.id, 1), "perk grows: " .. p.id)
		if not p.exclusive then
			assert(Pets.price(p.id) > lastPrice, "pets get pricier down the list: " .. p.id)
			lastPrice = Pets.price(p.id)
		end
		assert(Pets.perkText(p.id, 1) ~= "", "perk text: " .. p.id)
		if p.perk ~= "dig" and p.perk ~= "gold" then
			assert(Pets.perk(p.id, Config.MaxLevel) <= 0.5, "no runaway perks: " .. p.id)
		end
	end
	-- slots
	assert(Pets.slots(0) == 1 and Pets.slots(1) == 2 and Pets.slots(3) == 3 and Pets.slots(50) == 3, "slots")
	-- bonuses: only equipped + owned pets count, the same perk stacks
	local owned = { Rat = 0, Cat = Pets.xpFor(1), GoldRat = 0 }
	assert(Pets.bonus(owned, {}, "value") == 0, "nothing equipped")
	assert(math.abs(Pets.bonus(owned, { "Rat" }, "value") - Pets.perk("Rat", 1)) < 1e-9, "rat value")
	assert(Pets.bonus(owned, { "Rat" }, "power") == 0, "rat is no power pet")
	assert(math.abs(Pets.bonus(owned, { "Cat" }, "power") - Pets.perk("Cat", 2)) < 1e-9, "cat at level 2")
	assert(
		math.abs(
			Pets.bonus(owned, { "Rat", "GoldRat" }, "value") - Pets.perk("Rat", 1) - Pets.perk("GoldRat", 1)
		) < 1e-9,
		"the same perk stacks"
	)
	assert(Pets.bonus(owned, { "Bulldog" }, "power") == 0, "not owned = no bonus")
end
