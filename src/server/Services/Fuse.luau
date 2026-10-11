--!strict
-- Fuse machine: 3 identical items (same item + mutation) on your plot -> 1 of the next mutation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Mutations = require(Shared.Config.Mutations)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Bases = require(script.Parent.Bases)

local Fuse = {}

local function fuse(player: Player, id: string, mut: string)
	local s = State.get(player)
	if not s or not Progression.item(id) or not Mutations.List[mut] then
		return
	end
	local nextMut = Mutations.next(mut)
	if not nextMut then
		Net.notice(player, "That's already the best mutation!", "bad")
		return
	end
	local matches: { string } = {}
	for slot, item in s.data.Slots do
		if item.Id == id and item.Mut == mut and not Bases.isHidden(player, slot) then
			table.insert(matches, slot)
		end
	end
	if #matches < Mutations.FuseCount then
		Net.notice(player, "You need " .. Mutations.FuseCount .. " of the same item.", "bad")
		return
	end
	table.sort(matches, function(a, b)
		return (tonumber(a) :: number) < (tonumber(b) :: number)
	end)
	for i = 1, Mutations.FuseCount do
		Bases.removeSlot(player, matches[i])
	end
	Bases.addItem(player, id, nextMut)
	local info = Progression.item(id) :: any
	Net.fire(
		player,
		Remotes.Names.Deposited,
		info.name,
		info.rarity,
		nextMut,
		Progression.income(id, nextMut),
		"FUSED!"
	)
	if nextMut == "Rainbow" then
		Net.announce(
			"🌈 " .. player.DisplayName .. " fused a RAINBOW " .. info.name .. "! 🌈",
			{ 255, 120, 220 }
		)
	end
end

Fuse.fuse = fuse

function Fuse.start(worldInfo: any)
	local limit = RateLimit.new(2, 4)
	worldInfo.fusePrompt.Triggered:Connect(function(player: Player)
		Bases.sync(player)
		Net.fire(player, Remotes.Names.OpenFuse)
	end)
	Net.on(Remotes.Names.Fuse, function(player, id, mut)
		if limit(player) and typeof(id) == "string" and typeof(mut) == "string" then
			fuse(player, id, mut)
		end
	end)
end

return Fuse
