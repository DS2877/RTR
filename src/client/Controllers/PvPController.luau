--!strict
-- Day-time PvP on the client: Yard Brawl targeting (PUNCH with no wall in reach hits the nearest
-- player in front of you), knockback / knockouts / soap slips on your own character, loot drops on
-- the floor, raid beams (carry home / alarm / thief) and the Stash panel.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local PvP = require(Shared.Config.PvP)
local Finds = require(Shared.Config.Finds)
local Rarity = require(Shared.Config.Rarity)
local Tunnel = require(Shared.Tunnel)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local Client = script.Parent.Parent
local UI = require(Client.Util.UI)
local Panel = require(Client.Util.Panel)
local Sound = require(Client.Util.Sound)
local Shake = require(Client.Util.Shake)
local DigController = require(script.Parent.DigController)
local HUD = require(script.Parent.HUD)

local PvPController = {}

local player = Players.LocalPlayer
local folder: Folder
local target: Player? = nil
local targetGlow: Highlight? = nil
local lastBrawl = 0

local function root(p: Player?): BasePart?
	local c = (p or player).Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function isDay(): boolean
	return ReplicatedStorage:GetAttribute("Phase") == "Day"
end

-- Same safe zones as the server (Brawl.isSafe), from tagged parts.
local function isSafe(pos: Vector3): boolean
	if Tunnel.cellAt(pos) then
		return true
	end
	for _, s in CollectionService:GetTagged("Shop") do
		if ((s :: BasePart).Position - pos).Magnitude <= PvP.SafeRadiusShop then
			return true
		end
	end
	for _, s in CollectionService:GetTagged("GymStation") do
		if ((s :: BasePart).Position - pos).Magnitude <= PvP.SafeRadiusGym then
			return true
		end
	end
	for _, s in CollectionService:GetTagged("Dump") do
		if ((s :: BasePart).Position - pos).Magnitude <= PvP.SafeRadiusDump then
			return true
		end
	end
	return false
end

local function findTarget(): Player?
	local me = root()
	local cam = workspace.CurrentCamera
	if not me or not cam or not isDay() then
		return nil
	end
	local best, bestScore = nil, math.huge
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local r = root(other)
			if r then
				local d = (r.Position - me.Position).Magnitude
				local carrier = other:GetAttribute("Carrying") == true
				local ok = carrier
					or (
						not isSafe(r.Position)
						and not isSafe(me.Position)
						and other:GetAttribute("Protected") ~= true
					)
				if ok and d <= PvP.PunchRange then
					local dir = (r.Position - me.Position).Unit
					local facing = dir:Dot(cam.CFrame.LookVector)
					local score = d - facing * 4
					if facing > -0.2 and score < bestScore then
						best, bestScore = other, score
					end
				end
			end
		end
	end
	return best
end

local function brawlPunch(): boolean
	local t = target
	local now = os.clock()
	if not t or now - lastBrawl < PvP.PunchCooldown then
		return false
	end
	lastBrawl = now
	Remotes.get(Remotes.Names.Brawl):FireServer(t.UserId)
	Sound.play("Punch", 0.7, 0.9)
	return true
end

-- ===== being hit =====

