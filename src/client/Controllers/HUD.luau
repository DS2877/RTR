--!strict
-- Heads-up display in the slim simulator style: icon tiles with tiny labels on the left (Store,
-- Event, Index, Gift + a Music switch), stat lines without boxes in the lower left, a hotbar in the
-- bottom middle, translucent round PUNCH / VACUUM / LIFT buttons next to the jump button, the zone
-- + depth on top, toasts, banners, the BACKPACK FULL pill with a subtle guide (floor arrow + dump marker), find popups, ADMIN.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Cycle = require(Shared.Config.Cycle)
local Zones = require(Shared.Config.Zones)
local Finds = require(Shared.Config.Finds)
local Rarity = require(Shared.Config.Rarity)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local Client = script.Parent.Parent
local UI = require(Client.Util.UI)
local LootToast = require(Client.Util.LootToast)
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
-- Slim notice pill: dark translucent, a colored dot, clean text. Fades + slides in, fades out.
local function toast(text: string, kind: string?)
	local colors = {
		good = Color3.fromRGB(90, 220, 110),
		bad = Color3.fromRGB(255, 90, 90),
		cash = Color3.fromRGB(255, 215, 60),
		upgrade = Color3.fromRGB(120, 200, 255),
		info = Color3.fromRGB(220, 224, 230),
	}
	local color = colors[kind or "info"] or colors.info
	local pill: CanvasGroup = UI.new("CanvasGroup", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		BackgroundColor3 = Color3.fromRGB(16, 17, 22),
		BackgroundTransparency = 0.25,
		GroupTransparency = 1,
		Parent = toastHolder,
	}, {
		UI.corner(14),
		UI.stroke(Color3.new(1, 1, 1), 1, 0.85),
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14) }),
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
		}),
	})
	UI.new("Frame", {
		Size = UDim2.fromOffset(7, 7),
		BackgroundColor3 = color,
		Parent = pill,
	}, { UI.corner(4) })
	UI.new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.55),
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		Parent = pill,
	})
	UI.tween(pill, 0.22, { GroupTransparency = 0 })
	task.delay(2.6, function()
		UI.tween(pill, 0.35, { GroupTransparency = 1 })
		task.wait(0.4)
		pill:Destroy()
	end)
	local kids = {}
	for _, k in toastHolder:GetChildren() do
		if k:IsA("CanvasGroup") then
			table.insert(kids, k)
		end
	end
	if #kids > 4 then
		kids[1]:Destroy()
	end
end
HUD.toast = toast

local banner: CanvasGroup
local bannerToken = 0
-- Zone reached etc.: a thin cinematic strip (hairlines above and below, wide title, small sub).
local function showBanner(title: string, sub: string, color: Color3)
	bannerToken += 1
	local mine = bannerToken
	local t = banner:FindFirstChild("Title") :: TextLabel
	local st = banner:FindFirstChild("Sub") :: TextLabel
	t.Text = title
	t.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.2)
	st.Text = string.upper(sub)
	for _, n in { "LineTop", "LineBottom" } do
		local line = banner:FindFirstChild(n) :: Frame
		line.BackgroundColor3 = color
		line.Size = UDim2.new(0, 0, 0, 1)
		UI.tween(line, 0.6, { Size = UDim2.new(0.8, 0, 0, 1) }, Enum.EasingStyle.Quint)
	end
	banner.Visible = true
	banner.GroupTransparency = 1
	banner.Position = UDim2.fromScale(0.5, 0.31)
	UI.tween(banner, 0.35, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.3) })
	task.delay(3, function()
		if bannerToken == mine then
			UI.tween(banner, 0.5, { GroupTransparency = 1 })
		end
	end)
	-- and really gone afterwards (a transparent CanvasGroup can stay drawn on some phones)
	task.delay(3.6, function()
		if bannerToken == mine then
			banner.Visible = false
		end
	end)
end

-- ===== find popup =====

local function showFind(id: string)
	local f = Finds.ById[id]
	if not f then
		return
	end
	local tier = Rarity.Tiers[f.rarity]
	LootToast.show({
		icon = f.emoji,
		title = f.name,
		tag = f.rarity .. " find",
		value = Format.noodles(f.value),
		color = rgb(tier.color),
		shine = tier.rank >= 3,
	})
	Sound.play(if tier.rank >= 3 then "Rare" else "Find", 0.7)
	if tier.rank >= 3 then
		Shake.kick(0.3)
	end
