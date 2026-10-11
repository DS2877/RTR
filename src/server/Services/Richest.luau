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
pcall(function()
	reignStore = DataStoreService:GetOrderedDataStore("RTR_LongestReign_v1")
end)

local function bounty(victim: Player): number
	return math.max(R.MinBounty, math.floor(Bases.incomePerSecond(victim) * R.BountySeconds))
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
	band.Material = Enum.Material.Foil
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
		spike.Material = Enum.Material.Foil
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
		gem.CFrame = spike.CFrame * CFrame.new(0, 0.5, 0)
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

local function putCrown(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not character or not head or not head:IsA("BasePart") or character:FindFirstChild("Crown") then
		return
	end
	local crown = crownModel()
	local band = crown.PrimaryPart :: BasePart
	-- cylinder axis is X: stand it up
	crown:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local w = Instance.new("WeldConstraint")
	w.Part0 = head
	w.Part1 = band
	w.Parent = band
	crown.Parent = character
end

local function removeCrown(player: Player)
	local character = player.Character
	local crown = character and character:FindFirstChild("Crown")
	if crown then
		crown:Destroy()
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
			wanted.Bounty[i].Text = "BOUNTY " .. Format.cash(bounty(player))
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
		end
		Bases.changed(old)
	end
	old:SetAttribute("Richest", nil)
	removeCrown(old)
	workspace:SetAttribute("RichestUserId", nil)
	workspace:SetAttribute("RichestName", nil)
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
		Net.announce("👑 " .. player.DisplayName .. " DETHRONED " .. previous.DisplayName .. "! 👑")
	else
		Net.announce("👑 " .. player.DisplayName .. " is now THE RICHEST! Rob them for a bounty! 👑")
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
			local name = "Player"
			local okName, result = pcall(function()
				return Players:GetNameFromUserIdAsync(tonumber(e.key) :: number)
			end)
			if okName and result then
				name = result
			end
			line.Text = string.format("%d. %s — %s", i, name, Format.duration(e.value))
		else
			line.Text = ""
		end
	end
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
			{ 255, 80, 80 }
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
