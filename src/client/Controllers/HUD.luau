--!strict
-- Heads-up display in the slim simulator style: icon tiles with tiny labels on the left (Store,
-- Event, Index, Gift + a Music switch), stat lines without boxes in the lower left, a hotbar in the
-- bottom middle, translucent round PUNCH / VACUUM / LIFT buttons next to the jump button, the zone
-- + depth on top, toasts, banners, the BACKPACK FULL pill with a guide beam, find popups, ADMIN.

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
local ExtraShops = require(script.Parent.ExtraShops)
local Music = require(script.Parent.Music)

local HUD = {}

-- containers other controllers fill (set in HUD.start)
HUD.hotbar = nil :: Frame?
HUD.buttons = nil :: Frame?
HUD.right = nil :: Frame?

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
		Size = UDim2.new(1, 0, 0, 22),
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

-- INDEX: the collection album (every find per zone, "?" for the missing ones)
local function buildIndex(): Panel.Panel
	local panel = Panel.new(
		"IndexPanel",
		"📖 INDEX",
		Color3.fromRGB(110, 200, 255),
		Color3.fromRGB(20, 60, 140),
		Vector2.new(600, 330)
	)
	UI.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.body }
	)
	local function render()
		for _, c in panel.body:GetChildren() do
			if not c:IsA("UIListLayout") then
				c:Destroy()
			end
		end
		local found: { [string]: boolean } = {}
		for _, id in string.split(tostring(player:GetAttribute("FoundList") or ""), ",") do
			found[id] = true
		end
		local have, total = 0, 0
		for zone, z in Zones do
			local list = Finds.ByZone[zone] or {}
			local row = UI.new("Frame", {
				LayoutOrder = zone,
				Size = UDim2.new(1, -8, 0, 44),
				BackgroundColor3 = Color3.new(1, 1, 1),
				Parent = panel.body,
			}, { UI.corner(10), UI.stroke(Color3.fromRGB(205, 205, 215), 1) })
			local complete = #list > 0
			for _, f in list do
				if not found[f.id] then
					complete = false
				end
			end
			UI.label({
				Position = UDim2.fromOffset(8, 4),
				Size = UDim2.new(0.3, -8, 1, -8),
				Text = z.name .. (if complete then " ✅" else ""),
				TextColor3 = Color3.fromRGB(40, 40, 55),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})
			for i, f in list do
				total += 1
				local got = found[f.id] == true
				if got then
					have += 1
				end
				local tier = Rarity.Tiers[f.rarity]
				UI.new("TextLabel", {
					Position = UDim2.new(0.3, (i - 1) * 40, 0, 4),
					Size = UDim2.fromOffset(36, 36),
					BackgroundColor3 = if got then rgb(tier.color) else Color3.fromRGB(60, 60, 70),
					BackgroundTransparency = if got then 0.35 else 0,
					Text = if got then f.emoji else "?",
					TextScaled = true,
					Font = Enum.Font.FredokaOne,
					TextColor3 = Color3.fromRGB(200, 200, 210),
					Parent = row,
				}, { UI.corner(8) })
			end
		end
		panel.subtitle.Text = string.format("%d/%d found", have, total)
	end
	panel.onOpen = render
	player:GetAttributeChangedSignal("FoundList"):Connect(function()
		if panel.isOpen() then
			render()
		end
	end)
	return panel
