--!strict
-- Your items that aren't on a pedestal (the hotbar / My Items panel): place one on the plot,
-- take one off, Equip Best (best earners on the pedestals, the rest in the bag), sell.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Progression)
local Format = require(Shared.Format)
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Bases = require(script.Parent.Bases)
local Wallet = require(script.Parent.Wallet)

local Inventory = {}

type Data_Item = { Id: string, Mut: string }

-- Bag item `index` -> a free pedestal.
function Inventory.equip(player: Player, index: number): boolean
	local s = State.get(player)
	local item = s and s.data.Inventory[index]
	if not s or not item then
		return false
	end
	if not Bases.freeSlot(player) then
		Net.notice(player, "No free pedestal! Take something off or upgrade your plot.", "bad")
		return false
	end
	table.remove(s.data.Inventory, index)
	Bases.addItem(player, item.Id, item.Mut)
	return true
end

-- Pedestal `slot` -> the bag.
function Inventory.unequip(player: Player, slot: string): boolean
	local s = State.get(player)
	local item = s and s.data.Slots[slot]
	if not s or not item or Bases.isHidden(player, slot) then
		return false
	end
	if #s.data.Inventory >= Economy.InventoryMax then
		Net.notice(player, "Your items are full! Sell something first.", "bad")
		return false
	end
	Bases.removeSlot(player, slot)
	table.insert(s.data.Inventory, { Id = item.Id, Mut = item.Mut })
	Bases.changed(player)
	return true
end

-- The best earners go on the pedestals, everything else into the bag.
function Inventory.equipBest(player: Player)
	local s = State.get(player)
	if not s then
		return
	end
	local pool: { Data_Item } = {}
	for key, item in s.data.Slots do
		if not Bases.isHidden(player, key) then
			table.insert(pool, { Id = item.Id, Mut = item.Mut })
			s.data.Slots[key] = nil
		end
	end
	for _, item in s.data.Inventory do
		table.insert(pool, item)
	end
	table.sort(pool, function(a, b)
		return Progression.income(a.Id, a.Mut) > Progression.income(b.Id, b.Mut)
	end)
	local bag = {}
	for _, item in pool do
		local slot = Bases.freeSlot(player)
		if slot then
			s.data.Slots[slot] = item
		else
			table.insert(bag, item)
		end
	end
	s.data.Inventory = bag
	Bases.render(player)
	Bases.changed(player)
end

-- Sell bag item `index`.
function Inventory.sell(player: Player, index: number): boolean
	local s = State.get(player)
	local item = s and s.data.Inventory[index]
	if not s or not item then
		return false
	end
	local value = Progression.sellValue(item.Id, item.Mut)
	table.remove(s.data.Inventory, index)
	Wallet.add(player, value)
	Bases.changed(player)
	Net.notice(player, "Sold for " .. Format.cash(value), "good")
	return true
end

function Inventory.start()
	local limit = RateLimit.new(8, 3)
	local function valid(player: Player, n: any): boolean
		return limit(player) and typeof(n) == "number" and n >= 1 and n % 1 == 0
	end
	Net.on(Remotes.Names.Equip, function(player, index)
		if valid(player, index) then
			Inventory.equip(player, index)
		end
	end)
	Net.on(Remotes.Names.Unequip, function(player, slot)
		if limit(player) and typeof(slot) == "string" and #slot <= 3 then
			Inventory.unequip(player, slot)
		end
	end)
	Net.on(Remotes.Names.EquipBest, function(player)
		if limit(player) then
			Inventory.equipBest(player)
		end
	end)
	Net.on(Remotes.Names.SellItem, function(player, kind, key)
		if not limit(player) then
			return
		end
		if kind == "bag" and typeof(key) == "number" and key >= 1 and key % 1 == 0 then
			Inventory.sell(player, key)
		elseif kind == "slot" and typeof(key) == "string" and #key <= 3 then
			Bases.sell(player, key)
		end
	end)
end

return Inventory
