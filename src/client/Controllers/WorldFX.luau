--!strict
-- World-side client work: zone banners on Rich Street, which prompts you see (Steal on others'
-- bases, Sell on yours), walking through your own lock laser, treadmill "+speed" popups,
-- rainbow items, and the guide hint + arrow for new players.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Vaults = require(Shared.Config.Vaults)
local Progression = require(Shared.Progression)
local Economy = require(Shared.Config.Economy)

local UI = require(script.Parent.Parent.Util.UI)
local HUD = require(script.Parent.HUD)

local WorldFX = {}

local player = Players.LocalPlayer

local function myBase(): Model?
	local bases = workspace:FindFirstChild("Bases")
	local b = bases and bases:FindFirstChild("Base_" .. tostring(player:GetAttribute("BaseId")))
	return if b and b:IsA("Model") then b else nil
end

local function rootPart(): BasePart?
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

-- Steal prompts only on other bases, Sell only on yours.
local function setupPrompt(pp: ProximityPrompt)
	local function apply()
		local basesFolder = workspace:FindFirstChild("Bases")
		local base: Instance? = pp.Parent
		while base and base.Parent ~= basesFolder do
			base = base.Parent
		end
		if not base or not basesFolder then
			return -- vault loot, signs, machines: unchanged
		end
		local mine = base:GetAttribute("OwnerUserId") == player.UserId
		if pp.Name == "Steal" then
			pp.Enabled = not mine
		elseif pp.Name == "Sell" or pp.Name == "Upgrade" then
			pp.Enabled = mine
		end
	end
	task.defer(apply)
end

local function zoneBanner()
	local gui = HUD.gui()
	local banner = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(520, 52),
		Text = "",
		Visible = false,
		Parent = gui,
	}, Color3.fromRGB(20, 20, 28), 3)
	local current: number? = nil
	task.spawn(function()
		while true do
			task.wait(0.25)
			local r = rootPart()
			local vaultsFolder = workspace:FindFirstChild("Vaults")
			local found: number? = nil
			if r and vaultsFolder then
				for _, v in vaultsFolder:GetChildren() do
					local floor = v:FindFirstChild("Floor") :: BasePart?
					if floor and (floor.Position - r.Position).Magnitude < 60 then
						found = v:GetAttribute("VaultIndex")
					end
				end
			end
			if found ~= current then
				current = found
				if found then
					local def = Vaults[found]
					local need = Progression.speedToOutrun(found)
					local mine = Progression.walkSpeed(player:GetAttribute("SpeedPoints") or 0)
					banner.Text = def.emoji .. " " .. def.name
					banner.TextColor3 = UI.rgb(def.trim)
					banner.Visible = true
					UI.bump(banner, 0.3)
					if mine < need then
						HUD.toast("⚠️ Guards here are faster than you! Train on your treadmill.", "bad")
					end
					local stamp = os.clock()
					banner:SetAttribute("Stamp", stamp)
					task.delay(2.5, function()
						if banner:GetAttribute("Stamp") == stamp then
							banner.Visible = false
						end
					end)
				end
			end
		end
	end)
end

local function treadmillPopups()
	local gui = HUD.gui()
	Remotes.get(Remotes.Names.SpeedTick).OnClientEvent:Connect(function(amount: number)
		local l = UI.bigText({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.2, 0.55),
			Size = UDim2.fromOffset(200, 34),
			Text = "+" .. Format.number(math.max(1, math.floor(amount))) .. " ⚡",
			TextColor3 = Color3.fromRGB(110, 210, 255),
			Parent = gui,
		})
		UI.tween(l, 0.9, { Position = l.Position - UDim2.fromOffset(0, 80), TextTransparency = 1 })
		task.delay(0.95, function()
			l:Destroy()
		end)
	end)
end

