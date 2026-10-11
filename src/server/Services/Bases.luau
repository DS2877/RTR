--!strict
-- Player bases: assignment, items on pedestals, income + collect pad, upgrades, sell, lock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Progression)
local Format = require(Shared.Format)
local Economy = require(Shared.Config.Economy)
local Products = require(Shared.Config.Products)
local World = require(Shared.Config.World)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local ItemModel = require(script.Parent.Parent.Util.ItemModel)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Wallet = require(script.Parent.Wallet)
local Events = require(script.Parent.Events)

local Bases = {}

-- Set by Carry: (thief, owner, slot) when someone triggers "Steal" on a plot item.
Bases.onSteal = nil :: ((thief: Player, owner: Player, slot: string) -> ())?
-- Set by init: called whenever a player's plot changes (net worth may change).
Bases.onChanged = nil :: ((player: Player) -> ())?

local bases: { any } = {}
local owners: { [number]: Player } = {}
local slotModels: { [Player]: { [string]: Model } } = {}
local hidden: { [Player]: { [string]: boolean } } = {} -- slots being stolen right now
local lastCollect: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

function Bases.contains(base: any, pos: Vector3): boolean
	local l = (base.origin :: CFrame):PointToObjectSpace(pos)
	local depth = -l.Z
	return math.abs(l.X) <= World.BaseWidth / 2 and depth >= 0 and depth <= World.BaseDepth and l.Y < 40
end

function Bases.ownerOf(base: any): Player?
	return owners[base.id]
end

function Bases.incomeMult(player: Player): number
	local s = State.get(player)
	if not s then
		return 1
	end
	local m = 1
	if s.passes.DoubleCash then
		m *= 2
	end
	if s.passes.VIP then
		m *= Products.VipCashBonus
	end
	if typeof(player) == "Instance" and player.MembershipType == Enum.MembershipType.Premium then
		m *= Products.PremiumCashBonus
	end
	if s.isRichest then
		m *= Economy.Richest.IncomeBonus
	end
	if Events.active("CashFrenzy") then
		m *= Economy.Events.CashFrenzyMult
	end
	return m
end

function Bases.incomePerSecond(player: Player): number
	local s = State.get(player)
	if not s then
		return 0
	end
	local total = 0
	for _, item in s.data.Slots do
		total += Progression.income(item.Id, item.Mut)
	end
	return total * Bases.incomeMult(player)
end

function Bases.netWorth(player: Player): number
	local s = State.get(player)
	if not s then
		return 0
	end
	local worth = s.data.Cash + s.data.Pending
	for _, item in s.data.Slots do
		worth += Progression.sellValue(item.Id, item.Mut)
	end
	return worth
end

function Bases.sync(player: Player)
	local s = State.get(player)
	if not s then
		return
	end
	Net.fire(player, Remotes.Names.Sync, {
		Found = s.data.Found,
		Slots = s.data.Slots,
		Passes = s.passes,
	})
end

local function changed(player: Player)
	Bases.sync(player)
	player:SetAttribute("CashPerSec", Bases.incomePerSecond(player))
	if Bases.onChanged then
		Bases.onChanged(player)
	end
end

local function updatePrompts(player: Player)
	local s = State.get(player)
	if not s or not s.base then
		return
	end
	local base = s.base
	local plotPrompt = base.plotSign:FindFirstChild("Upgrade") :: ProximityPrompt
	local pc = Progression.plotCost(s.data.PlotLevel)
	plotPrompt.ActionText = if pc then "Upgrade Plot" else "Plot MAX"
	plotPrompt.ObjectText = if pc
		then string.format("Lv %d → %d  (%s)", s.data.PlotLevel, s.data.PlotLevel + 1, Format.cash(pc))
		else "Max level"
	local treadPrompt = base.treadSign:FindFirstChild("Upgrade") :: ProximityPrompt
	local tc = Progression.treadmillCost(s.data.Treadmill)
	treadPrompt.ActionText = if tc then "Upgrade Treadmill" else "Treadmill MAX"
	treadPrompt.ObjectText = if tc
		then string.format("Lv %d → %d  (%s)", s.data.Treadmill, s.data.Treadmill + 1, Format.cash(tc))
		else "Max level"
	player:SetAttribute("PlotLevel", s.data.PlotLevel)
	player:SetAttribute("Treadmill", s.data.Treadmill)
	player:SetAttribute("TreadmillRate", Progression.treadmillRate(s.data.Treadmill))
end

local function itemCFrame(ped: BasePart): CFrame
	return ped.CFrame * CFrame.new(0, 0.6 + 2.4, 0) * CFrame.Angles(0, math.pi, 0)
