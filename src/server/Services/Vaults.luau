--!strict
-- The rich people's loot: every spot in a zone holds one crate of a rolled rarity (the item and
-- a hidden mutation are rolled with it); steal it, and the spot refills after a while.
-- Loot is shared by the whole server, so rare crates are a race.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Progression)
local Economy = require(Shared.Config.Economy)
local Vaults = require(Shared.Config.Vaults)
local Rarity = require(Shared.Config.Rarity)

local Net = require(script.Parent.Parent.Net)
local CrateModel = require(script.Parent.Parent.Util.CrateModel)
local Carry = require(script.Parent.Carry)
local Events = require(script.Parent.Events)

local VaultLoot = {}

type Slot = {
	vault: number,
	pedestal: BasePart,
	model: Model?,
	id: string?,
	mut: string?,
	respawnAt: number,
}

local slots: { Slot } = {}
local rng = Random.new()

local function lootCFrame(ped: BasePart): CFrame
	-- on the floor marker, lock facing the middle of the zone (markers sit at +-lx)
	local toPath = Vector3.new(0, 0, -ped.Position.Z).Unit
	local core = ped.Position + Vector3.new(0, ped.Size.Y / 2 + 1.1 * 1.25, 0)
	return CFrame.lookAt(core, core + toPath)
end

local spawnLoot: (slot: Slot, id: string, mut: string) -> ()

-- STEAL on a vault pedestal: start carrying, empty the pedestal, schedule the refill.
local function take(slot: Slot, player: Player): boolean
	local model = slot.model
	if not model or not slot.id then
		return false
	end
	local takenId, takenMut = slot.id :: string, slot.mut :: string
	local ok = Carry.start(player, takenId, takenMut, "vault", function()
		-- dropped / caught: the loot goes straight back on its pedestal (if still empty)
		if not slot.id then
			spawnLoot(slot, takenId, takenMut)
		end
	end)
	if ok then
		model:Destroy()
		slot.model = nil
		slot.id = nil
		slot.mut = nil
		local r = Economy.VaultRespawnSeconds
		slot.respawnAt = os.clock() + rng:NextNumber(r[1], r[2])
		Net.notice(player, "RUN!! Get it home!", "info")
	else
		Net.notice(player, "You're already carrying something!", "bad")
	end
	return ok
end

function spawnLoot(slot: Slot, id: string, mut: string)
	if slot.model then
		slot.model:Destroy()
	end
	slot.id = id
	slot.mut = mut
	local info = Progression.item(id) :: Progression.ItemInfo
	local def = Vaults[slot.vault]
	-- a locked crate: everyone sees its rarity, nobody sees what's inside (or its mutation)
	local model = CrateModel.build(info.rarity, { title = def.name .. " Crate", scale = 1.25 })
	model:PivotTo(lootCFrame(slot.pedestal))
	model:SetAttribute("Vault", slot.vault)
	local core = model.PrimaryPart :: BasePart
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "Steal"
	pp.ActionText = "STEAL"
	pp.ObjectText = info.rarity .. " Crate"
	pp.HoldDuration = Economy.StealHoldSeconds
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight = false
	pp.Parent = core
	pp.Triggered:Connect(function(player)
		take(slot, player)
	end)
	model.Parent = slot.pedestal.Parent
	slot.model = model
	if Rarity.Tiers[info.rarity].glow then
		model:SetAttribute("Highlight", true)
	end
	if info.rarity == "Mythic" then
		Net.announce(
			string.format("✨ A MYTHIC crate appeared at %s's! ✨", def.name),
			Rarity.Tiers[info.rarity].color
		)
	end
end

local function roll(slot: Slot)
	local rarity = Progression.rollRarity(rng:NextNumber())
	-- GOLD RUSH: dividing the roll multiplies every mutation chance
	local mutRoll = rng:NextNumber() / (if Events.active("GoldRush") then Economy.Events.GoldRushMult else 1)
	local mut = Progression.rollMutation(mutRoll)
	spawnLoot(slot, Progression.vaultItem(slot.vault, rarity), mut)
end

function VaultLoot.start(worldInfo: any)
	for _, v in worldInfo.vaults do
		for _, ped in v.pedestals do
			local slot: Slot =
				{ vault = v.index, pedestal = ped, model = nil, id = nil, mut = nil, respawnAt = 0 }
			table.insert(slots, slot)
			roll(slot)
		end
	end
	-- GOLD RUSH starts: every vault restocks at once, with the boosted mutation odds
	workspace:GetAttributeChangedSignal("EventId"):Connect(function()
		if workspace:GetAttribute("EventId") == "GoldRush" then
			VaultLoot.rerollAll()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local t = os.clock()
			for _, slot in slots do
				if not slot.id and t >= slot.respawnAt then
					roll(slot)
				end
			end
		end
	end)
end

-- The loot on pedestal `ped` of vault `vault` (id, mutation), or nil while it refills.
function VaultLoot.lootAt(vault: number, ped: number): (string?, string?)
	local n = 0
	for _, slot in slots do
		if slot.vault == vault then
			n += 1
			if n == ped then
				return slot.id, slot.mut
			end
		end
	end
	return nil, nil
end

-- What the STEAL prompt on that pedestal does (also used by the smoke test).
function VaultLoot.stealAt(vault: number, ped: number, player: Player): boolean
	local n = 0
	for _, slot in slots do
		if slot.vault == vault then
			n += 1
			if n == ped then
				return take(slot, player)
			end
		end
	end
	return false
end

-- Admin: reroll everything (testing rare spawns)
function VaultLoot.rerollAll()
	for _, slot in slots do
		roll(slot)
	end
end

return VaultLoot
