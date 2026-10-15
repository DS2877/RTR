--!strict
-- Heads-up display, mobile first: big PUNCH / VACUUM / LIFT buttons in the lower right, Noodles,
-- strength, backpack and find slots, the zone + depth, toasts, banners, the BACKPACK FULL prompt
-- with a guide beam to the Yard dump, find popups, and the ADMIN panel for phone testing.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Zones = require(Shared.Config.Zones)
local Finds = require(Shared.Config.Finds)
local Rarity = require(Shared.Config.Rarity)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local Client = script.Parent.Parent
local UI = require(Client.Util.UI)
local Panel = require(Client.Util.Panel)
local Sound = require(Client.Util.Sound)
local Shake = require(Client.Util.Shake)
local DigController = require(script.Parent.DigController)
local DigFX = require(script.Parent.DigFX)
local VoxelRender = require(script.Parent.VoxelRender)
local CameraController = require(script.Parent.CameraController)

local HUD = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local DARK = Color3.fromRGB(20, 20, 28)

local function attr(name: string, default: number): number
	local v = player:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- ===== pieces =====

local function pill(parent: Instance, pos: UDim2, size: UDim2, color: Color3, icon: string): TextLabel
	local f = UI.new("Frame", {
		Position = pos,
		Size = size,
		BackgroundColor3 = color,
		Parent = parent,
	}, { UI.corner(14), UI.stroke(DARK, 3), UI.gradient(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)) })
	UI.bigText({
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.new(0, 34, 1, -8),
		Text = icon,
		Parent = f,
	})
	return UI.bigText({
		Name = "Value",
		Position = UDim2.fromOffset(42, 5),
		Size = UDim2.new(1, -50, 1, -10),
		Text = "0",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = f,
	})
end

local function roundButton(
	parent: Instance,
	name: string,
	text: string,
	color: Color3,
	size: number,
	pos: UDim2
): TextButton
	local b: TextButton = UI.new("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(1, 1),
		Position = pos,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		Text = "",
		AutoButtonColor = false,
		Parent = parent,
	}, {
		UI.corner(size // 2),
		UI.stroke(DARK, 4),
		UI.gradient(Color3.new(1, 1, 1), Color3.fromRGB(180, 180, 180)),
	})
	UI.bigText({
		Name = "Label",
		Position = UDim2.fromScale(0.1, 0.2),
		Size = UDim2.fromScale(0.8, 0.6),
		Text = text,
		Parent = b,
	}, DARK, 3)
	return b
end

-- press-and-hold helper that works for touch, mouse and gamepad-select
local function holdable(b: TextButton, onDown: () -> (), onUp: () -> ())
	b.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			UI.bump(b, -0.08)
			onDown()
		end
	end)
	b.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			onUp()
		end
	end)
	b.MouseLeave:Connect(onUp)
end

-- ===== toasts / banners =====

local toastHolder: Frame
local function toast(text: string, kind: string?)
	local colors = {
		good = Color3.fromRGB(90, 220, 110),
		bad = Color3.fromRGB(255, 90, 90),
		cash = Color3.fromRGB(255, 215, 60),
		upgrade = Color3.fromRGB(120, 200, 255),
		info = Color3.fromRGB(240, 240, 240),
	}
	local l = UI.bigText({
		Size = UDim2.new(1, 0, 0, 30),
		Text = text,
		TextColor3 = colors[kind or "info"] or colors.info,
		Parent = toastHolder,
	})
	task.delay(2.6, function()
		UI.tween(l, 0.4, { TextTransparency = 1 })
		task.wait(0.45)
		l:Destroy()
	end)
	local kids = toastHolder:GetChildren()
	if #kids > 5 then
		for _, k in kids do
			if k:IsA("TextLabel") then
				k:Destroy()
				break
			end
		end
	end
end
HUD.toast = toast

local banner: TextLabel
local bannerSub: TextLabel
local function showBanner(title: string, sub: string, color: Color3)
	banner.Text = title
	banner.TextColor3 = color
	bannerSub.Text = sub
	banner.Visible = true
	bannerSub.Visible = true
	local scale = banner:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = banner })
	scale.Scale = 0.3
	UI.tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(3.2, function()
		if banner.Text == title then
			banner.Visible = false
			bannerSub.Visible = false
		end
	end)
