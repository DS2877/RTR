--!strict
-- Carrying loot: pick up (from a vault or another player's base), RUN!!, drop, get caught/slapped,
-- deposit at your own base. Stolen player items stay in the victim's data until the thief gets home.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Progression)
local Format = require(Shared.Format)
local Economy = require(Shared.Config.Economy)
local Rarity = require(Shared.Config.Rarity)
local Vaults = require(Shared.Config.Vaults)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local ItemModel = require(script.Parent.Parent.Util.ItemModel)
local CrateModel = require(script.Parent.Parent.Util.CrateModel)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Bases = require(script.Parent.Bases)
local Movement = require(script.Parent.Movement)
local Wallet = require(script.Parent.Wallet)
local Crates = require(script.Parent.Crates)

local Carry = {}

-- Set by Richest: bounty for robbing the richest (victim) -> cash amount, or 0.
Carry.bountyFor = nil :: ((victim: Player) -> number)?
Carry.onRobbedRichest = nil :: ((thief: Player, victim: Player, bounty: number) -> ())?

local function setAttributes(player: Player)
	local s = State.get(player)
	local c = s and s.carry
	if c then
		local info = Progression.item(c.id)
		local crate = c.source == "vault"
		-- a crate's contents stay secret: only its rarity + whose crate it is are shown
		player:SetAttribute(
			"Carrying",
			if crate and info then Vaults[info.vault].name .. " Crate" elseif info then info.name else c.id
		)
		player:SetAttribute("CarryRarity", if info then info.rarity else "Common")
		player:SetAttribute("CarryMut", if crate then "None" else c.mut)
		-- the victim's client points a "GO GET THEM!" arrow at whoever carries their item
		player:SetAttribute("CarryVictim", if c.victim then c.victim.UserId else nil)
	else
		player:SetAttribute("Carrying", nil)
		player:SetAttribute("CarryRarity", nil)
		player:SetAttribute("CarryMut", nil)
		player:SetAttribute("CarryVictim", nil)
	end
end

local function attachModel(player: Player, carry: State.Carry)
	local character = player.Character
	if carry.source == "vault" then
		-- a crate is hugged in front of you
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local info = Progression.item(carry.id)
		local crate = CrateModel.build(if info then info.rarity else "Common", { scale = 0.9 })
		crate.Name = "CarriedLoot"
		ItemModel.weldTo(crate, root, CFrame.new(0, 0.6, -2.3))
		crate.Parent = character
		carry.model = crate
		return
	end
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local model = ItemModel.build(carry.id, carry.mut, { label = false })
	model.Name = "CarriedLoot"
	ItemModel.weldTo(model, head, CFrame.new(0, 3.2, 0))
	model.Parent = character
	carry.model = model
end

local function clear(player: Player)
	local s = State.get(player)
	if not s or not s.carry then
		return
	end
	local c = s.carry
	s.carry = nil
	if c.model then
		c.model:Destroy()
	end
	setAttributes(player)
	Movement.refresh(player)
end

function Carry.isCarrying(player: Player): boolean
	local s = State.get(player)
	return s ~= nil and s.carry ~= nil
end

-- Start carrying. Returns false if the player can't carry right now.
function Carry.start(
	player: Player,
	id: string,
	mut: string,
	source: string,
	restore: () -> (),
	victim: Player?,
	victimSlot: string?
): boolean
	local s = State.get(player)
	if not s or s.carry or not State.humanoid(player) or os.clock() < s.stunUntil then
		return false
	end
	local carry: State.Carry = {
		id = id,
		mut = mut,
		model = nil,
		source = source,
		victim = victim,
		victimSlot = victimSlot,
		restore = restore,
		startedAt = os.clock(),
	}
	s.carry = carry
	attachModel(player, carry)
	setAttributes(player)
	Movement.refresh(player)
	return true
end

-- Drop: the loot goes back where it came from.
function Carry.drop(player: Player, reason: string?)
	local s = State.get(player)
	if not s or not s.carry then
		return
	end
	local restore = s.carry.restore
	clear(player)
	restore()
	if reason then
		Net.notice(player, reason, "bad")
	end
end

-- Caught by a guard or slapped by a player. `tooSlow`: the guard was faster than you can ever
-- run with loot (the client may show the Speed Pack offer).
function Carry.caught(player: Player, by: string, tooSlow: boolean?)
	local s = State.get(player)
	if not s or not s.carry then
		return
	end
	Carry.drop(player)
	s.data.Stats.Caught += 1
	Net.fire(player, Remotes.Names.Caught, by, tooSlow == true)
	Movement.stun(player, Economy.StunSeconds) -- the knock-up is done by the client (it owns its physics)
end

local function deposit(player: Player)
	local s = State.get(player)
	local c = s and s.carry
	if not s or not c then
		return
	end
	if c.source == "vault" then
		-- a crate goes to the appraiser's table (full table: keep carrying, tell them once)
		if not Crates.add(player, c.id, c.mut) then
			if not (c :: any).warned then
				(c :: any).warned = true
				Net.notice(player, "The appraiser's table is full! Open your crates first.", "bad")
			end
			return
		end
		clear(player)
		local info = Progression.item(c.id)
		Net.fire(
			player,
			Remotes.Names.Deposited,
			if info then Vaults[info.vault].name .. " Crate" else "Crate",
			if info then info.rarity else "Common",
			"None",
			0,
			if info then "You stole from " .. string.upper(Vaults[info.vault].name) .. "!" else "STOLEN!"
		)
		s.data.Stats.Steals += 1
		player:SetAttribute("Steals", s.data.Stats.Steals + s.data.Stats.PlayerSteals)
		return
	end
	local slot = Bases.freeSlot(player)
	if not slot and #s.data.Inventory >= Economy.InventoryMax then
		-- plot and bag full: keep carrying, tell them once in a while
		if not (c :: any).warned then
			(c :: any).warned = true
			Net.notice(player, "Your plot and items are full! Sell something first.", "bad")
		end
		return
	end
	local victim = c.victim
	local victimSlot = c.victimSlot
	-- the bounty is priced while the item still counts toward the richest's income
	local bounty = if victim and Carry.bountyFor then Carry.bountyFor(victim) else 0
	clear(player)
	-- stolen from a player: now it really leaves their plot
	if victim and victimSlot then
		Bases.removeSlot(victim, victimSlot)
	end
	Crates.give(player, c.id, c.mut)

	local info = Progression.item(c.id)
	local income = Progression.income(c.id, c.mut)
	local title = if victim then "You robbed " .. string.upper(victim.DisplayName) .. "!" else "STOLEN!"
	Net.fire(
		player,
		Remotes.Names.Deposited,
		if info then info.name else c.id,
		if info then info.rarity else "Common",
		c.mut,
		income,
		title
	)

	if victim then
		s.data.Stats.PlayerSteals += 1
		Net.notice(
			victim,
			"😱 " .. player.DisplayName .. " stole your " .. (if info then info.name else c.id) .. "!",
			"bad"
		)
		if bounty > 0 then
			Wallet.add(player, bounty)
			s.data.Stats.RobbedRichest += 1
			if Carry.onRobbedRichest then
				Carry.onRobbedRichest(player, victim, bounty)
			end
		end
	else
		s.data.Stats.Steals += 1
	end
	player:SetAttribute("Steals", s.data.Stats.Steals + s.data.Stats.PlayerSteals)
	Wallet.sync(player)

	if info and (info.rarity == "Legendary" or info.rarity == "Mythic" or c.mut == "Rainbow") then
		local tier = Rarity.Tiers[info.rarity]
		Net.announce(
			string.format(
				"%s stole a %s%s! (%s/s)",
				player.DisplayName,
				if c.mut ~= "None" then c.mut .. " " else "",
				info.name,
				Format.cash(income)
			),
			tier.color
		)
	end
end

-- Thief triggered "Steal" on someone's plot item.
local function stealFromPlayer(thief: Player, owner: Player, slot: string)
	local ts, os_ = State.get(thief), State.get(owner)
	if not ts or not os_ or not os_.base or ts.carry then
		return
	end
	local item = os_.data.Slots[slot]
	if not item or Bases.isHidden(owner, slot) then
		return
	end
	local r = State.root(thief)
	if not r or not Bases.contains(os_.base, r.Position) then
		return
	end
	local ok = Carry.start(thief, item.Id, item.Mut, "player", function()
		if owner.Parent == Players and State.get(owner) then
			Bases.setHidden(owner, slot, false)
		end
	end, owner, slot)
	if ok then
		Bases.setHidden(owner, slot, true)
		Net.notice(
			owner,
			"🚨 "
				.. thief.DisplayName
				.. " is stealing your "
				.. (Progression.item(item.Id) :: any).name
				.. "! Slap them!",
			"bad"
		)
		Net.notice(thief, "RUN to your base!", "info")
	end
end

function Carry.startService()
	Bases.onSteal = stealFromPlayer
	local dropLimit = RateLimit.new(2, 3)
	local slapLimit = RateLimit.new(3, 3)

	Net.on(Remotes.Names.Drop, function(player)
		if dropLimit(player) then
			Carry.drop(player)
		end
	end)

	Net.on(Remotes.Names.Slap, function(player, targetId)
		if not slapLimit(player) or typeof(targetId) ~= "number" then
			return
		end
		local s = State.get(player)
		local target = Players:GetPlayerByUserId(targetId)
		if not s or not target or target == player then
			return
		end
		local t = os.clock()
		if t - s.lastSlap < Economy.SlapCooldown or t < s.stunUntil then
			return
		end
		local ts = State.get(target)
		local a, b = State.root(player), State.root(target)
		if not ts or not ts.carry or not a or not b then
			return
		end
		if (a.Position - b.Position).Magnitude > Economy.SlapRange then
			return
		end
		s.lastSlap = t
		local victim = (ts.carry :: State.Carry).victim
		Carry.caught(target, player.DisplayName)
		Net.notice(player, "👋 SLAPPED " .. target.DisplayName .. "!", "good")
		if victim == player then
			Net.announce(
				"👋 " .. player.DisplayName .. " SLAPPED the thief " .. target.DisplayName .. "!",
				{
					255,
					170,
					60,
				}
			)
		end
	end)

	-- deposit + safety loop
	task.spawn(function()
		while true do
			task.wait(0.15)
			for player, s in State.all() do
				if s.carry then
					local h = State.humanoid(player)
					local r = State.root(player)
					if not h or not r then
						Carry.drop(player)
					elseif s.carry.victim and not State.get(s.carry.victim) then
						-- the victim left: their item went with them
						clear(player)
						Net.notice(player, "They left the game with their loot!", "bad")
					elseif s.base and Bases.contains(s.base, r.Position) then
						deposit(player)
					end
				end
			end
		end
	end)
end

-- When a player leaves or dies with loot, it goes back.
function Carry.onLeaving(player: Player)
	Carry.drop(player)
	-- anyone carrying this player's items: those items left with their owner
	for other, s in State.all() do
		if s.carry and s.carry.victim == player then
			clear(other)
		end
	end
end

return Carry
