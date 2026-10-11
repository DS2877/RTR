--!strict
-- The heist moment: red vignette + "RUN!!" + Drop button while carrying, "SAFE ZONE" when you
-- reach home, a big reveal when loot lands on your plot, and the SLAP button when a thief is near.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Rarity = require(Shared.Config.Rarity)
local Mutations = require(Shared.Config.Mutations)
local Economy = require(Shared.Config.Economy)

local UI = require(script.Parent.Parent.Util.UI)
local Sound = require(script.Parent.Parent.Util.Sound)
local Music = require(script.Parent.Parent.Util.Music)
local Shake = require(script.Parent.Parent.Util.Shake)
local HUD = require(script.Parent.HUD)

local CarryFX = {}

local player = Players.LocalPlayer

function CarryFX.start()
	local gui: ScreenGui = UI.new("ScreenGui", {
		Name = "Heist",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 2,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- red edge vignette (full screen, not scaled)
	local vignette = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 0, 30),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, {
		UI.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(0.22, 1),
				NumberSequenceKeypoint.new(0.78, 1),
				NumberSequenceKeypoint.new(1, 0.35),
			}),
		}),
	})

	local layer = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local holder = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(300, 90),
		BackgroundTransparency = 1,
		Parent = layer,
	})
	UI.scaleObject(holder)
	local run = UI.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(60, 0, 10),
		Text = "RUN!!",
		Font = Enum.Font.LuckiestGuy,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = holder,
	}, { UI.corner(20), UI.stroke(Color3.fromRGB(255, 60, 70), 4), UI.textStroke(Color3.new(0, 0, 0), 3) })
	local carryName = UI.bigText({
		Position = UDim2.new(0, -100, 1, 4),
		Size = UDim2.new(1, 200, 0, 28),
		Text = "",
		Visible = false,
		Parent = holder,
	})

	local dropHolder = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -200, 1, -30),
		Size = UDim2.fromOffset(110, 70),
		BackgroundTransparency = 1,
		Parent = layer,
	})
	UI.scaleObject(dropHolder)
	local drop: TextButton = UI.new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(200, 40, 50),
		Text = "",
		Visible = false,
		Parent = dropHolder,
	}, { UI.corner(16), UI.stroke(Color3.fromRGB(90, 10, 20), 3) })
	UI.bigText({
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		Text = "🗑 DROP",
		Parent = drop,
	})
	drop.Activated:Connect(function()
		Remotes.get(Remotes.Names.Drop):FireServer()
	end)

	local slapHolder = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -200, 1, -120),
		Size = UDim2.fromOffset(130, 90),
		BackgroundTransparency = 1,
		Parent = layer,
	})
	UI.scaleObject(slapHolder)
	local slap: TextButton = UI.new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 160, 40),
		Text = "",
		Visible = false,
		Parent = slapHolder,
	}, { UI.corner(20), UI.stroke(Color3.fromRGB(120, 60, 0), 4) })
	UI.bigText({
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		Text = "👋 SLAP!",
		Parent = slap,
	})
	local slapTarget: Player? = nil
	slap.Activated:Connect(function()
		if slapTarget then
			Remotes.get(Remotes.Names.Slap):FireServer(slapTarget.UserId)
			UI.bump(slap, 0.25)
			Sound.play("Slap", 0.8)
			Shake.kick(0.3)
		end
	end)

	local function myBase(): Instance?
		local bases = workspace:FindFirstChild("Bases")
		return bases and bases:FindFirstChild("Base_" .. tostring(player:GetAttribute("BaseId")))
	end

	local function refresh()
		local carrying = player:GetAttribute("Carrying")
		local on = carrying ~= nil
		vignette.Visible = on
		run.Visible = on
		drop.Visible = on
		carryName.Visible = on
		if on then
			local rarity = player:GetAttribute("CarryRarity") or "Common"
			local mut = player:GetAttribute("CarryMut") or "None"
			local tier = Rarity.Tiers[rarity]
			carryName.Text = (if mut ~= "None" then mut .. " " else "")
				.. tostring(carrying)
				.. " ("
				.. rarity
				.. ")"
			carryName.TextColor3 = if tier then UI.rgb(tier.color) else Color3.new(1, 1, 1)
			Sound.play("Grab", 0.6)
			Sound.play("Whoosh", 0.5)
			Shake.kick(0.45)
		end
		Shake.fov(if on then 9 else 0)
		Music.setChase(on)
	end
	player:GetAttributeChangedSignal("Carrying"):Connect(refresh)
	refresh()

	-- pulsing RUN!! + SAFE ZONE text + slap target scan
	local t0 = os.clock()
	RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if run.Visible then
			local pulse = 0.5 + 0.5 * math.sin(t * 9)
			vignette.BackgroundTransparency = 0.25 + pulse * 0.25
			run.Rotation = math.sin(t * 7) * 3
			local base = myBase()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local floor = base and base:FindFirstChild("Floor") :: BasePart?
			if root and floor then
				local d = (root.Position - floor.Position) * Vector3.new(1, 0, 1)
				run.Text = if d.Magnitude < 60 then "SAFE ZONE!" else "RUN!!"
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.15)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local best: Player? = nil
			if root and not player:GetAttribute("Carrying") then
				local bestD = Economy.SlapRange - 1
				for _, other in Players:GetPlayers() do
					if other ~= player and other:GetAttribute("Carrying") then
						local oc = other.Character
						local orr = oc and oc:FindFirstChild("HumanoidRootPart") :: BasePart?
						if orr then
							local d = (orr.Position - root.Position).Magnitude
							if d < bestD then
								best, bestD = other, d
							end
						end
					end
				end
			end
			slapTarget = best
			slap.Visible = best ~= nil
		end
	end)

	-- a guard spotted you: buzzer + red flash + shake
	Remotes.get(Remotes.Names.Alarm).OnClientEvent:Connect(function(vaultName: string)
		Sound.play("Alarm", 0.7)
		Shake.kick(0.25)
		HUD.toast("🚨 " .. vaultName .. "'s guard spotted you! RUN!", "bad")
		local flash = UI.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(255, 0, 30),
			BackgroundTransparency = 0.55,
			Parent = gui,
		})
		UI.tween(flash, 0.4, { BackgroundTransparency = 1 })
		task.delay(0.45, function()
			flash:Destroy()
		end)
	end)

	-- someone is carrying MY item: a beam from me to them + GO GET THEM!
	local a0 = Instance.new("Attachment")
	local a1 = Instance.new("Attachment")
	local thiefBeam = Instance.new("Beam")
	thiefBeam.Attachment0 = a0
	thiefBeam.Attachment1 = a1
	thiefBeam.Width0 = 1.6
	thiefBeam.Width1 = 0.6
	thiefBeam.FaceCamera = true
	thiefBeam.Color = ColorSequence.new(Color3.fromRGB(255, 60, 60))
	thiefBeam.LightEmission = 1
	thiefBeam.Transparency = NumberSequence.new(0.1)
	thiefBeam.Enabled = false
	thiefBeam.Parent = workspace.Terrain
	local goText = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 160),
		Size = UDim2.fromOffset(420, 46),
		Text = "🚨 GO GET THEM! SLAP THE THIEF! 🚨",
		TextColor3 = Color3.fromRGB(255, 90, 90),
		Visible = false,
		Parent = layer,
	}, Color3.fromRGB(40, 0, 0), 3)
	local wasChasing = false
	task.spawn(function()
		while true do
			task.wait(0.15)
			local thief: Player? = nil
			for _, other in Players:GetPlayers() do
				if other ~= player and other:GetAttribute("CarryVictim") == player.UserId then
					thief = other
				end
			end
			local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local theirRoot = thief and thief.Character and thief.Character:FindFirstChild("HumanoidRootPart")
			local on = myRoot ~= nil and theirRoot ~= nil
			if on then
				a0.Parent = myRoot
				a1.Parent = theirRoot
			end
			thiefBeam.Enabled = on
			goText.Visible = on
			if on then
				goText.Rotation = math.sin(os.clock() * 8) * 2
			end
			if on and not wasChasing then
				Sound.play("Alarm", 0.6)
				Shake.kick(0.3)
			end
			wasChasing = on
		end
	end)

	Remotes.get(Remotes.Names.Caught).OnClientEvent:Connect(function(by: string)
		Sound.play("Caught", 0.8)
		Shake.kick(0.7)
		HUD.announce("💥 CAUGHT by " .. by .. "! The loot went back.", { 255, 90, 90 })
		-- knock-up: our own client owns our character's physics, so the push happens here
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.AssemblyLinearVelocity = Vector3.new(0, 45, 0)
		end
		local flash = UI.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.2,
			Parent = gui,
		})
		UI.tween(flash, 0.5, { BackgroundTransparency = 1 })
		task.delay(0.6, function()
			flash:Destroy()
		end)
	end)

	Remotes.get(Remotes.Names.Deposited).OnClientEvent
		:Connect(function(name: string, rarity: string, mut: string, income: number, title: string?)
			local tier = Rarity.Tiers[rarity]
			local m = Mutations.List[mut]
			local big = rarity == "Legendary" or rarity == "Mythic" or (m and m.mult >= 5)
			Sound.play(if big then "Rare" else "Deposit", 0.7)
			local card = UI.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.42),
				Size = UDim2.fromOffset(420, 120),
				BackgroundColor3 = Color3.fromRGB(25, 25, 35),
				BackgroundTransparency = 0.1,
				Parent = layer,
			}, { UI.corner(22), UI.stroke(if tier then UI.rgb(tier.color) else Color3.new(1, 1, 1), 4) })
			UI.scaleObject(card)
			UI.bigText({
				Position = UDim2.fromOffset(10, 8),
				Size = UDim2.new(1, -20, 0, 26),
				Text = title or "STOLEN!",
				TextColor3 = Color3.fromRGB(255, 90, 90),
				Parent = card,
			})
			UI.bigText({
				Position = UDim2.fromOffset(10, 36),
				Size = UDim2.new(1, -20, 0, 40),
				Text = (if mut ~= "None" then mut .. " " else "") .. name,
				TextColor3 = if m and m.color then UI.rgb(m.color) else Color3.new(1, 1, 1),
				Parent = card,
			})
			UI.bigText({
				Position = UDim2.fromOffset(10, 80),
				Size = UDim2.new(1, -20, 0, 30),
				Text = rarity .. "  •  +" .. Format.cash(income) .. "/s",
				TextColor3 = if tier then UI.rgb(tier.color) else Color3.new(1, 1, 1),
				Parent = card,
			})
			local scale = card:FindFirstChildOfClass("UIScale") :: UIScale
			local target = scale.Scale
			scale.Scale = target * 0.3
			UI.tween(scale, 0.35, { Scale = target }, Enum.EasingStyle.Back)
			task.delay(if big then 3 else 1.8, function()
				UI.tween(card, 0.3, { BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0.3) })
				task.wait(0.32)
				card:Destroy()
			end)
		end)
end

return CarryFX