end

-- ===== find popup =====

local findCard: Frame
local function showFind(id: string)
	local f = Finds.ById[id]
	if not f then
		return
	end
	local tier = Rarity.Tiers[f.rarity]
	local color = rgb(tier.color)
	local emoji = findCard:FindFirstChild("Emoji") :: TextLabel
	local name = findCard:FindFirstChild("Name") :: TextLabel
	local rarity = findCard:FindFirstChild("Rarity") :: TextLabel
	emoji.Text = f.emoji
	name.Text = f.name
	rarity.Text = string.upper(f.rarity) .. " · " .. Format.noodles(f.value)
	rarity.TextColor3 = color
	local stroke = findCard:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Color = color
	findCard.Visible = true
	local scale = findCard:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = findCard })
	scale.Scale = 0.2
	UI.tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	Sound.play(if tier.rank >= 3 then "Rare" else "Find", 0.7)
	if tier.rank >= 3 then
		Shake.kick(0.4)
	end
	task.delay(2.4, function()
		if name.Text == f.name then
			findCard.Visible = false
		end
	end)
end

-- ===== guide beam (BACKPACK FULL -> dump) =====

local beam: Beam? = nil
local beamTarget: Attachment? = nil
local function setGuide(on: boolean)
	local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local dump = CollectionService:GetTagged("Dump")[1]
	if not on or not r or not dump then
		if beam then
			beam.Enabled = false
		end
		return
	end
	if not beam or not beam.Parent then
		local a0 = Instance.new("Attachment")
		a0.Name = "GuideA"
		a0.Parent = r
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.Transparency = 1
		holder.Size = Vector3.one
		holder.Parent = workspace
		local a1 = Instance.new("Attachment")
		a1.Parent = holder
		beamTarget = a1
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Width0 = 1.2
		b.Width1 = 1.2
		b.FaceCamera = true
		b.LightEmission = 1
		b.Color = ColorSequence.new(Color3.fromRGB(255, 220, 60))
		b.Transparency = NumberSequence.new(0.2)
		b.TextureSpeed = 2
		b.Segments = 20
		b.Parent = r
		beam = b
	end
	if beamTarget then
		(beamTarget.Parent :: BasePart).Position = (dump :: BasePart).Position + Vector3.new(0, 4, 0)
	end
	(beam :: Beam).Enabled = true
end

-- ===== admin =====

local function buildAdmin(parent: Instance)
	local panel = Panel.new(
		"AdminPanel",
		"ADMIN",
		Color3.fromRGB(255, 90, 90),
		Color3.fromRGB(120, 20, 30),
		Vector2.new(560, 320)
	)
	local grid = UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(126, 54),
		CellPadding = UDim2.fromOffset(8, 8),
		Parent = panel.body,
	})
	local _ = grid
	local perfOn = false
	local cmds = {
		{ "+1M 🍜", "noodles", 1e6 },
		{ "+1B 🍜", "noodles", 1e9 },
		{ "💪 1K", "strength", 1000 },
		{ "💪 100K", "strength", 1e5 },
		{ "Zone 2", "zone", 2 },
		{ "Zone 3", "zone", 3 },
		{ "Fill bag", "fill", nil },
		{ "Stress dig", "stress", nil },
		{ "Reset tunnel", "resettunnel", nil },
		{ "Day/Night", "day", nil },
		{ "Perf", "perf", nil },
		{ "RESET DATA", "reset", nil },
	}
	local remote = Remotes.get(Remotes.Names.AdminCmd)
	local perf = UI.label({
		Name = "Perf",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.fromOffset(330, 22),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		Parent = parent,
	})
	UI.textStroke(DARK, 2).Parent = perf
	for _, c in cmds do
		local b = Panel.button(
			{ Size = UDim2.fromOffset(126, 54) },
			Color3.fromRGB(255, 200, 200),
			Color3.fromRGB(120, 20, 30),
			c[1] :: string
		)
		b.Parent = panel.body
		b.Activated:Connect(function()
			Sound.play("Click")
			if c[2] == "perf" then
				perfOn = not perfOn
				perf.Visible = perfOn
			else
				remote:FireServer(c[2], c[3])
			end
		end)
	end
	local frames, last = 0, os.clock()
	RunService.RenderStepped:Connect(function()
		frames += 1
		local now = os.clock()
		if perfOn and now - last >= 0.5 then
			perf.Text = string.format(
				"FPS %d · voxel parts %d · debris %d · heaps %d",
				math.floor(frames / (now - last)),
				VoxelRender.partCount(),
				DigFX.debrisCount(),
				DigFX.heapCount()
			)
			frames, last = 0, now
		elseif not perfOn then
			frames, last = 0, now
		end
	end)
	return panel