local function rainbow()
	RunService.Heartbeat:Connect(function()
		local hue = (os.clock() * 0.25) % 1
		for _, p in CollectionService:GetTagged("Rainbow") do
			if p:IsA("BasePart") then
				p.Color = Color3.fromHSV(hue, 0.8, 1)
			end
		end
	end)
end

-- Your own laser never blocks you (collision is decided by your own client for your character).
local function ownLaser()
	local function apply()
		local base = myBase()
		local laser = base and base:FindFirstChild("Laser") :: BasePart?
		if laser then
			laser.CanCollide = false
			laser.LocalTransparencyModifier = 0.5
		end
	end
	task.spawn(function()
		while true do
			apply()
			task.wait(0.2)
		end
	end)
end

-- Guide: one short goal at a time + a beam arrow to it.
local function guide()
	local gui = HUD.gui()
	local hint = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(560, 32),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 240, 160),
		Parent = gui,
	}, Color3.fromRGB(20, 20, 28), 2.5)

	local a0 = Instance.new("Attachment")
	local a1 = Instance.new("Attachment")
	local targetPart = Instance.new("Part")
	targetPart.Anchored = true
	targetPart.CanCollide = false
	targetPart.CanQuery = false
	targetPart.CanTouch = false
	targetPart.Transparency = 1
	targetPart.Size = Vector3.new(1, 1, 1)
	targetPart.Parent = workspace
	a1.Parent = targetPart
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Static
	beam.TextureSpeed = 2
	beam.TextureLength = 3
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 230, 80))
	beam.LightEmission = 1
	beam.Transparency = NumberSequence.new(0.2)
	beam.Parent = targetPart

	task.spawn(function()
		while true do
			task.wait(0.3)
			local r = rootPart()
			if r and a0.Parent ~= r then
				a0.Parent = r
			end
			local base = myBase()
			local text = ""
			local target: Vector3? = nil
			local pts = player:GetAttribute("SpeedPoints") or 0
			local speed = Progression.walkSpeed(pts)
			if player:GetAttribute("Carrying") then
				text = "🏃 Bring it to YOUR base! Guards will chase you!"
				local floor = base and base:FindFirstChild("Floor") :: BasePart?
				target = floor and floor.Position
			elseif base then
				-- best vault you can outrun
				local best = 0
				for i = 1, #Vaults do
					if speed * Economy.CarrySlowdown.Common > Vaults[i].guardSpeed then
						best = i
					end
				end
				local slots = player:GetAttribute("CashPerSec") or 0
				if pts < 30 then
					text = "⚡ Run on your treadmill to get faster!"
					local belt = base:FindFirstChild("Treadmill") :: BasePart?
					target = belt and belt.Position
				elseif best >= 1 and slots < Vaults[math.max(1, best)].baseIncome * 3 then
					text = "💰 Steal from " .. Vaults[best].name .. "!"
					local v = workspace:FindFirstChild("Vaults")
					local vm = v and v:FindFirstChild("Vault_" .. Vaults[best].id)
					local floor = vm and vm:FindFirstChild("Floor") :: BasePart?
					target = floor and floor.Position
				else
					text = ""
				end
			end
			hint.Text = text
			hint.Visible = text ~= ""
			if target then
				targetPart.Position = target + Vector3.new(0, 3, 0)
				beam.Enabled = true
			else
				beam.Enabled = false
			end
		end
	end)
end

function WorldFX.start()
	for _, d in workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			setupPrompt(d)
		end
	end
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			setupPrompt(d)
		end
	end)
	-- base ownership changes (players join/leave): re-apply on every base prompt
	local bases = workspace:WaitForChild("Bases")
	for _, b in bases:GetChildren() do
		b:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			for _, d in b:GetDescendants() do
				if d:IsA("ProximityPrompt") then
					setupPrompt(d)
				end
			end
		end)
	end
	zoneBanner()
	treadmillPopups()
	rainbow()
	ownLaser()
	guide()
end

return WorldFX