end

local function renderSlot(player: Player, slot: string)
	local s = State.get(player)
	if not s or not s.base then
		return
	end
	local models = slotModels[player]
	if not models then
		models = {}
		slotModels[player] = models
	end
	local old = models[slot]
	if old then
		old:Destroy()
		models[slot] = nil
	end
	local item = s.data.Slots[slot]
	local ped: BasePart? = s.base.pedestals[tonumber(slot) :: number]
	if not item or not ped or (hidden[player] and hidden[player][slot]) then
		return
	end
	local model = ItemModel.build(item.Id, item.Mut)
	ItemModel.place(model, itemCFrame(ped))
	model:SetAttribute("Slot", slot)
	local core = model.PrimaryPart :: BasePart
	local value = Progression.sellValue(item.Id, item.Mut)

	local steal = Instance.new("ProximityPrompt")
	steal.Name = "Steal"
	steal.ActionText = "Steal"
	steal.ObjectText = (Progression.item(item.Id) :: any).name
	steal.HoldDuration = 0.6
	steal.MaxActivationDistance = 9
	steal.RequiresLineOfSight = false
	steal.Parent = core
	steal.Triggered:Connect(function(thief)
		if thief ~= player and Bases.onSteal then
			Bases.onSteal(thief, player, slot)
		end
	end)

	local sell = Instance.new("ProximityPrompt")
	sell.Name = "Sell"
	sell.ActionText = "Sell " .. Format.cash(value)
	sell.ObjectText = (Progression.item(item.Id) :: any).name
	sell.HoldDuration = 0.8
	sell.MaxActivationDistance = 9
	sell.RequiresLineOfSight = false
	sell.KeyboardKeyCode = Enum.KeyCode.F
	sell.UIOffset = Vector2.new(0, 80)
	sell.Parent = core
	sell.Triggered:Connect(function(who)
		if who == player then
			Bases.sell(player, slot)
		end
	end)

	model.Parent = s.base.model
	models[slot] = model
end

function Bases.render(player: Player)
	local s = State.get(player)
	if not s or not s.base then
		return
	end
	local unlocked = Progression.pedestals(s.data.PlotLevel)
	for i, ped in s.base.pedestals do
		local open = i <= unlocked
		ped.Transparency = if open then 0 else 0.75
		ped.Color = if open then Color3.fromRGB(245, 245, 250) else Color3.fromRGB(120, 120, 130)
		ped.Material = if open then Enum.Material.Marble else Enum.Material.ForceField
		local ring = s.base.rings and s.base.rings[i]
		if ring then
			ring.Transparency = if open then 0 else 1
		end
	end
	for i = 1, #s.base.pedestals do
		renderSlot(player, tostring(i))
	end
	updatePrompts(player)
end

function Bases.assign(player: Player): any?
	local s = State.get(player)
	if not s then
		return nil
	end
	for _, base in bases do
		if not owners[base.id] then
			owners[base.id] = player
			s.base = base
			base.model:SetAttribute("OwnerUserId", player.UserId)
			base.model:SetAttribute("OwnerName", player.DisplayName)
			base.model:SetAttribute("LockedUntil", 0)
			base.model:SetAttribute("LockReadyAt", 0)
			base.signLabel.Text = string.upper(player.DisplayName) .. "'S BASE"
			player:SetAttribute("BaseId", base.id)
			Bases.render(player)
			changed(player)
			return base
		end
	end
	return nil
end

function Bases.release(player: Player)
	local s = State.get(player)
	local models = slotModels[player]
	if models then
		for _, m in models do
			m:Destroy()
		end
	end
	slotModels[player] = nil
	hidden[player] = nil
	lastCollect[player] = nil
	if s and s.base then
		local base = s.base
		owners[base.id] = nil
		base.model:SetAttribute("OwnerUserId", nil)
		base.model:SetAttribute("OwnerName", nil)
		base.model:SetAttribute("LockedUntil", 0)
		base.signLabel.Text = "EMPTY BASE"
		base.pendingLabel.Text = ""
		base.laser.CanCollide = false
		base.laser.Transparency = 1
		base.beam.Transparency = 1
		s.base = nil
	end
end

-- First free unlocked slot, or nil when the plot is full.
function Bases.freeSlot(player: Player): string?
	local s = State.get(player)
	if not s then
		return nil
	end
	for i = 1, Progression.pedestals(s.data.PlotLevel) do
		local key = tostring(i)
		if not s.data.Slots[key] then
			return key
		end
	end
	return nil
end

