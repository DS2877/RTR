--!strict
-- NPC vault loot: every pedestal holds one rolled item; steal it, and it refills after a while.
-- Loot is shared by the whole server, so rare spawns are a race.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Progression)
local Economy = require(Shared.Config.Economy)
local Vaults = require(Shared.Config.Vaults)
local Rarity = require(Shared.Config.Rarity)

local Net = require(script.Parent.Parent.Net)
local ItemModel = require(script.Parent.Parent.Util.ItemModel)
local Carry = require(script.Parent.Carry)

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
	return ped.CFrame * CFrame.new(0, 1 + 2.4, 0) * CFrame.Angles(0, math.pi, 0)
end

local function spawnLoot(slot: Slot, id: string, mut: string)
	if slot.model then
		slot.model:Destroy()
	end
	slot.id = id
	slot.mut = mut
	local model = ItemModel.build(id, mut, { extraText = "🔒 " .. Vaults[slot.vault].name })
	ItemModel.place(model, lootCFrame(slot.pedestal))
	local core = model.PrimaryPart :: BasePart
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "Steal"
	pp.ActionText = "STEAL"
	pp.ObjectText = (Progression.item(id) :: any).name
	pp.HoldDuration = 0.4
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight = false
	pp.Parent = core
	pp.Triggered:Connect(function(player)
		if slot.model ~= model or not slot.id then
			return
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
	end)
	model.Parent = slot.pedestal.Parent
	slot.model = model
	local info = Progression.item(id)
	if info and (Rarity.Tiers[info.rarity].glow or mut ~= "None") then
		model:SetAttribute("Highlight", true)
	end
	if info and (info.rarity == "Mythic" or mut == "Rainbow") then
		Net.announce(
			string.format(
				"✨ A %s%s appeared at %s! ✨",
				if mut ~= "None" then mut .. " " else "",
				info.name,
				Vaults[slot.vault].name
			),
			Rarity.Tiers[info.rarity].color
		)
	end
end

local function roll(slot: Slot)
	local rarity = Progression.rollRarity(rng:NextNumber())
	local mut = Progression.rollMutation(rng:NextNumber())
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

-- Admin: reroll everything (testing rare spawns)
function VaultLoot.rerollAll()
	for _, slot in slots do
		roll(slot)
	end
end

return VaultLoot