end

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
	local cmds: { { any } } = {
		{ "+1M 🍜", "noodles", 1e6 },
		{ "+1B 🍜", "noodles", 1e9 },
		{ "💪 1K", "strength", 1000 },
		{ "💪 100K", "strength", 1e5 },
		{ "Zone 2", "zone", 2 },
		{ "Zone 3", "zone", 3 },
		{ "Zone 4", "zone", 4 },
		{ "Zone 6", "zone", 6 },
		{ "Fill bag", "fill", nil },
		{ "Stress dig", "stress", nil },
		{ "Reset tunnel", "resettunnel", nil },
		{ "☀️ Day", "day", nil },
		{ "🌙 Night", "night", nil },
		{ "Zone 10", "zone", 10 },
		{ "Bottom→Escape", "bottom", nil },
		{ "👮 Inspect me", "inspect", nil },
		{ "⚡ Blackout", "blackout", nil },
		{ "🔓 Riot", "riot", nil },
		{ "🧹 Inspection", "inspection", nil },
		{ "💰 Treasure", "treasure", nil },
		{ "🧨 x5", "dynamite", 5 },
		{ "Perf", "perf", nil },
		{ "📸 Photo", "photo", nil },
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
			elseif c[2] == "photo" then
				-- photo mode for icons/thumbnails: hide every UI for 15 s
				local guis = {}
				for _, g in player:WaitForChild("PlayerGui"):GetChildren() do
					if g:IsA("ScreenGui") and g.Enabled then
						g.Enabled = false
						table.insert(guis, g)
					end
				end
				pcall(function()
					StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
				end)
				task.delay(15, function()
					for _, g in guis do
						g.Enabled = true
					end
					pcall(function()
						StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
						StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
					end)
				end)
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

	-- ===== LEFT: icon tiles (Store / Event, Index / Gift) + Music switch =====
	local left = UI.new("Frame", {
		Name = "Left",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.4, 0),
		Size = UDim2.fromOffset(160, 190),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }) })
	UI.scaleObject(left)
	local function tileRow(order: number): Frame
		return UI.new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 62),
			BackgroundTransparency = 1,
			Parent = left,
		}, {
			UI.new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
	end
	local row1, row2 = tileRow(1), tileRow(2)
	local storeTile =
		UI.tile(row1, "Store", "🛒", "Store", Color3.fromRGB(255, 120, 200), Color3.fromRGB(110, 90, 255))
	storeTile.LayoutOrder = 1
	UI.badge(storeTile, "!")
	local eventTile =
		UI.tile(row1, "Event", "⚡", "Event", Color3.fromRGB(255, 190, 70), Color3.fromRGB(240, 100, 40))
	eventTile.LayoutOrder = 2
	eventTile.Visible = false
	local indexTile =
		UI.tile(row2, "Index", "📖", "Index", Color3.fromRGB(110, 200, 255), Color3.fromRGB(40, 90, 220))
	indexTile.LayoutOrder = 1
	UI.badge(indexTile, "")
	local giftTile =
		UI.tile(row2, "Gift", "🎁", "10m", Color3.fromRGB(140, 240, 120), Color3.fromRGB(30, 160, 80))
	giftTile.LayoutOrder = 2
	UI.toggle(left, 3, "Music", true, function(on)
		Music.setEnabled(on)
	end)
	storeTile.Activated:Connect(function()
		Sound.play("Click")
		UI.badge(storeTile, "")
		ExtraShops.open("Store")
	end)
	local newFinds = 0
	local indexPanel = buildIndex()
	indexTile.Activated:Connect(function()
		Sound.play("Click")
		newFinds = 0
		UI.badge(indexTile, "")
		indexPanel.toggle()
	end)
	giftTile.Activated:Connect(function()
		toast("🎁 A free gift every " .. Economy.GiftMinutes .. " minutes you play!", "info")
	end)
	Remotes.get(Remotes.Names.Found).OnClientEvent:Connect(function()
		newFinds += 1
		UI.badge(indexTile, tostring(newFinds))
	end)

	-- ===== BOTTOM LEFT: stat lines without boxes =====
	local stats = UI.new("Frame", {
		Name = "Stats",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -10),
		Size = UDim2.fromOffset(260, 150),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		}),
	})
	UI.scaleObject(stats)
	local boost = UI.slimText({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 15), Text = "", Parent = stats })
	local strength = UI.statLine(stats, 2, "💪", Color3.fromRGB(255, 120, 110), 24)
	local bagText = UI.statLine(stats, 3, "🧱", Color3.fromRGB(235, 205, 150), 24)
	local slots = UI.statLine(stats, 4, "💎", Color3.fromRGB(205, 160, 255), 24)
	local noodles = UI.statLine(stats, 5, "🍜", Color3.fromRGB(255, 215, 70), 32)

	-- ===== TOP CENTER: zone + depth, toasts, full prompt =====
	local zoneText = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(320, 26),
		Text = "CELL BLOCK",
		Parent = gui,
	}, UI.INK, 1.6)
	UI.scaleObject(zoneText)

	toastHolder = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 118),
		Size = UDim2.fromOffset(460, 140),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new(
			"UIListLayout",
			{ Padding = UDim.new(0, 1), HorizontalAlignment = Enum.HorizontalAlignment.Center }
		),
	})
	UI.scaleObject(toastHolder)

	-- big banner (zone reached)
	banner = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromScale(0.6, 0.1),
		Text = "",
		Visible = false,
		Parent = gui,
	}, UI.INK, 2)
	bannerSub = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromScale(0.4, 0.045),
		Text = "",
		Visible = false,
		Parent = gui,
	}, UI.INK, 1.4)

	-- find card: slim dark card outlined in the rarity color
	findCard = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(220, 120),
		BackgroundColor3 = Color3.fromRGB(25, 25, 34),
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	}, { UI.corner(14), UI.stroke(Color3.new(1, 1, 1), 2) })
	UI.bigText({
		Name = "Title",
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 18),
		Text = "YOU FOUND",
		Parent = findCard,
	})
	UI.bigText({
		Name = "Emoji",
		Position = UDim2.fromOffset(10, 24),
		Size = UDim2.new(1, -20, 0, 44),
		Text = "",
		Parent = findCard,
	})
	UI.bigText({
		Name = "Name",
		Position = UDim2.fromOffset(10, 70),
		Size = UDim2.new(1, -20, 0, 24),
		Text = "",
		Parent = findCard,
	})
	UI.bigText({
		Name = "Rarity",
		Position = UDim2.fromOffset(10, 96),
		Size = UDim2.new(1, -20, 0, 18),
		Text = "",
		Parent = findCard,
	})

	-- FULL prompt: slim red pill
	local fullBox = UI.new("TextButton", {
		Name = "Full",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 34),
		Size = UDim2.fromOffset(360, 36),
		BackgroundColor3 = Color3.fromRGB(240, 70, 70),
		Text = "",
		Visible = false,
		Parent = gui,
	}, {
		UI.corner(18),
		UI.stroke(UI.INK, 2),
		UI.gradient(Color3.new(1, 1, 1), Color3.fromRGB(210, 210, 210)),
	})
	UI.scaleObject(fullBox)
	local fullText = UI.bigText({
		Position = UDim2.fromOffset(12, 7),
		Size = UDim2.new(1, -24, 1, -14),
		Text = "BACKPACK FULL → Dump in the Yard",
		Parent = fullBox,
	}, UI.INK, 1.4)

	-- ===== BOTTOM CENTER: hotbar (Moments puts 🧨 / 💡 here) =====
	local hotbar: Frame = UI.new("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(300, 58),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	UI.scaleObject(hotbar)
	HUD.hotbar = hotbar

	-- ===== BOTTOM RIGHT: action buttons next to the jump button =====
	local buttons = UI.new("Frame", {
		Name = "Buttons",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.fromOffset(280, 260),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.scaleObject(buttons, 1.1)
	HUD.buttons = buttons
	local punchBtn = UI.actionButton(buttons, "Punch", "👊", "PUNCH", 104)
	punchBtn.Position = UDim2.new(1, -205, 1, -80)
	local vacBtn = UI.actionButton(buttons, "Vacuum", "🌀", "VACUUM", 76)
	vacBtn.Position = UDim2.new(1, -96, 1, -178)
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
			vacBtn.BackgroundTransparency = if on then 0.15 else 0.45
		end
	end
	holdable(vacBtn, function()
		setVac(true)
	end, function()
		setVac(false)
	end)

	-- ===== RIGHT: admin tile =====
	local right = UI.new("Frame", {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.4, 0),
		Size = UDim2.fromOffset(56, 130),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
	UI.scaleObject(right)
	HUD.right = right
	local adminPanel = nil
	local adminBtn = UI.tile(
		right,
		"Admin",
		"🛠️",
		"Admin",
		Color3.fromRGB(255, 130, 120),
		Color3.fromRGB(200, 40, 50),
		54
	)
	adminBtn.LayoutOrder = 9
	adminBtn.Visible = false
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
			string.format("%s   ⚡%s", Format.number(attr("Strength", 10)), Format.number(attr("Power", 10)))
		bagText.Text = string.format("%s/%s", Format.number(bag), Format.number(cap))
			.. (if loose > 0 then string.format("  +%s", Format.number(loose)) else "")
		bagText.TextColor3 = if bag >= cap then Color3.fromRGB(255, 90, 90) else Color3.fromRGB(235, 205, 150)
		slots.Text = string.format("%d/%d", attr("SlotsUsed", 0), attr("Slots", 3))
		local parts = {}
		if player:GetAttribute("TopDog") == true then
			table.insert(parts, "🐶 TOP DOG")
		end
		local rebirths = attr("Rebirths", 0)
		if rebirths > 0 then
			table.insert(parts, string.format("Escapes x%s", Format.number(1 + rebirths * 0.5)))
		end
		if player:GetAttribute("GroupBonus") == true then
			table.insert(parts, "Group Boost: +10%")
		end
		local buffs = tostring(player:GetAttribute("Buffs") or "")
		if buffs ~= "" then
			table.insert(parts, "Buffs: " .. buffs)
		end
		boost.Text = table.concat(parts, " · ")
		local minutes = attr("PlayMinutes", 0)
		local label = giftTile:FindFirstChild("Label") :: TextLabel
		label.Text = (Economy.GiftMinutes - minutes % Economy.GiftMinutes) .. "m"
	end
	for _, name in
		{
			"Bag",
			"BagCap",
			"Loose",
			"Strength",
			"Power",
			"SlotsUsed",
			"Slots",
			"Rebirths",
			"GroupBonus",
			"Buffs",
			"PlayMinutes",
			"TopDog",
		}
	do
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
		-- event tile shows the running event's timer
		local ev = ReplicatedStorage:GetAttribute("Event")
		local running = typeof(ev) == "string" and ev ~= ""
		eventTile.Visible = running
		if running then
			local ends = ReplicatedStorage:GetAttribute("EventEnds")
			local left = if typeof(ends) == "number"
				then math.max(0, ends - workspace:GetServerTimeNow())
				else 0
			local label = eventTile:FindFirstChild("Label") :: TextLabel
			label.Text = Format.duration(left)
		end
	end)
	player:GetAttributeChangedSignal("Noodles"):Connect(function()
		UI.bump(noodles.Parent :: GuiObject, 0.08)
	end)
	eventTile.Activated:Connect(function()
		local ev = ReplicatedStorage:GetAttribute("Event")
		if typeof(ev) == "string" and ev ~= "" then
			toast("⚡ " .. ev .. " is on!", "cash")
		end
	end)

	-- context: zone label, full prompt, auto-vacuum (the gym has its own LIFT: GymController)
	local fullKind: string? = nil
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
		vacBtn.Visible = player:GetAttribute("AutoVacuum") ~= true
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
