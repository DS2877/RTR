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
local Sound = require(script.Parent.Parent.Util.Sound)
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

-- Steal prompts only on other bases, Sell only on yours. Quick Hands pass: steal instantly.
local function setupPrompt(pp: ProximityPrompt)
	local function apply()
		if pp.Name == "Steal" then
			if pp:GetAttribute("BaseHold") == nil then
				pp:SetAttribute("BaseHold", pp.HoldDuration)
			end
			pp.HoldDuration = if player:GetAttribute("Pass_QuickHands")
				then 0
				else pp:GetAttribute("BaseHold") or 0
		end
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
		elseif pp.Name == "Appraise" and not mine then
			pp.Enabled = false -- only the owner opens their crates
		end
	end
	task.defer(apply)
	if pp.Name == "Appraise" then
		-- the server flips Enabled when a crate gets ready: hide it again on other bases
		pp:GetPropertyChangedSignal("Enabled"):Connect(function()
			if pp.Enabled then
				task.defer(apply)
			end
		end)
	end
end

local function zoneBanner()
	local gui = HUD.gui()
	-- a dark see-through strip across the top with the street's name, shown while you're in it
	local holder = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.fromOffset(620, 54),
		BackgroundColor3 = Color3.fromRGB(10, 10, 15),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	}, {
		UI.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.18, 0),
				NumberSequenceKeypoint.new(0.82, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	UI.scaleObject(holder)
	local banner = UI.bigText({
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 1, -8),
		Text = "",
		Parent = holder,
	}, Color3.fromRGB(20, 20, 28), 3)
	local function nameColor(def: any): Color3
		-- the brighter of the zone's two colors, a touch lighter so it reads on the dark strip
		local a, b = UI.rgb(def.trim), UI.rgb(def.color)
		local function lum(c: Color3): number
			return 0.3 * c.R + 0.59 * c.G + 0.11 * c.B
		end
		return (if lum(a) > 0.4 then a else b):Lerp(Color3.new(1, 1, 1), 0.15)
	end
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
					if floor then
						-- inside this zone's floor (zones are long boxes along the corridor)
						local l = floor.CFrame:PointToObjectSpace(r.Position)
						if math.abs(l.X) <= floor.Size.X / 2 and math.abs(l.Z) <= floor.Size.Z / 2 then
							found = v:GetAttribute("VaultIndex")
						end
					end
				end
			end
			-- hidden while carrying: the top of the screen belongs to RUN!!
			holder.Visible = found ~= nil and player:GetAttribute("Carrying") == nil
			if found ~= current then
				current = found
				if found then
					local def = Vaults[found]
					local need = Progression.speedToOutrun(found)
					local mine = Progression.walkSpeed(player:GetAttribute("SpeedPoints") or 0)
					banner.Text = def.name .. " " .. def.emoji
					banner.TextColor3 = nameColor(def)
					UI.bump(holder, 0.12)
					if mine < need then
						HUD.toast(
							"⚠️ " .. def.name .. " is faster than you! Train on your treadmill.",
							"bad"
						)
					end
				end
			end
		end
	end)
end

-- A number that pops out at a spot in the world and floats up (treadmill, income).
local function worldPopup(at: Vector3, text: string, color: Color3, size: number?)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(at)
	anchor.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(170, 40 * (size or 1))
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 90
	bb.Adornee = anchor
	bb.Parent = anchor
	local l = UI.bigText({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color,
		Parent = bb,
	}, Color3.fromRGB(20, 20, 28), 2.5)
	UI.tween(bb, 1.1, { StudsOffset = Vector3.new(math.random(-15, 15) / 10, 4.5, 0) }, Enum.EasingStyle.Quad)
	task.delay(0.6, function()
		UI.tween(l, 0.5, { TextTransparency = 1 })
		local st = l:FindFirstChildOfClass("UIStroke")
		if st then
			UI.tween(st, 0.5, { Transparency = 1 })
		end
	end)
	task.delay(1.2, function()
		anchor:Destroy()
	end)
end

