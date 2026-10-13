--!strict
-- The appraiser: crates you bring home wait on the appraiser's table at your base, each with its
-- own countdown (they all tick at once). When one is READY, open it (prompt on the crate or the
-- Appraise panel) and the item inside lands on a free pedestal, or in your items if the plot is
-- full. The item + mutation were decided when the crate was stolen; opening only reveals them.

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
local CrateModel = require(script.Parent.Parent.Util.CrateModel)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Bases = require(script.Parent.Bases)
local Wallet = require(script.Parent.Wallet)

local Crates = {}

local models: { [Player]: { Model } } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rarityOf(id: string): string
	local info = Progression.item(id)
	return if info then info.rarity else "Common"
end

function Crates.capacity(player: Player): number
	local s = State.get(player)
	return if s then Progression.crateSlots(s.data.PlotLevel) else 0
end

local function timeText(secs: number): string
	secs = math.max(0, math.ceil(secs))
	if secs >= 60 then
		return string.format("%dm %02ds", secs // 60, secs % 60)
	end
	return secs .. "s"
end

-- Countdown labels + prompts + the HUD badge counts (called every second and on every change).
local function refresh(player: Player)
	local s = State.get(player)
	if not s then
		return
	end
	local t = now()
	local ready = 0
	for i, c in s.data.Crates do
		local isReady = t >= c.ReadyAt
		if isReady then
			ready += 1
		end
		local m = models[player] and models[player][i]
		local core = m and m.PrimaryPart
		if core then
			local label = core:FindFirstChild("Label")
			local timer = label and label:FindFirstChild("Title") :: TextLabel?
			if timer then
				timer.Text = if isReady then "READY!" else timeText(c.ReadyAt - t)
				timer.TextColor3 = if isReady then Color3.fromRGB(120, 255, 120) else Color3.new(1, 1, 1)
			end
			local pp = core:FindFirstChild("Appraise") :: ProximityPrompt?
			if pp then
				pp.Enabled = isReady
			end
		end
	end
	player:SetAttribute("Crates", #s.data.Crates)
	player:SetAttribute("CratesReady", ready)
	player:SetAttribute("CrateSlots", Crates.capacity(player))
end

function Crates.render(player: Player)
	local s = State.get(player)
	for _, m in models[player] or {} do
		m:Destroy()
	end
	models[player] = {}
	if not s or not s.base then
		return
	end
	local spots: { CFrame } = s.base.crateSpots or {}
	for i, c in s.data.Crates do
		local spot = spots[i]
		if spot then
			local rarity = rarityOf(c.Id)
			local info = Progression.item(c.Id)
			local m = CrateModel.build(
				rarity,
				{ title = "", scale = 1.1, theme = if info then Vaults[info.vault].id else nil }
			)
			m:PivotTo(spot * CFrame.new(0, 1.2, 0))
			local core = m.PrimaryPart :: BasePart
			local pp = Instance.new("ProximityPrompt")
			pp.Name = "Appraise"
			pp.ActionText = "Open"
			pp.ObjectText = rarity .. " Crate"
			pp.HoldDuration = 0.3
			pp.MaxActivationDistance = 9
			pp.RequiresLineOfSight = false
			pp.Enabled = false
			pp.Parent = core
			local index = i
			pp.Triggered:Connect(function(who)
				if who == player then
					Crates.appraise(player, index)
				end
			end)
			m.Parent = s.base.model
			models[player][i] = m
		end
	end
	refresh(player)
end

-- A stolen crate arrives home. False when the appraiser's table is full.
function Crates.add(player: Player, id: string, mut: string): boolean
	local s = State.get(player)
	if not s or #s.data.Crates >= Crates.capacity(player) then
		return false
	end
	table.insert(s.data.Crates, {
		Id = id,
		Mut = mut,
		ReadyAt = now() + Progression.appraiseSeconds(rarityOf(id)),
	})
	Crates.render(player)
	Bases.sync(player)
	return true
end

-- Puts an owned item on a free pedestal, else in the inventory. Returns "base", "bag" or nil (full).
function Crates.give(player: Player, id: string, mut: string): string?
	local s = State.get(player)
	if not s then
		return nil
	end
	if Bases.addItem(player, id, mut) then
		return "base"
	end
	if #s.data.Inventory >= Economy.InventoryMax then
		return nil
	end
	table.insert(s.data.Inventory, { Id = id, Mut = mut })
	s.data.Found[id] = true
	Bases.changed(player)
	return "bag"
end

-- Opens crate `index` if it's ready. Returns true when it opened.
function Crates.appraise(player: Player, index: number): boolean
	local s = State.get(player)
	local c = s and s.data.Crates[index]
	if not s or not c or now() < c.ReadyAt then
		return false
	end
	local where = Crates.give(player, c.Id, c.Mut)
	if not where then
		Net.notice(player, "Your items are full! Sell or place some first.", "bad")
		return false
	end
	table.remove(s.data.Crates, index)
	Crates.render(player)
	Bases.sync(player)
	local info = Progression.item(c.Id)
	local income = Progression.income(c.Id, c.Mut)
	-- a one-time bonus on top of the passive income (like the genre's hatch bonus)
	local bonus = math.floor(income * Economy.Crates.OpenBonusSeconds)
	Wallet.add(player, bonus)
	Net.fire(
		player,
		Remotes.Names.Revealed,
		if info then info.name else c.Id,
		if info then info.rarity else "Common",
		c.Mut,
		income,
		where,
		bonus
	)
	if info and (info.rarity == "Legendary" or info.rarity == "Mythic" or c.Mut == "Rainbow") then
		Net.announce(
			string.format(
				"%s found a %s%s in a %s crate! (%s/s)",
				player.DisplayName,
				if c.Mut ~= "None" then c.Mut .. " " else "",
				info.name,
				Vaults[info.vault].name,
				Format.cash(income)
			),
			Rarity.Tiers[info.rarity].color
		)
	end
	return true
end

-- Opens every ready crate (newest first, so indexes stay valid). Returns how many opened.
function Crates.appraiseAll(player: Player): number
	local s = State.get(player)
	if not s then
		return 0
	end
	local opened = 0
	for i = #s.data.Crates, 1, -1 do
		if Crates.appraise(player, i) then
			opened += 1
		end
	end
	return opened
end

function Crates.release(player: Player)
	for _, m in models[player] or {} do
		m:Destroy()
	end
	models[player] = nil
end

function Crates.start()
	local limit = RateLimit.new(6, 3)
	Net.on(Remotes.Names.Appraise, function(player, index)
		if not limit(player) or typeof(index) ~= "number" then
			return
		end
		if index == 0 then
			Crates.appraiseAll(player)
		elseif index >= 1 and index % 1 == 0 then
			Crates.appraise(player, index)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for player in State.all() do
				refresh(player)
			end
		end
	end)
end

return Crates