local stunToken = 0
local function dizzy(seconds: number, spin: boolean)
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local r = root()
	if not h or not r then
		return
	end
	h.PlatformStand = true
	stunToken += 1
	local mine = stunToken
	if spin then
		r.AssemblyAngularVelocity = Vector3.new(math.random() * 8 - 4, 10, math.random() * 8 - 4)
	end
	local stars = Instance.new("BillboardGui")
	stars.Size = UDim2.fromOffset(120, 40)
	stars.StudsOffset = Vector3.new(0, 3.2, 0)
	stars.AlwaysOnTop = true
	stars.Adornee = r
	local l = UI.bigText({ Size = UDim2.fromScale(1, 1), Text = "💫 ⭐ 💫", Parent = stars })
	local _ = l
	stars.Parent = folder
	task.delay(seconds, function()
		stars:Destroy()
		-- only the latest stun gets you up (a knockout right after a trap keeps you down)
		if h.Parent and stunToken == mine then
			h.PlatformStand = false
			h:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

-- ===== drops on the floor =====

local dropModels: { [number]: Model } = {}
local function setDrops(list: { { number } })
	local seen = {}
	for _, d in list do
		local id = d[1]
		seen[id] = true
		if not dropModels[id] then
			local m = Instance.new("Model")
			m.Name = "Drop"
			local pos = Vector3.new(d[2], d[3], d[4])
			local n = math.clamp(math.ceil(d[5] / 3), 1, 6)
			for i = 1, n do
				local p = Instance.new("Part")
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.Size = Vector3.new(0.8, 0.6, 0.8)
				p.Material = Enum.Material.Slate
				p.Color = Color3.fromRGB(150, 140, 125)
				p.CFrame = CFrame.new(pos + Vector3.new(math.cos(i) * 1.2, -2.2, math.sin(i) * 1.2))
				p.Parent = m
			end
			if d[6] > 0 then
				local gem = Instance.new("Part")
				gem.Anchored = true
				gem.CanCollide = false
				gem.CanQuery = false
				gem.Size = Vector3.new(1, 1, 1)
				gem.Material = Enum.Material.Neon
				gem.Color = Color3.fromRGB(255, 220, 80)
				gem.CFrame = CFrame.new(pos + Vector3.new(0, -1, 0)) * CFrame.Angles(0.6, 0.6, 0)
				gem.Parent = m
				local light = Instance.new("PointLight")
				light.Color = gem.Color
				light.Range = 10
				light.Parent = gem
			end
			m.Parent = folder
			dropModels[id] = m
		end
	end
	for id, m in dropModels do
		if not seen[id] then
			m:Destroy()
			dropModels[id] = nil
		end
	end
end

-- ===== raid beams =====

local beam: Beam? = nil
local beamHolder: BasePart? = nil
local beamA0: Attachment? = nil
local beamTarget: () -> Vector3? = function()
	return nil
end
local beamUntil = 0

local function setBeam(color: Color3, seconds: number, getTarget: () -> Vector3?)
	beamTarget = getTarget
	beamUntil = os.clock() + seconds
	local r = root()
	if not r then
		return
	end
	if not beam or not beam.Parent or beam.Parent ~= r then
		-- the old set (a previous character's) goes first: no stray holders / attachments pile up
		if beam then
			beam:Destroy()
		end
		if beamA0 then
			beamA0:Destroy()
		end
		if beamHolder then
			beamHolder:Destroy()
		end
		local a0 = Instance.new("Attachment")
		a0.Parent = r
		local holder = Instance.new("Part")
		holder.Name = "RaidBeamTarget"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.Transparency = 1
		holder.Size = Vector3.one
		holder.Parent = folder
		local a1 = Instance.new("Attachment")
		a1.Parent = holder
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Width0 = 1
		b.Width1 = 1
		b.FaceCamera = true
		b.LightEmission = 1
		b.Segments = 16
		b.Parent = r
		beam = b
		beamA0 = a0
		beamHolder = holder
	end
	(beam :: Beam).Color = ColorSequence.new(color)
end

-- ===== stash panel =====

local stash: { string } = {}
local stashPanel: Panel.Panel

local function renderStash()
	for _, c in stashPanel.body:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	stashPanel.subtitle.Text = string.format("%d/%d", #stash, PvP.StashSize)
	local buttons = UI.new("Frame", {
		LayoutOrder = 0,
		Size = UDim2.new(1, -6, 0, 42),
		BackgroundTransparency = 1,
		Parent = stashPanel.body,
	})
	local put = Panel.button(
		{ Size = UDim2.new(0.49, 0, 1, 0) },
		Color3.fromRGB(90, 220, 110),
		Color3.fromRGB(30, 80, 40),
		"PUT ALL IN 📥"
	)
	put.Parent = buttons
	local take = Panel.button(
		{ Position = UDim2.fromScale(0.51, 0), Size = UDim2.new(0.49, 0, 1, 0) },
		Color3.fromRGB(255, 200, 70),
		Color3.fromRGB(110, 70, 0),
		"TAKE ALL 📤"
	)
	take.Parent = buttons
	local cmd = Remotes.get(Remotes.Names.StashCmd)
	put.Activated:Connect(function()
		Sound.play("Click")
		cmd:FireServer("put")
	end)
	take.Activated:Connect(function()
		Sound.play("Click")
		cmd:FireServer("take")
	end)
	Panel.text("note", "By day raiders can steal ONE find from here. Sell finds to keep them safe!", {
		LayoutOrder = 1,
		Size = UDim2.new(1, -6, 0, 26),
		Parent = stashPanel.body,
	})
	for i, id in stash do
		local f = Finds.ById[id]
		if f then
			local tier = Rarity.Tiers[f.rarity]
			local r = Panel.row(stashPanel.body, 1 + i, 36)
			Panel.text("title", f.emoji .. " " .. f.name, {
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(0.6, -12, 1, 0),
				TextSize = 14,
				Parent = r,
			})
			Panel.text("note", string.upper(f.rarity) .. " · " .. Format.noodles(f.value), {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 0),
				Size = UDim2.new(0.4, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = UI.rgb(tier.color):Lerp(Color3.new(1, 1, 1), 0.2),
				Parent = r,
			})
		end
	end
end

-- own chest: no hold, "Open"; other chests: "STEAL" (hold = their lock), hidden at night
local function updatePrompts()
	local day = isDay()
	for _, chest in CollectionService:GetTagged("Stash") do
		local prompt = chest:FindFirstChild("StashPrompt") :: ProximityPrompt?
		if prompt then
			local owner = chest:GetAttribute("Owner")
			local mine = owner == player.UserId
			prompt.ActionText = if mine then "Open Stash" else "STEAL"
			prompt.ObjectText = if mine then "Your Stash" else "Stash chest"
			if mine then
				prompt.HoldDuration = 0
			end
			prompt.Enabled = mine or (day and owner ~= nil and player:GetAttribute("Carrying") ~= true)
		end
	end
end

function PvPController.start()
	folder = Instance.new("Folder")
	folder.Name = "PvPFX"
	folder.Parent = workspace

	DigController.onEmptyPunch = brawlPunch

	Remotes.get(Remotes.Names.Knocked).OnClientEvent
		:Connect(function(impulse: Vector3, _stamina: number, out: boolean)
			local r = root()
			if r then
				r.AssemblyLinearVelocity = impulse
			end
			Shake.kick(if out then 0.9 else 0.45)
			Sound.play("Punch", 0.9, 0.6)
			if out then
				dizzy(2.2, true)
			end
		end)
	Remotes.get(Remotes.Names.Hit).OnClientEvent:Connect(function(_victim: number, out: boolean)
		Shake.kick(if out then 0.5 else 0.25)
		if out then
			HUD.toast("💥 KNOCKOUT!", "good")
		end
	end)
	Remotes.get(Remotes.Names.Slip).OnClientEvent:Connect(function(seconds: number)
		local r = root()
		if r then
			r.AssemblyLinearVelocity = r.CFrame.LookVector * 30 + Vector3.new(0, 12, 0)
		end
		Sound.play("Full", 0.4, 1.3)
		dizzy(seconds, true)
	end)
	Remotes.get(Remotes.Names.Drops).OnClientEvent:Connect(setDrops)

	Remotes.get(Remotes.Names.Raid).OnClientEvent
		:Connect(function(kind: string, text: string, userId: number?)
			HUD.toast(text, if kind == "home" then "good" elseif kind == "carry" then "cash" else "bad")
			if kind == "alarm" or kind == "stolen" then
				Sound.play("Siren", 0.5)
				local thief = if userId then Players:GetPlayerByUserId(userId) else nil
				setBeam(Color3.fromRGB(255, 70, 70), 25, function()
					local r = root(thief)
					return if r then r.Position else nil
				end)
			elseif kind == "carry" then
				Sound.play("Rare", 0.6)
				local cell = player:GetAttribute("Cell")
				setBeam(Color3.fromRGB(255, 220, 60), 120, function()
					if typeof(cell) ~= "number" or cell <= 0 then
						return nil
					end
					return Tunnel.frame(cell) * Vector3.new(0, 4, 10)
				end)
			elseif kind == "home" or kind == "dropped" then
				beamUntil = 0
				if kind == "home" then
					Sound.play("Zone", 0.6)
				end
			end
		end)

	stashPanel = Panel.new(
		"StashPanel",
		"📦 STASH",
		Color3.fromRGB(200, 140, 70),
		Color3.fromRGB(90, 50, 10),
		Vector2.new(560, 310)
	)
	UI.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = stashPanel.body }
	)
	stashPanel.onOpen = renderStash
	Remotes.get(Remotes.Names.Stash).OnClientEvent:Connect(function(list)
		stash = list
		if stashPanel.isOpen() then
			renderStash()
		end
	end)
	Remotes.get(Remotes.Names.OpenStash).OnClientEvent:Connect(function()
		stashPanel.setOpen(true)
	end)

	-- stamina bar above the hotbar
	local gui = UI.new(
		"ScreenGui",
		{ Name = "PvP", ResetOnSpawn = false, DisplayOrder = 2, Parent = player:WaitForChild("PlayerGui") }
	)
	local bar = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		-- just above the hotbar (58 px * scale + 8), under the ESCAPE / BRIBE pills
		Position = UDim2.new(0.5, 0, 1, -50),
		Size = UDim2.fromOffset(220, 12),
		BackgroundColor3 = Color3.fromRGB(40, 40, 50),
		Visible = false,
		Parent = gui,
	}, { UI.corner(6), UI.stroke(UI.INK, 1.5) })
	UI.scaleObject(bar)
	local function placeBar()
		bar.Position = UDim2.new(0.5, 0, 1, -(8 + 58 * UI.screenScale() + 6))
	end
	placeBar()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(placeBar)
	end
	local fill = UI.new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(90, 220, 110), Parent = bar },
		{ UI.corner(6) }
	)
	UI.slimText({
		Position = UDim2.new(0, 0, 0, -16),
		Size = UDim2.new(1, 0, 0, 14),
		Text = "STAMINA",
		Parent = bar,
	})
	local topDog = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 32),
		Size = UDim2.fromOffset(200, 20),
		Text = "🐶 YOU ARE TOP DOG",
		TextColor3 = Color3.fromRGB(255, 210, 60),
		Visible = false,
		Parent = gui,
	})
	UI.scaleObject(topDog)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.15 then
			acc = 0
			-- brawl target
			local t = findTarget()
			if DigController.hasAim() then
				t = nil
			end
			if t ~= target then
				target = t
				if targetGlow then
					targetGlow:Destroy()
					targetGlow = nil
				end
				if t and t.Character then
					local h = Instance.new("Highlight")
					h.FillColor = Color3.fromRGB(255, 60, 60)
					h.FillTransparency = 0.75
					h.OutlineColor = Color3.fromRGB(255, 80, 80)
					h.Adornee = t.Character
					h.Parent = folder
					targetGlow = h
				end
			end
			updatePrompts()
			local st = player:GetAttribute("Stamina")
			local stamina = if typeof(st) == "number" then st else PvP.MaxStamina
			bar.Visible = stamina < PvP.MaxStamina - 0.5
			fill.Size = UDim2.fromScale(math.clamp(stamina / PvP.MaxStamina, 0, 1), 1)
			topDog.Visible = false -- shown in the HUD's boost line instead
		end
		-- raid beam target follows
		if beam then
			local pos = if os.clock() < beamUntil then beamTarget() else nil
			beam.Enabled = pos ~= nil
			local holder = beamHolder
			if pos and holder then
				holder.Position = pos
			end
		end
	end)
end

return PvPController
