--!strict
local Progression = require("../src/shared/Progression")
local Vaults = require("../src/shared/Config/Vaults")
local Rarity = require("../src/shared/Config/Rarity")

local function check(cond: boolean, msg: string)
	if not cond then
		error(msg, 2)
	end
end

return function()
	-- every vault has one item per rarity, ids are unique
	local seen = {}
	for _, v in Vaults do
		check(#v.items == #Rarity.Order, v.id .. " needs " .. #Rarity.Order .. " items")
		for _, it in v.items do
			check(not seen[it.id], "duplicate item id " .. it.id)
			seen[it.id] = true
		end
	end
	-- income grows with vault and rarity
	check(Progression.income("Radio") > Progression.income("Wrench"), "rarity raises income")
	check(Progression.income("Wrench", "Gold") == Progression.income("Wrench") * 2, "gold doubles")
	for i = 2, #Vaults do
		check(Vaults[i].baseIncome > Vaults[i - 1].baseIncome, "vault income grows")
		check(Vaults[i].guardSpeed > Vaults[i - 1].guardSpeed, "guards get faster")
	end
	-- crates: the appraiser holds more crates as the plot grows (capped), rarer crates take longer
	check(Progression.crateSlots(1) == 3, "3 crate slots at start")
	check(Progression.crateSlots(4) == 4, "+1 crate slot every 3 plot levels")
	check(Progression.crateSlots(100) == 8, "crate slots capped")
	for i = 2, #Rarity.Order do
		check(
			Progression.appraiseSeconds(Rarity.Order[i]) > Progression.appraiseSeconds(Rarity.Order[i - 1]),
			"rarer crates take longer"
		)
	end
	-- speed curve
	check(Progression.walkSpeed(0) == 16, "base speed 16")
	check(
		math.abs(Progression.walkSpeed(Progression.pointsFor(80)) - 80) < 1e-6,
		"pointsFor inverts walkSpeed"
	)
	check(Progression.walkSpeed(1e30) == 200, "speed capped")
	-- the last vault must be outrunnable below the cap
	check(Progression.speedToOutrun(#Vaults) < 200, "billionaire guards outrunnable")
	-- rolls
	check(Progression.rollRarity(0) == "Common", "r=0 common")
	check(Progression.rollRarity(0.99999) == "Mythic", "r~1 mythic")
	check(Progression.rollMutation(0) == "Rainbow", "r=0 rainbow")
	check(Progression.rollMutation(0.5) == "None", "r=.5 none")
	-- costs
	check(Progression.treadmillCost(1) == 60, "treadmill L1 cost")
	check(Progression.plotCost(13) == nil, "plot max")
	check(Progression.pedestals(13) == 30, "30 pedestals at max")
end
