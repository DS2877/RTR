--!strict
-- 👑 THE RICHEST — the twist.
-- The richest player on the server wears a crown, their base shoots a golden beam into the sky,
-- their face goes on the WANTED board, they earn +50%... and they can never lock their base.
-- Robbing them pays a bounty (paid by the game, on top of the item).
-- Longest reigns go on a global leaderboard.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local Bases = require(script.Parent.Bases)
local Carry = require(script.Parent.Carry)

local Richest = {}

local R = Economy.Richest
local current: Player? = nil
local wanted: any = nil
local reignLines: { TextLabel } = {}
local reignStore: OrderedDataStore? = nil
local nameCache: { [number]: string } = {}
pcall(function()
	reignStore = DataStoreService:GetOrderedDataStore("RTR_LongestReign_v1")
end)

-- 1 at the start of a reign, growing every minute up to R.MaxGrowth.
local function growth(player: Player): number
	local s = State.get(player)
	if not s or not s.isRichest then
		return 1
	end
	local minutes = (os.clock() - s.reignStart) / 60
	return math.min(R.MaxGrowth, 1 + R.GrowthPerMinute * minutes)
end

local function bounty(victim: Player): number
	local base = math.max(R.MinBounty, Bases.incomePerSecond(victim) * R.BountySeconds)
	return math.floor(base * growth(victim))
end

local function crownModel(): Model
	local model = Instance.new("Model")
	model.Name = "Crown"
	local gold = Color3.fromRGB(255, 205, 40)
	local band = Instance.new("Part")
	band.Name = "Band"
	band.Shape = Enum.PartType.Cylinder
	band.Size = Vector3.new(0.7, 2.2, 2.2)
	band.Color = gold
	band.Material = Enum.Material.SmoothPlastic
	band.CanCollide = false
	band.Massless = true
	band.Parent = model
	model.PrimaryPart = band
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		local spike = Instance.new("Part")
		spike.Name = "Spike"
		spike.Size = Vector3.new(0.4, 0.9, 0.4)
		spike.Color = gold
		spike.Material = Enum.Material.SmoothPlastic
		spike.CanCollide = false
		spike.Massless = true
		spike.CFrame = band.CFrame
			* CFrame.new(0.6, math.cos(a) * 0.95, math.sin(a) * 0.95)
			* CFrame.Angles(0, 0, math.rad(90))
		local gem = Instance.new("Part")
		gem.Name = "Gem"
		gem.Shape = Enum.PartType.Ball
		gem.Size = Vector3.new(0.35, 0.35, 0.35)
		gem.Color = Color3.fromRGB(255, 40, 80)
		gem.Material = Enum.Material.Neon
		gem.CanCollide = false
		gem.Massless = true
		-- the spike is turned 90° about Z, so its -Y axis points up out of the band
		gem.CFrame = spike.CFrame * CFrame.new(0, -0.5, 0)
		for _, p in { spike, gem } do
			local w = Instance.new("WeldConstraint")
			w.Part0 = band
			w.Part1 = p
			w.Parent = p
			p.Parent = model
		end
	end
	local light = Instance.new("PointLight")
	light.Color = gold
	light.Brightness = 3
	light.Range = 14
	light.Parent = band
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = gold
	sparkles.Parent = band
	return model
end

-- Builds a crown and welds it on top of `head`; `scale` grows with the reign.
-- (Exported for the smoke test.)
function Richest.attachCrown(head: BasePart, parent: Instance, scale: number?): Model
	local crown = crownModel()
	if scale and scale ~= 1 then
		crown:ScaleTo(scale)
	end
	local band = crown.PrimaryPart :: BasePart
	-- cylinder axis is X: stand it up (band bottom just above the head)
	local lift = head.Size.Y / 2 + band.Size.X / 2 + 0.25
	crown:PivotTo(head.CFrame * CFrame.new(0, lift, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local w = Instance.new("WeldConstraint")
	w.Part0 = head
	w.Part1 = band
	w.Parent = band
	crown.Parent = parent
	return crown
end

local crownTier: { [Player]: number } = {}

local function crownScale(player: Player): number
	return 1 + (growth(player) - 1) * 0.35 -- up to 1.7x at max growth
end

-- A golden light pillar that follows the richest player: visible from anywhere on the map.
local function putPillar(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or root:FindFirstChild("RichPillar") then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "RichPillarBottom"
	a0.Position = Vector3.new(0, 4, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "RichPillarTop"
	a1.Position = Vector3.new(0, R.PillarHeight, 0)
	a1.Parent = root
	local beam = Instance.new("Beam")
	beam.Name = "RichPillar"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 5
	beam.Width1 = 5
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 215, 60))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0.85),
	})
	beam.Parent = root