local function treadmillPopups()
	-- "+29,000"-style numbers spraying out of you while you train
	Remotes.get(Remotes.Names.SpeedTick).OnClientEvent:Connect(function(amount: number)
		local r = rootPart()
		if r then
			local side = r.CFrame.RightVector * (math.random(-20, 20) / 10)
			worldPopup(
				r.Position + Vector3.new(0, 2.5, 0) + side,
				"+" .. Format.number(math.max(1, math.floor(amount))) .. " ⚡",
				Color3.fromRGB(110, 210, 255)
			)
		end
	end)
	-- income floating up out of every item on your plot ("+$570" every few seconds)
	task.spawn(function()
		while true do
			task.wait(3)
			local base = myBase()
			local r = rootPart()
			if base and r and (base:GetPivot().Position - r.Position).Magnitude < 120 then
				-- your multipliers (passes, richest, events, friends) = real income / base income
				local raw = 0
				for _, m in base:GetChildren() do
					local id = m:IsA("Model") and m:GetAttribute("ItemId")
					if id then
						raw += Progression.income(id, m:GetAttribute("Mutation") or "None")
					end
				end
				local mult = if raw > 0 then (player:GetAttribute("CashPerSec") or raw) / raw else 1
				for _, m in base:GetChildren() do
					local id = m:IsA("Model") and m:GetAttribute("ItemId")
					if id and m.PrimaryPart then
						local income = Progression.income(id, m:GetAttribute("Mutation") or "None") * 3 * mult
						worldPopup(
							m.PrimaryPart.Position + Vector3.new(0, 2, 0),
							"+" .. Format.cash(income),
							Color3.fromRGB(255, 230, 110),
							0.8
						)
					end
				end
			end
		end
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
	-- one compact objective pill (bottom center) + the golden beam to the target
	local pill = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -84), -- above the hotbar
		Size = UDim2.fromOffset(520, 40),
		BackgroundTransparency = 1, -- outlined text only, like the rest of the HUD
		Visible = false,
		Parent = gui,
	})
	UI.scaleObject(pill)
	local hint = UI.bigText({
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 1, -12),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 240, 160),
		Parent = pill,
	}, Color3.fromRGB(20, 20, 28), 2)
	local lastText = ""

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
			local learning = not player:GetAttribute("TutorialDone")
			local steals = player:GetAttribute("Steals") or 0
			local function vaultTarget(i: number): Vector3?
				local v = workspace:FindFirstChild("Vaults")
				local vm = v and v:FindFirstChild("Vault_" .. Vaults[i].id)
				local floor = vm and vm:FindFirstChild("Floor") :: BasePart?
				return floor and floor.Position
			end
			local function appraiserTarget(): Vector3?
				local a = base and base:FindFirstChild("Appraiser")
				local h = a and a:FindFirstChild("Head") :: BasePart?
				return if h then h.Position else nil
			end
			local ready = player:GetAttribute("CratesReady") or 0
			local crates = player:GetAttribute("Crates") or 0
			if player:GetAttribute("Carrying") then
				text = "" -- RUN!! already says it; the golden beam still points home
				local floor = base and base:FindFirstChild("Floor") :: BasePart?
				target = floor and floor.Position
			elseif base then
				-- best zone you can outrun
				local best = 0
				for i = 1, #Vaults do
					if speed * Economy.CarrySlowdown.Common > Vaults[i].guardSpeed then
						best = i
					end
				end
				local income = player:GetAttribute("CashPerSec") or 0
				if learning and pts < 30 and steals == 0 then
					text = "STEP 1/5  •  ⚡ Stand on your treadmill"
					local belt = base:FindFirstChild("Treadmill") :: BasePart?
					target = belt and belt.Position
				elseif learning and steals == 0 then
					local v = math.max(1, best)
					text = "STEP 2/5  •  📦 STEAL a crate from " .. Vaults[v].name
					target = vaultTarget(v)
				elseif ready > 0 then
					text = (if learning then "STEP 4/5  •  " else "") .. "📦 Your crate is ready! Open it"
					target = appraiserTarget()
				elseif learning and crates > 0 then
					text = "STEP 4/5  •  🧐 The appraiser is opening your crate..."
					target = appraiserTarget()
				elseif learning and (player:GetAttribute("Collected") or 0) == 0 then
					text = "STEP 5/5  •  💵 Step on your green COLLECT pad"
					local pad = base:FindFirstChild("CollectPad") :: BasePart?
					target = pad and pad.Position
				elseif pts < 30 then
					text = "⚡ Train on your treadmill to get faster"
					local belt = base:FindFirstChild("Treadmill") :: BasePart?
					target = belt and belt.Position
				elseif best >= 1 and income < Vaults[best].baseIncome * 3 then
					text = "📦 Next target: " .. Vaults[best].name
					target = vaultTarget(best)
				end
			end
			hint.Text = text
			pill.Visible = text ~= ""
			if text ~= lastText and text ~= "" then
				UI.bump(pill, 0.12)
				if lastText ~= "" and learning then
					Sound.play("Upgrade", 0.4)
				end
			end
			lastText = text
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
	player:GetAttributeChangedSignal("Pass_QuickHands"):Connect(function()
		for _, d in workspace:GetDescendants() do
			if d:IsA("ProximityPrompt") and d.Name == "Steal" then
				setupPrompt(d)
			end
		end
	end)
	zoneBanner()
	treadmillPopups()
	rainbow()
	ownLaser()
	guide()
end

return WorldFX