end

-- ===== guide (BACKPACK FULL -> dump) =====
-- Subtle on purpose: a small arrow on the floor at your feet pointing at the dump, and a small
-- marker over the dump itself (visible through walls) with the distance.

local guideOn = false
local arrow: Part? = nil
local arrowText: TextLabel? = nil
local marker: BillboardGui? = nil
local markerText: TextLabel? = nil

local function buildGuide(dump: BasePart)
	local a = Instance.new("Part")
	a.Name = "GuideArrow"
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.CastShadow = false
	a.Transparency = 1
	a.Size = Vector3.new(3, 0.05, 3)
	a.Parent = workspace
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Top
	sg.LightInfluence = 0
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.Parent = a
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = "➜"
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 214, 90)
	t.TextTransparency = 0.35
	t.Parent = sg
	arrow, arrowText = a, t
	local bb = Instance.new("BillboardGui")
	bb.Name = "DumpMarker"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(120, 26)
	bb.StudsOffset = Vector3.new(0, 6, 0)
	bb.LightInfluence = 0
	bb.Adornee = dump
	bb.Parent = player:WaitForChild("PlayerGui")
	local pill = Instance.new("TextLabel")
	pill.Size = UDim2.fromScale(1, 1)
	pill.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
	pill.BackgroundTransparency = 0.3
	pill.Font = Enum.Font.GothamBold
	pill.TextSize = 12
	pill.TextColor3 = Color3.fromRGB(255, 214, 90)
	pill.Text = "DUMP"
	pill.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = pill
	marker, markerText = bb, pill
end

local function setGuide(on: boolean)
	guideOn = on
	local dump = CollectionService:GetTagged("Dump")[1]
	if on and dump and dump:IsA("BasePart") and not arrow then
		buildGuide(dump)
	end
	if marker then
		marker.Enabled = on
	end
	if arrow then
		arrow.Parent = if on then workspace else nil
	end
end

RunService.RenderStepped:Connect(function()
	if not guideOn or not arrow or not arrowText then
		return
	end
	local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local dump = CollectionService:GetTagged("Dump")[1]
	if not r or not r:IsA("BasePart") or not dump or not dump:IsA("BasePart") then
		return
	end
	local flat = Vector3.new(dump.Position.X - r.Position.X, 0, dump.Position.Z - r.Position.Z)
	local dist = flat.Magnitude
	if markerText then
		markerText.Text = string.format("🗑️ DUMP · %dm", math.floor(dist / 3.5))
	end
	-- the arrow sits a few studs ahead of you towards the dump, pulsing softly; gone when close
	if dist < 14 then
		arrowText.TextTransparency = 1
		return
	end
	local dir = flat.Unit
	local feet = r.Position - Vector3.new(0, 2.9, 0) + dir * 4.5
	-- the "➜" glyph points along +X of the surface: turn +X to the dump direction
	arrow.CFrame = CFrame.lookAt(feet, feet + dir) * CFrame.Angles(0, math.pi / 2, 0)
	arrowText.TextTransparency = 0.35 + 0.25 * (0.5 + 0.5 * math.sin(os.clock() * 5))
end)

-- ===== admin =====