end

local function putCrown(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not character or not head or not head:IsA("BasePart") or character:FindFirstChild("Crown") then
		return
	end
	Richest.attachCrown(head, character, crownScale(player))
	putPillar(character)
	crownTier[player] = math.floor(growth(player) * 4)
end

local function removeCrown(player: Player)
	crownTier[player] = nil
	local character = player.Character
	local crown = character and character:FindFirstChild("Crown")
	if crown then
		crown:Destroy()
	end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		for _, name in { "RichPillar", "RichPillarBottom", "RichPillarTop" } do
			local x = root:FindFirstChild(name)
			if x then
				x:Destroy()
			end
		end
	end
end

-- The richest base's sign turns gold and shows what it earns: everyone knows where the money is.
local function baseSign(player: Player, isRichest: boolean)
	local s = State.get(player)
	if not s or not s.base then
		return
	end
	local label = s.base.signLabel :: TextLabel
	if isRichest then
		label.Text = "👑 "
			.. string.upper(player.DisplayName)
			.. " • "
			.. Format.cash(Bases.incomePerSecond(player))
			.. "/s"
		label.TextColor3 = Color3.fromRGB(255, 215, 60)
	else
		label.Text = string.upper(player.DisplayName) .. "'S BASE"
		label.TextColor3 = Color3.new(1, 1, 1)
	end
end

-- Bigger crown + wider beam as the reign goes on.
local function growCrown(player: Player)
	local tier = math.floor(growth(player) * 4)
	if crownTier[player] ~= tier then
		removeCrown(player)
		putCrown(player)
	end
	local s = State.get(player)
	if s and s.base then
		local w = 10 * (1 + (growth(player) - 1) * 0.6)
		s.base.beam.Size = Vector3.new(s.base.beam.Size.X, w, w)
	end
end

local function setWanted(player: Player?)
	if not wanted then
		return
	end
	for i, img in wanted.Image do
		if player then
			img.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=420&h=420"
			wanted.Title[i].Text = "👑 WANTED 👑"
			wanted.Name[i].Text = string.upper(player.DisplayName)
			local g = growth(player)
			wanted.Bounty[i].Text = "BOUNTY "
				.. Format.cash(bounty(player))
				.. (if g >= 1.1 then string.format("  (x%.1f)", g) else "")
		else
			img.Image = ""
			wanted.Title[i].Text = "👑 NO KING 👑"
			wanted.Name[i].Text = "BE THE RICHEST"
			wanted.Bounty[i].Text = "TO WEAR THE CROWN"
		end
	end
end

local function saveReign(player: Player, seconds: number)
	local s = State.get(player)
	if not s or seconds < 1 then
		return
	end
	s.data.Stats.ReignSeconds += seconds
	if seconds > s.data.Stats.BestReign then
		s.data.Stats.BestReign = seconds
	end
	local store = reignStore
	if store then
		local best = math.floor(s.data.Stats.BestReign)
		task.spawn(function()
			pcall(function()
				store:UpdateAsync(tostring(player.UserId), function(old: number?)
					return if old and old >= best then nil else best
				end)
			end)
		end)
	end
end

local function dethrone(reason: string?)
	local old = current
	if not old then
		return
	end
	current = nil
	local s = State.get(old)
	if s then
		saveReign(old, os.clock() - s.reignStart)
		s.isRichest = false
		if s.base then
			s.base.beam.Transparency = 1
			s.base.beam.Size = Vector3.new(s.base.beam.Size.X, 10, 10)
		end
		Bases.changed(old)
		baseSign(old, false)
	end
	old:SetAttribute("Richest", nil)
	removeCrown(old)
	workspace:SetAttribute("RichestUserId", nil)
	workspace:SetAttribute("RichestName", nil)
	workspace:SetAttribute("RichestGrowth", nil)
	if old.Parent == Players then
		Net.fire(old, Remotes.Names.Crown, false)
	end
	if reason then
		Net.announce(reason, { 255, 120, 60 })
	end
	setWanted(nil)
end

local function crown(player: Player)
	local s = State.get(player)
	if not s then
		return
	end
	local previous = current
	if previous then
		dethrone()
	end
	current = player
	s.isRichest = true
	s.reignStart = os.clock()
	player:SetAttribute("Richest", true)
	workspace:SetAttribute("RichestUserId", player.UserId)
	workspace:SetAttribute("RichestName", player.DisplayName)
	putCrown(player)
	if s.base then
		s.base.beam.Transparency = 0.45
		-- a richest can't hide behind a lock
		if not R.CanLock then
			Bases.unlock(s.base)
		end
	end
	Bases.changed(player)
	Net.fire(player, Remotes.Names.Crown, true)
	if previous then
		Net.announce(
			"👑 " .. player.DisplayName .. " DETHRONED " .. previous.DisplayName .. "! 👑",
			{ 255, 215, 60 },
			"Crown"
		)
	else
		Net.announce(
			"👑 " .. player.DisplayName .. " is now THE RICHEST! Rob them for a bounty! 👑",
			{ 255, 215, 60 },
			"Crown"
		)
	end
	setWanted(player)
end

local function evaluate()
	local players = 0
	local best: Player? = nil
	local bestWorth = -1
	for player in State.all() do
		players += 1
		local w = Bases.netWorth(player)
		player:SetAttribute("NetWorth", w)
		if w > bestWorth then
			best, bestWorth = player, w
		end
	end
	if players < R.MinPlayers then
		if current then
			dethrone()
		end
		return
	end
	if not best then
		return
	end
	if current and State.get(current) == nil then
		dethrone()
	end
	if current == nil then
		if bestWorth > 0 then
			crown(best)
		end
	elseif best ~= current then
		local cw = Bases.netWorth(current)
		if bestWorth > cw * R.Hysteresis then
			crown(best)
		end
	end
	if current then
		workspace:SetAttribute("RichestWorth", Bases.netWorth(current))
		workspace:SetAttribute("RichestBounty", bounty(current))
		workspace:SetAttribute("RichestGrowth", growth(current))
		growCrown(current)
		baseSign(current, true)
		setWanted(current)
	end
end

local function refreshBoard()
	local store = reignStore
	if not store then
		return
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, 10)
	end)
	if not ok or not pages then
		return
	end
	local entries = (pages :: any):GetCurrentPage()
	for i, line in reignLines do
		local e = entries[i]
		if e then
			local userId = tonumber(e.key) :: number
			local name = nameCache[userId]
			if not name then
				local okName, result = pcall(function()
					return Players:GetNameFromUserIdAsync(userId)
				end)
				name = if okName and result then result else "Player"
				if okName and result then
					nameCache[userId] = result
				end
			end
			line.Text = string.format("%d. %s — %s", i, name, Format.duration(e.value))
		else
			line.Text = ""
		end
	end