function Bases.addItem(player: Player, id: string, mut: string): string?
	local s = State.get(player)
	if not s then
		return nil
	end
	local slot = Bases.freeSlot(player)
	if not slot then
		return nil
	end
	s.data.Slots[slot] = { Id = id, Mut = mut }
	s.data.Found[id] = true
	renderSlot(player, slot)
	changed(player)
	Bases.celebrate(player, slot)
	return slot
end

-- A burst of sparkles + coins on a pedestal (everyone nearby sees it).
function Bases.celebrate(player: Player, slot: string)
	local s = State.get(player)
	local ped: BasePart? = s and s.base and s.base.pedestals[tonumber(slot) :: number]
	if not ped then
		return
	end
	local burst = ped:FindFirstChild("Burst") :: ParticleEmitter?
	if not burst then
		local e = Instance.new("ParticleEmitter")
		e.Name = "Burst"
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 255, 255))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(0.6, 1.1)
		e.Speed = NumberRange.new(10, 18)
		e.SpreadAngle = Vector2.new(60, 60)
		e.Acceleration = Vector3.new(0, -30, 0)
		e.LightEmission = 1
		e.Rate = 120
		e.EmissionDirection = Enum.NormalId.Top
		e.Enabled = false
		e.Parent = ped
		burst = e
	end
	local b = burst :: ParticleEmitter
	b.Enabled = true
	task.delay(0.35, function()
		b.Enabled = false
	end)
end

function Bases.removeSlot(player: Player, slot: string): boolean
	local s = State.get(player)
	if not s or not s.data.Slots[slot] then
		return false
	end
	s.data.Slots[slot] = nil
	if hidden[player] then
		hidden[player][slot] = nil
	end
	renderSlot(player, slot)
	changed(player)
	return true
end