-- INDEX: the collection album (every find per zone, "?" for the missing ones)
local function buildIndex(): Panel.Panel
	local panel = Panel.new(
		"IndexPanel",
		"📖 INDEX",
		Color3.fromRGB(110, 200, 255),
		Color3.fromRGB(20, 60, 140),
		Vector2.new(580, 310)
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
			local row = Panel.row(panel.body, zone, 44)
			local complete = #list > 0
			for _, f in list do
				if not found[f.id] then
					complete = false
				end
			end
			Panel.text("title", z.name .. (if complete then " ✅" else ""), {
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(0.3, -12, 1, 0),
				TextSize = 14,
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
					Position = UDim2.new(0.3, (i - 1) * 38, 0, 5),
					Size = UDim2.fromOffset(34, 34),
					BackgroundColor3 = if got then rgb(tier.color) else Color3.new(1, 1, 1),
					BackgroundTransparency = if got then 0.45 else 0.92,
					Text = if got then f.emoji else "?",
					TextSize = 18,
					Font = Enum.Font.GothamBold,
					TextColor3 = Color3.fromRGB(150, 154, 168),
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
		CellSize = UDim2.fromOffset(122, 40),
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
		{ "📋 Roll call", "rollcall", nil },
		{ "Zone 10", "zone", 10 },
		{ "Bottom→Escape", "bottom", nil },
		{ "👮 Inspect me", "inspect", nil },
		{ "⚡ Blackout", "blackout", nil },
		{ "🔓 Riot", "riot", nil },
		{ "🧹 Inspection", "inspection", nil },
		{ "💰 Treasure", "treasure", nil },
		{ "💎 Gold rush", "goldrush", nil },
		{ "🍜 Payday", "payday", nil },
		{ "🌋 Quake", "earthquake", nil },
		{ "📦 Supply", "supplydrop", nil },
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
			{ Size = UDim2.fromOffset(122, 40) },
			Color3.fromRGB(255, 120, 120),
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
				"FPS %d · quality %s · voxel parts %d · debris %d · heaps %d",
				math.floor(frames / (now - last)),
				select(2, require(script.Parent.Quality).level()),
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
			{ Padding = UDim.new(0, 5), HorizontalAlignment = Enum.HorizontalAlignment.Center }
		),
	})
	UI.scaleObject(toastHolder)

	-- zone banner: thin cinematic strip
	banner = UI.new("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(520, 92),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	UI.scaleObject(banner)
	for _, line in { { "LineTop", 0 }, { "LineBottom", 1 } } do
		UI.new("Frame", {
			Name = line[1],
			AnchorPoint = Vector2.new(0.5, line[2]),
			Position = UDim2.fromScale(0.5, line[2]),
			Size = UDim2.new(0.8, 0, 0, 1),
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = banner,
		}, {
			UI.new("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end
	UI.new("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.GothamBlack,
		TextSize = 40,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = banner,
	}, { UI.textStroke(UI.INK, 1) })
	UI.new("TextLabel", {
		Name = "Sub",
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(215, 220, 228),
		Parent = banner,
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
			local cfg = Cycle.Events[ev :: string]
			local icon = eventTile:FindFirstChild("Icon")
			if cfg and icon and icon:IsA("TextLabel") then
				icon.Text = cfg.emoji
			end
		end
	end)
	player:GetAttributeChangedSignal("Noodles"):Connect(function()
		UI.bump(noodles.Parent :: GuiObject, 0.08)
	end)
	eventTile.Activated:Connect(function()
		local ev = ReplicatedStorage:GetAttribute("Event")
		local cfg = if typeof(ev) == "string" then Cycle.Events[ev] else nil
		if cfg then
			toast(cfg.emoji .. " " .. cfg.name .. ": " .. cfg.text, "cash")
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
		elseif bag + loose >= cap and player:GetAttribute("AutoVacuum") ~= true then
			kind = "loose"
		elseif fullKind == "slots" then
			kind = "slots"
		end
		local phase = ReplicatedStorage:GetAttribute("Phase")
		local locked = phase == "Night" or phase == "LightsOut"
		if kind == "bag" then
			fullText.Text = if locked
				then "BACKPACK FULL · rubble stays on the floor → flush it 🚽"
				else "BACKPACK FULL · rubble stays on the floor → Yard dump"
		elseif kind == "loose" then
			fullText.Text = "Hold 🌀 VACUUM to pick up the rubble!"
		elseif kind == "slots" then
			fullText.Text = "FIND SLOTS FULL · new finds go to your Stash → sell at The Fence"
		end
		fullBox.Visible = kind ~= nil
		setGuide(kind == "bag" and not locked)
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
	Remotes.get(Remotes.Names.Dumped).OnClientEvent:Connect(function(n, how)
		toast("+" .. Format.noodles(n) .. (if how == "flush" then "  🚽 flushed" else ""), "cash")
		Sound.play(if how == "flush" then "Splat" else "Dump", 0.7)
		fullKind = nil
	end)
	player:GetAttributeChangedSignal("SlotsUsed"):Connect(function()
		if attr("SlotsUsed", 0) < attr("Slots", 3) and fullKind == "slots" then
			fullKind = nil
		end
	end)
end

return HUD