end

Richest.bounty = bounty
Richest.growth = growth
Richest.evaluate = function()
	evaluate()
end

function Richest.isRichest(player: Player): boolean
	return current == player
end

function Richest.onLeaving(player: Player)
	if current == player then
		dethrone("👑 The Richest left the server! The crown is up for grabs!")
	end
end

-- Respawned characters need their crown back.
function Richest.onCharacter(player: Player)
	if current == player then
		task.wait(0.3)
		putCrown(player)
	end
end

function Richest.start(worldInfo: any)
	wanted = worldInfo.wanted
	reignLines = worldInfo.reignLines
	setWanted(nil)
	Carry.bountyFor = function(victim: Player): number
		if current == victim then
			return bounty(victim)
		end
		return 0
	end
	Carry.onRobbedRichest = function(thief: Player, victim: Player, amount: number)
		Net.announce(
			string.format(
				"💥 %s ROBBED THE RICHEST (%s)! +%s BOUNTY 💥",
				thief.DisplayName,
				victim.DisplayName,
				Format.cash(amount)
			),
			{ 255, 80, 80 },
			"Bounty"
		)
		task.defer(evaluate)
	end
	task.spawn(function()
		while true do
			task.wait(R.CheckSeconds)
			local ok, err = pcall(evaluate)
			if not ok then
				warn("richest evaluate failed: " .. tostring(err))
			end
		end
	end)
	task.spawn(function()
		while true do
			pcall(refreshBoard)
			task.wait(60)
		end
	end)
end

return Richest