end

-- ===== build =====

function HUD.start()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	gui = UI.new("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 2,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- top-left stats
	local stats = UI.new("Frame", {
		Name = "Stats",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(250, 210),
		Parent = gui,
	})
	UI.scaleObject(stats)
	local noodles =
		pill(stats, UDim2.fromOffset(0, 0), UDim2.fromOffset(240, 50), Color3.fromRGB(255, 200, 70), "🍜")
	local strength =
		pill(stats, UDim2.fromOffset(0, 56), UDim2.fromOffset(240, 42), Color3.fromRGB(255, 120, 110), "💪")
	local bagFrame = UI.new("Frame", {
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.fromOffset(240, 42),
		BackgroundColor3 = Color3.fromRGB(60, 60, 70),
		Parent = stats,
	}, { UI.corner(14), UI.stroke(DARK, 3) })
	local bagFill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(170, 150, 120),
		Parent = bagFrame,
	}, { UI.corner(14) })
	local bagText = UI.bigText({
		Position = UDim2.fromOffset(8, 5),
		Size = UDim2.new(1, -16, 1, -10),
		Text = "🪨 0/20",
		ZIndex = 2,
		Parent = bagFrame,
	})
	local slots = pill(
		stats,
		UDim2.fromOffset(0, 152),
		UDim2.fromOffset(240, 40),
		Color3.fromRGB(190, 140, 255),
		"💎"
	)

	-- top-center zone / depth
	local zoneBox = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(300, 40),
		BackgroundColor3 = Color3.fromRGB(30, 32, 40),
		BackgroundTransparency = 0.25,
		Parent = gui,
	}, { UI.corner(12) })
	UI.scaleObject(zoneBox)
	local zoneText = UI.bigText({
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 1, -8),
		Text = "CELL BLOCK",
		Parent = zoneBox,
	})

	toastHolder = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(460, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new(
			"UIListLayout",
			{ Padding = UDim.new(0, 2), HorizontalAlignment = Enum.HorizontalAlignment.Center }
		),
	})
	UI.scaleObject(toastHolder)

	-- big banner (zone reached, announcements)
	banner = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromScale(0.8, 0.13),
		Text = "",
		Visible = false,
		Parent = gui,
	}, DARK, 4)
	bannerSub = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(0.6, 0.06),
		Text = "",
		Visible = false,
		Parent = gui,
	}, DARK, 3)

	-- find card
	findCard = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(260, 150),
		BackgroundColor3 = Color3.fromRGB(30, 30, 40),
		Visible = false,
		Parent = gui,
	}, { UI.corner(20), UI.stroke(Color3.new(1, 1, 1), 5) })
	UI.bigText({
		Name = "Title",
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 26),
		Text = "YOU FOUND",
		Parent = findCard,
	})
	UI.bigText({
		Name = "Emoji",
		Position = UDim2.fromOffset(10, 30),
		Size = UDim2.new(1, -20, 0, 54),
		Text = "",
		Parent = findCard,
	})
	UI.bigText({
		Name = "Name",
		Position = UDim2.fromOffset(10, 86),
		Size = UDim2.new(1, -20, 0, 32),
		Text = "",
		Parent = findCard,
	})
	UI.bigText({
		Name = "Rarity",
		Position = UDim2.fromOffset(10, 118),
		Size = UDim2.new(1, -20, 0, 24),
		Text = "",
		Parent = findCard,
	})

	-- FULL prompt
	local fullBox = UI.new("TextButton", {
		Name = "Full",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.fromOffset(420, 64),
		BackgroundColor3 = Color3.fromRGB(255, 80, 80),
		Text = "",
		Visible = false,
		Parent = gui,
	}, { UI.corner(16), UI.stroke(DARK, 4), UI.gradient(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)) })
	UI.scaleObject(fullBox)
	local fullText = UI.bigText({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 1, -12),
		Text = "BACKPACK FULL → Dump in the Yard",
		Parent = fullBox,
	}, DARK, 3)

	-- buttons (lower right, above the jump button)
	local buttons = UI.new("Frame", {
		Name = "Buttons",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Size = UDim2.fromOffset(330, 300),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.scaleObject(buttons, 1.15)
	local punchBtn = roundButton(
		buttons,
		"Punch",
		"👊\nPUNCH",
		Color3.fromRGB(255, 170, 50),
		150,
		UDim2.new(1, -96, 1, -96)
	)
	local vacBtn = roundButton(
		buttons,
		"Vacuum",
		"🌀\nVACUUM",
		Color3.fromRGB(90, 200, 255),
		104,
		UDim2.new(1, -254, 1, -40)
	)
	local liftBtn = roundButton(
		buttons,
		"Lift",
		"🏋️\nLIFT",
		Color3.fromRGB(255, 110, 110),
		150,
		UDim2.new(1, -96, 1, -96)
	)
	liftBtn.Visible = false
	holdable(punchBtn, function()
		DigController.setHolding(true)
	end, function()
		DigController.setHolding(false)
	end)
	local vacRemote = Remotes.get(Remotes.Names.Vacuum)
	local vacuuming = false
	local function setVac(on: boolean)
		if on ~= vacuuming then
			vacuuming = on
			vacRemote:FireServer(on)
			DigFX.setVacuum(on)
		end
	end
	holdable(vacBtn, function()
		setVac(true)
	end, function()
		setVac(false)
	end)
	local liftRemote = Remotes.get(Remotes.Names.Lift)
	local lastLift = 0
	liftBtn.Activated:Connect(function()
		local now = os.clock()
		if now - lastLift >= Economy.LiftInterval then
			lastLift = now
			liftRemote:FireServer()
			UI.bump(liftBtn, 0.15)
		end
	end)

	-- admin
	local adminPanel = nil
	local adminBtn = UI.new("TextButton", {
		Name = "Admin",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(84, 40),
		BackgroundColor3 = Color3.fromRGB(255, 90, 90),
		Text = "ADMIN",
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = gui,
	}, { UI.corner(10), UI.stroke(DARK, 3) })
	UI.scaleObject(adminBtn)
	local function refreshAdmin()
		adminBtn.Visible = player:GetAttribute("Admin") == true
		if adminBtn.Visible and not adminPanel then
			adminPanel = buildAdmin(gui)
		end
	end
	player:GetAttributeChangedSignal("Admin"):Connect(refreshAdmin)
	refreshAdmin()
	adminBtn.Activated:Connect(function()
		if adminPanel then
			adminPanel.toggle()
		end
	end)

	-- live values
	local shownNoodles = attr("Noodles", 0)
	local function refresh()
		local bag, cap = attr("Bag", 0), attr("BagCap", 20)
		local loose = attr("Loose", 0)
		strength.Text =
			string.format("%s  ⚡%s", Format.number(attr("Strength", 10)), Format.number(attr("Power", 10)))
		bagText.Text = string.format("🪨 %s/%s", Format.number(bag), Format.number(cap))
			.. (if loose > 0 then string.format("  +%s", Format.number(loose)) else "")
		bagFill.Size = UDim2.fromScale(math.clamp(bag / math.max(1, cap), 0, 1), 1)
		bagFill.BackgroundColor3 = if bag >= cap
			then Color3.fromRGB(255, 90, 90)
			else Color3.fromRGB(170, 150, 120)
		slots.Text = string.format("Finds %d/%d", attr("SlotsUsed", 0), attr("Slots", 3))
	end
	for _, name in { "Bag", "BagCap", "Loose", "Strength", "Power", "SlotsUsed", "Slots" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
	RunService.RenderStepped:Connect(function(dt)
		local target = attr("Noodles", 0)
		if math.abs(target - shownNoodles) < 1 then
			shownNoodles = target
		else
			shownNoodles += (target - shownNoodles) * math.min(1, dt * 8)
		end
		noodles.Text = Format.number(math.floor(shownNoodles + 0.5))
	end)
	player:GetAttributeChangedSignal("Noodles"):Connect(function()
		UI.bump(noodles.Parent :: GuiObject, 0.12)
	end)

	-- context: zone label, LIFT near the gym, full prompt, auto-vacuum
	local fullKind: string? = nil
	local stations = CollectionService:GetTagged("GymStation")
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		local cell, z = CameraController.where()
		if cell then
			local zone = Zones[CameraController.zone()]
			zoneText.Text = string.format("%s · %dm", zone.name, math.max(0, z))
		else
			zoneText.Text = string.format("⛏️ Record %dm", attr("MaxDepth", 0))
		end
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local nearGym = false
		if r and r:IsA("BasePart") then
			if #stations == 0 then
				stations = CollectionService:GetTagged("GymStation")
			end
			for _, s in stations do
				if ((s :: BasePart).Position - r.Position).Magnitude <= Economy.GymRange then
					nearGym = true
				end
			end
		end
		liftBtn.Visible = nearGym
		punchBtn.Visible = not nearGym
		vacBtn.Visible = not nearGym and player:GetAttribute("AutoVacuum") ~= true
		-- full prompt
		local bag, cap, loose = attr("Bag", 0), attr("BagCap", 20), attr("Loose", 0)
		local kind: string? = nil
		if bag >= cap then
			kind = "bag"
		elseif bag + loose >= cap then
			kind = "loose"
		elseif fullKind == "slots" then
			kind = "slots"
		end
		if kind == "bag" then
			fullText.Text = "BACKPACK FULL → Dump in the Yard"
		elseif kind == "loose" then
			fullText.Text = "Hold 🌀 VACUUM to pick up the rubble!"
		elseif kind == "slots" then
			fullText.Text = "FIND SLOTS FULL → Sell at The Fence"
		end
		fullBox.Visible = kind ~= nil
		setGuide(kind == "bag")
	end)

	-- events
	Remotes.get(Remotes.Names.Notice).OnClientEvent:Connect(function(text, kind)
		toast(text, kind)
		if kind == "upgrade" then
			Sound.play("Upgrade")
		end
	end)
	Remotes.get(Remotes.Names.Announce).OnClientEvent:Connect(function(text, color, sound)
		toast("📢 " .. text, "cash")
		local _ = color
		if sound then
			Sound.play(sound, 0.5)
		end
	end)
	Remotes.get(Remotes.Names.Zone).OnClientEvent:Connect(function(zone)
		local z = Zones[zone]
		if not z then
			return
		end
		local c = z.palette[1]
		showBanner(
			z.name,
			"NEW ZONE UNLOCKED!",
			Color3.fromRGB(math.min(255, c[1] + 80), math.min(255, c[2] + 80), math.min(255, c[3] + 80))
		)
		Sound.play("Zone", 0.7)
		DigFX.confetti()
		Shake.kick(0.6)
	end)
	Remotes.get(Remotes.Names.Found).OnClientEvent:Connect(showFind)
	Remotes.get(Remotes.Names.Full).OnClientEvent:Connect(function(kind)
		fullKind = kind
		Sound.play("Full", 0.35)
		UI.bump(fullBox, 0.1)
		if kind == "slots" then
			task.delay(3, function()
				if fullKind == "slots" then
					fullKind = nil
				end
			end)
		end
	end)
	Remotes.get(Remotes.Names.Dumped).OnClientEvent:Connect(function(n)
		toast("+" .. Format.noodles(n), "cash")
		Sound.play("Dump", 0.7)
		fullKind = nil
	end)
	Remotes.get(Remotes.Names.Lifted).OnClientEvent:Connect(function(gain)
		toast("+" .. gain .. " 💪", "good")
		Sound.play("Click", 0.4, 0.8 + math.random() * 0.3)
	end)
	player:GetAttributeChangedSignal("SlotsUsed"):Connect(function()
		if attr("SlotsUsed", 0) < attr("Slots", 3) and fullKind == "slots" then
			fullKind = nil
		end
	end)
end

return HUD
