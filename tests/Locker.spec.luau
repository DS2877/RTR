--!strict
local Locker = require("../src/shared/Locker")
local Config = require("../src/shared/Config/Locker")
local Upgrades = require("../src/shared/Config/Upgrades")
local Progression = require("../src/shared/Progression")

return function()
	-- the perk table: 5-7 perks, each with known, rising FP costs and a text per level
	assert(#Config.Perks >= 5 and #Config.Perks <= 7, "5-7 perks")
	local seen: { [string]: boolean } = {}
	for _, p in Config.Perks do
		assert(not seen[p.id], "unique perk id " .. p.id)
		seen[p.id] = true
		assert(#p.levels >= 1, "levels for " .. p.id)
		local last = 0
		for i, l in p.levels do
			assert(l.cost > 0 and l.cost >= last, p.id .. " level " .. i .. " costs more than the last")
			assert(l.cost == math.floor(l.cost), "whole FP costs")
			assert(#l.text > 0, "text for " .. p.id .. " level " .. i)
			last = l.cost
		end
	end

	-- levels: unknown ids, junk and out-of-range values are 0 / clamped
	assert(Locker.level(nil, "QuickHands") == 0, "no perks = level 0")
	assert(Locker.level({ QuickHands = 2 }, "QuickHands") == 2, "level read")
	assert(Locker.level({ QuickHands = 99 }, "QuickHands") == 3, "clamped to the max")
	assert(Locker.level({ QuickHands = 0 / 0 }, "QuickHands") == 0, "NaN = 0")
	assert(Locker.level({ Nope = 2 }, "Nope") == 0, "unknown perk = 0")
	local clean = Locker.sanitize({ QuickHands = 2.7, Nope = 3, Bargain = -1, [5] = 1 } :: any)
	assert(clean.QuickHands == 2 and clean.Nope == nil and clean.Bargain == nil, "sanitize")
	assert(next(Locker.sanitize("junk")) == nil, "sanitize junk")

	-- costs
	assert(Locker.nextCost({}, "Bargain") == Config.Perks[5].levels[1].cost, "first level cost")
	assert(Locker.nextCost({ Bargain = 2 }, "Bargain") == nil, "maxed = nil")
	assert(Locker.nextCost({}, "Nope") == nil, "unknown = nil")
	local total = 0
	for _, p in Config.Perks do
		for _, l in p.levels do
			total += l.cost
		end
	end
	assert(Locker.remainingCost({}) == total, "everything left")
	assert(Locker.remainingCost({ HeadStart = 3 }) == total - 6, "minus a maxed perk")

	-- effects
	assert(
		Locker.powerMult({}) == 1 and math.abs(Locker.powerMult({ QuickHands = 1 }) - 1.1) < 1e-9,
		"quick hands"
	)
	assert(Locker.slotBonus({ DeepPockets = 2 }) == 2, "deep pockets")
	assert(math.abs(Locker.priceMult({ Bargain = 1 }) - 0.9) < 1e-9, "bargain")
	assert(Locker.nightBonus({ NightOwl = 2 }) > Locker.nightBonus({ NightOwl = 1 }), "night owl rises")
	assert(next(Locker.headStart({})) == nil, "no head start without the perk")
	local hs = Locker.headStart({ HeadStart = 1 })
	assert(hs.Tools == 2 and hs.Backpack == 2, "spoon + sock")
	assert(
		Upgrades.Tools[hs.Tools].name == "Spoon" and Upgrades.Backpack[hs.Backpack].name == "Sock",
		"named right"
	)
	for lv = 1, 3 do
		for track, level in Locker.headStart({ HeadStart = lv }) do
			assert((Upgrades :: any)[track][level] ~= nil, "head start level exists: " .. track)
		end
	end
	assert(Locker.strengthAfterEscape({}, 50000, 10) == 10, "no perk: back to the start")
	assert(Locker.strengthAfterEscape({ MuscleMemory = 3 }, 50000, 10) == 15000, "keep 30%")
	assert(Locker.strengthAfterEscape({ MuscleMemory = 1 }, 20, 10) == 10, "never under the start")

	-- the shops' prices (server and client both use Progression.upgradeCost)
	local full = Progression.nextCost("Tools", 2) :: number
	assert(Progression.upgradeCost("Tools", 2, nil) == full, "no perk = full price")
	assert(Progression.upgradeCost("Tools", 2, { Bargain = 2 }) == math.ceil(full * 0.8), "-20%")
	assert(Progression.upgradeCost("Tools", #Upgrades.Tools, { Bargain = 2 }) == nil, "maxed stays nil")
	assert(
		Progression.upgradeCost("Cart", 1, { Bargain = 1 }) == math.ceil(Upgrades.Cart[2].cost * 0.9),
		"cart too"
	)
	assert(Progression.findSlots(1, 2) == Upgrades.FindSlots[1].value + 2, "find slots + deep pockets")

	-- Freedom Points
	local pts = Config.Points
	assert(Locker.escapePoints(pts.FastMinutes) == pts.Base + pts.Fast, "fast run bonus")
	assert(Locker.escapePoints(pts.FastMinutes + 1) == pts.Base, "slow run = base")
	assert(Locker.escapePoints(-5) == pts.Base, "a broken clock never gives the bonus")
	assert(Locker.medalPoints("gold") == pts.Gold and Locker.medalPoints("silver") == 0, "gold medal")
	assert(Locker.medalPoints("") == 0, "no medal")

	-- the cart: speeds rise, level 1 walks
	assert(Progression.cartSpeed(1) == 1, "on foot")
	for i = 2, #Upgrades.Cart do
		assert(Upgrades.Cart[i].value > Upgrades.Cart[i - 1].value, "cart speeds rise")
		assert(Upgrades.Cart[i].cost > Upgrades.Cart[i - 1].cost, "cart costs rise")
	end
	assert(table.find(Upgrades.Shops.Workshop, "Cart") ~= nil, "the Tool Crib sells carts")
end
