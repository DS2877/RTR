--!strict
-- Rough economy simulation: one active player, 3 hours. Prints when each vault becomes
-- outrunnable and income over time.  `lune run tools/simulate`
local Progression = require("../src/shared/Progression")
local Economy = require("../src/shared/Config/Economy")
local Vaults = require("../src/shared/Config/Vaults")
local World = require("../src/shared/Config/World")
local Rarity = require("../src/shared/Config/Rarity")
local Format = require("../src/shared/Format")

local expectedMult = 0
local totalW = 0
for _, id in Rarity.Order do
	totalW += Rarity.Tiers[id].weight
end
for _, id in Rarity.Order do
	expectedMult += Rarity.Tiers[id].weight / totalW * Rarity.Tiers[id].mult
end

local t, cash, points, tread, plot = 0, 0, 0, 1, 1
local items: { number } = { Progression.income(Economy.StarterItem) }
local reached: { [number]: number } = {}
local function income(): number
	local s = 0
	for _, v in items do
		s += v
	end
	return s
end
local function advance(dt: number)
	t += dt
	cash += income() * dt
end
local function vaultX(i: number): number
	return World.StreetStartX + 60 + (i - 1) * World.VaultSpacing
end

while t < 6 * 3600 do
	local speed = Progression.walkSpeed(points)
	-- best vault we can outrun
	local best = 0
	for i = 1, #Vaults do
		if speed * Economy.CarrySlowdown.Common > Vaults[i].guardSpeed then
			best = i
		end
	end
	if best > 0 and not reached[best] then
		reached[best] = t
	end
	-- upgrades: buy cheapest affordable
	local tc = Progression.treadmillCost(tread)
	local pc = Progression.plotCost(plot)
	if tc and cash >= tc and (not pc or tc <= pc or #items < Progression.pedestals(plot)) then
		cash -= tc
		tread += 1
	elseif pc and cash >= pc and #items >= Progression.pedestals(plot) then
		cash -= pc
		plot += 1
	end
	-- next vault needs more speed? train 30s
	local nextV = best + 1
	if best == 0 or (Vaults[nextV] and speed * 0.9 < Vaults[nextV].guardSpeed and t % 120 < 60) then
		points += Progression.treadmillRate(tread) * 30
		advance(30)
	else
		local dist = vaultX(best) + 60
		advance(dist * 2 / (speed * 0.88) + 6)
		local value = Vaults[best].baseIncome * expectedMult
		if #items < Progression.pedestals(plot) then
			table.insert(items, value)
		else
			table.sort(items)
			if items[1] < value then
				cash += items[1] * Economy.SellSeconds
				items[1] = value
			end
		end
	end
end

local out = {}
for i = 1, #Vaults do
	table.insert(
		out,
		string.format(
			"%-22s %s",
			Vaults[i].name,
			if reached[i] then string.format("%.1f min", reached[i] / 60) else "not reached"
		)
	)
end
print(table.concat(out, "\n"))
print(
	string.format(
		"after 6h: treadmill L%d, plot L%d, %s/s, speed %.0f",
		tread,
		plot,
		Format.cash(income()),
		Progression.walkSpeed(points)
	)
)