-- Hide/show an item while a thief is carrying it (it stays in the owner's data until deposited).
function Bases.setHidden(player: Player, slot: string, isHidden: boolean)
	hidden[player] = hidden[player] or {}
	hidden[player][slot] = if isHidden then true else nil
	renderSlot(player, slot)
end

function Bases.isHidden(player: Player, slot: string): boolean
	return hidden[player] ~= nil and hidden[player][slot] == true
end

function Bases.sell(player: Player, slot: string)
	local s = State.get(player)
	if not s then
		return
	end
	local item = s.data.Slots[slot]
	if not item or Bases.isHidden(player, slot) then
		return
	end
	local value = Progression.sellValue(item.Id, item.Mut)
	Bases.removeSlot(player, slot)
	Wallet.add(player, value)
	Net.notice(player, "Sold for " .. Format.cash(value), "good")
end

local function teleportIntrudersOut(base: any, owner: Player)
	for p in State.all() do
		if p ~= owner then
			local r = State.root(p)
			local character = p.Character
			if r and character and Bases.contains(base, r.Position) then
				-- 10 studs out in front of the entrance, facing away from the base
				character:PivotTo(base.origin * CFrame.new(0, 4, 10) * CFrame.Angles(0, math.pi, 0))
			end
		end
	end
end

local function setLaser(base: any, on: boolean)
	base.laser.CanCollide = on
	base.laser.Transparency = if on then 0.35 else 1
end

function Bases.lock(player: Player)
	local s = State.get(player)
	if not s or not s.base then
		return
	end
	local base = s.base
	if s.isRichest and not Economy.Richest.CanLock then
		Net.notice(player, "👑 The Richest can't lock their base!", "bad")
		return
	end
	local t = now()
	if t < (base.model:GetAttribute("LockReadyAt") or 0) then
		return
	end
	local secs = Economy.LockSeconds * (if s.passes.LongLock then 2 else 1)
	base.model:SetAttribute("LockedUntil", t + secs)
	base.model:SetAttribute("LockReadyAt", t + secs + Economy.LockCooldown)
	setLaser(base, true)
	teleportIntrudersOut(base, player)
	Net.notice(player, "🔒 Base locked for " .. secs .. "s", "good")
end

function Bases.unlock(base: any)
	base.model:SetAttribute("LockedUntil", 0)
	setLaser(base, false)
end

local function collect(player: Player)
	local s = State.get(player)
	if not s then
		return
	end
	local t = os.clock()
	if lastCollect[player] and t - lastCollect[player] < 0.6 then
		return
	end
	lastCollect[player] = t
	local amount = math.floor(s.data.Pending)
	if amount < 1 then
		return
	end
	s.data.Pending -= amount
	Wallet.add(player, amount)
	s.data.Stats.Collected += 1
	player:SetAttribute("Collected", s.data.Stats.Collected)
	Net.notice(player, "+" .. Format.cash(amount), "cash")
	Net.fire(player, Remotes.Names.CashFX, amount, if s.base then s.base.collectPad.Position else nil)
end

local function upgradePlot(player: Player)
	local s = State.get(player)
	if not s then
		return
	end
	local cost = Progression.plotCost(s.data.PlotLevel)
	if not cost then
		return
	end
	if not Wallet.spend(player, cost) then
		Net.notice(player, "Need " .. Format.cash(cost), "bad")
		Net.fire(player, Remotes.Names.Offer, "cash")
		return
	end
	s.data.PlotLevel += 1
	Bases.render(player)
	changed(player)
	Net.notice(
		player,
		"Plot upgraded! " .. Progression.pedestals(s.data.PlotLevel) .. " pedestals",
		"upgrade"
	)
end

local function upgradeTreadmill(player: Player)
	local s = State.get(player)
	if not s then
		return
	end
	local cost = Progression.treadmillCost(s.data.Treadmill)
	if not cost then
		return
	end
	if not Wallet.spend(player, cost) then
		Net.notice(player, "Need " .. Format.cash(cost), "bad")
		Net.fire(player, Remotes.Names.Offer, "cash")
		return
	end
	s.data.Treadmill += 1
	updatePrompts(player)
	Net.notice(player, "Treadmill level " .. s.data.Treadmill .. "!", "upgrade")
end

local function ownerOfPrompt(base: any, player: Player): boolean
	return owners[base.id] == player
end

function Bases.start(worldInfo: any)
	bases = worldInfo.bases
	local lockLimit = RateLimit.new(1, 3)

	for _, base in bases do
		local plotPrompt = Instance.new("ProximityPrompt")
		plotPrompt.Name = "Upgrade"
		plotPrompt.HoldDuration = 0
		plotPrompt.MaxActivationDistance = 12
		plotPrompt.RequiresLineOfSight = false
		plotPrompt.Parent = base.plotSign
		plotPrompt.Triggered:Connect(function(player)
			if ownerOfPrompt(base, player) then
				upgradePlot(player)
			end
		end)
		local treadPrompt = plotPrompt:Clone()
		treadPrompt.Parent = base.treadSign
		treadPrompt.Triggered:Connect(function(player)
			if ownerOfPrompt(base, player) then
				upgradeTreadmill(player)
			end
		end)
		base.collectPad.Touched:Connect(function(hit)
			local p = Players:GetPlayerFromCharacter(hit.Parent)
			if p and owners[base.id] == p then
				collect(p)
			end
		end)
	end

	Net.on(Remotes.Names.Lock, function(player)
		if lockLimit(player) then
			Bases.lock(player)
		end
	end)

	-- income tick + lock expiry
	task.spawn(function()
		while true do
			task.wait(1)
			local t = now()
			for player, s in State.all() do
				if s.base then
					local inc = Bases.incomePerSecond(player)
					s.data.Pending += inc
					player:SetAttribute("CashPerSec", inc)
					if s.passes.AutoCollect and s.data.Pending >= 1 then
						-- Auto Collect pass: straight into the wallet, quietly
						local amount = math.floor(s.data.Pending)
						s.data.Pending -= amount
						Wallet.add(player, amount)
						if s.data.Stats.Collected == 0 then
							s.data.Stats.Collected = 1
							player:SetAttribute("Collected", 1)
						end
					end
					s.base.pendingLabel.Text = if s.passes.AutoCollect
						then "🧲 AUTO COLLECT"
						else "💰 COLLECT " .. Format.cash(math.floor(s.data.Pending))
					local lockedUntil = s.base.model:GetAttribute("LockedUntil") or 0
					if lockedUntil > 0 and t >= lockedUntil then
						Bases.unlock(s.base)
					elseif lockedUntil > 0 then
						-- nobody gets past a lock (not even by turning the laser off on their own client)
						teleportIntrudersOut(s.base, player)
					end
					-- standing still on the pad keeps collecting (Touched only fires on a new step)
					local r = State.root(player)
					if r then
						local l = (s.base.collectPad :: BasePart).CFrame:PointToObjectSpace(r.Position)
						if math.abs(l.X) <= 4.5 and math.abs(l.Z) <= 4.5 and l.Y > 0 and l.Y < 7 then
							collect(player)
						end
					end
				end
			end
		end
	end)
end

Bases.changed = changed
Bases.updatePrompts = updatePrompts
-- what the Upgrade prompts / collect pad do (also used by the smoke test)
Bases.upgradePlot = upgradePlot
Bases.upgradeTreadmill = upgradeTreadmill
Bases.collect = collect

return Bases
