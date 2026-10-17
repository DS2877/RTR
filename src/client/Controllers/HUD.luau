--!strict
-- Heads-up display in the slim simulator style: icon tiles with tiny labels on the left (Store,
-- Event, Index, Gift + a Music switch), stat lines without boxes in the lower left, a hotbar in the
-- bottom middle, translucent round PUNCH / VACUUM / LIFT buttons next to the jump button, the zone
-- + depth on top, toasts, banners, a small FULL chip, find popups, ADMIN.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Zones = require(Shared.Config.Zones)
local Finds = require(Shared.Config.Finds)
local Rarity = require(Shared.Config.Rarity)
local World = require(Shared.Config.World)
local Upgrades = require(Shared.Config.Upgrades)
local Extras = require(Shared.Config.Extras)

-- buff id -> the emoji of the meal / item that gives it (HUD boost line)
local BUFF_ICON: { [string]: string } = { Rush = "⚡2x NOODLES" }
for _, list in { Extras.Meals, Extras.Market } do
	for _, it in list :: { any } do
		if it.buff and not BUFF_ICON[it.buff] then
			BUFF_ICON[it.buff] = it.emoji
		end
	end
end
local Progression = require(Shared.Progression)
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
HUD.crewTile = nil :: GuiButton? -- Controllers/Crew wires it
HUD.petsTile = nil :: GuiButton? -- Controllers/Pets wires it
HUD.passTile = nil :: GuiButton? -- Controllers/PassUI wires it
HUD.right = nil :: Frame?
HUD.replayTour = nil :: (() -> ())? -- (admin) the first-join tour again (Controllers/Tour)

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

-- Press-and-hold helper for touch and mouse. The hold belongs to the input that started it: it
-- ends when THAT finger lifts or is cancelled (even after sliding off the button, where the button
-- itself never hears the end), not when another finger lets go. Returns release() to end it from
-- outside (the buttons got hidden mid-hold).
local function holdable(b: TextButton, onDown: () -> (), onUp: () -> ()): () -> ()
	local active: InputObject? = nil
	local watch: RBXScriptConnection? = nil
	local function release()
		if watch then
			watch:Disconnect()
			watch = nil
		end
		if active then
			active = nil
			onUp()
		end
	end
	b.InputBegan:Connect(function(input)
		if
			active == nil
			and (
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			)
		then
			active = input
			watch = input.Changed:Connect(function(prop)
				if
					prop == "UserInputState"
					and (
						input.UserInputState == Enum.UserInputState.End
						or input.UserInputState == Enum.UserInputState.Cancel
					)
				then
					release()
				end
			end)
			UI.bump(b, -0.08)
			onDown()
		end
	end)
	b.InputEnded:Connect(function(input)
		if input == active then
			release()
		end
	end)
	-- the mouse leaving ends a mouse hold (a finger sliding off keeps holding until it lifts)
	b.MouseLeave:Connect(function()
		local a = active
		if a and a.UserInputType == Enum.UserInputType.MouseButton1 then
			release()
		end
	end)
	return release
end

-- ===== toasts / banners =====

local toastHolder: Frame
local toastCount = 0
-- Toasts live in their own layer above the panels: under the zone line normally, at the bottom
-- of the screen while a panel is open (so they never hide behind or on top of the menu).
local function placeToasts()
	if Panel.anyOpen() then
		toastHolder.AnchorPoint = Vector2.new(0.5, 1)
		toastHolder.Position = UDim2.new(0.5, 0, 1, -4)
		local layout = toastHolder:FindFirstChildOfClass("UIListLayout")
		if layout then
			layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		end
	else
		toastHolder.AnchorPoint = Vector2.new(0.5, 0)
		toastHolder.Position = UDim2.new(0.5, 0, 0, 118)
		local layout = toastHolder:FindFirstChildOfClass("UIListLayout")
		if layout then
			layout.VerticalAlignment = Enum.VerticalAlignment.Top
		end
	end
end
-- Slim notice pill: dark translucent, a colored dot, clean text. Fades + slides in, fades out.
local function toast(text: string, kind: string?)
	placeToasts()
	toastCount += 1
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
		Size = UDim2.fromOffset(0, 32),
		BackgroundColor3 = Color3.fromRGB(16, 17, 22),
		BackgroundTransparency = 0.25,
		GroupTransparency = 1,
		LayoutOrder = toastCount,
		Parent = toastHolder,
	}, {
		UI.corner(16),
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
		Size = UDim2.fromOffset(0, 32),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.55),
		Font = Enum.Font.GothamMedium,
		TextSize = 17,
		Parent = pill,
	})
	UI.tween(pill, 0.22, { GroupTransparency = 0 })
	-- longer texts stay longer (time to read them)
	task.delay(math.clamp(2.2 + #text * 0.04, 2.6, 6), function()
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

-- ===== admin =====

-- INDEX: the collection album (every find per zone, "?" for the missing ones)
-- WORK DETAIL: today's three jobs (server: Services/Missions, attribute "Missions" = JSON)
local function readJobs(): any
	local raw = player:GetAttribute("Missions")
	if typeof(raw) ~= "string" then
		return nil
	end
	local ok, data = pcall(function()
		return game:GetService("HttpService"):JSONDecode(raw)
	end)
	return if ok then data else nil
end

local function claimable(data: any): number
	if not data then
		return 0
	end
	local n, all = 0, true
	for _, it in data.items do
		if it.progress >= it.goal and not it.claimed then
			n += 1
		end
		if not it.claimed then
			all = false
		end
	end
	if all and not data.bonus then
		n += 1
	end
	return n
end

local function buildJobs(): Panel.Panel
	local panel = Panel.new(
		"JobsPanel",
		"📋 WORK DETAIL",
		Color3.fromRGB(255, 170, 60),
		Color3.fromRGB(110, 60, 0),
		Vector2.new(540, 300)
	)
	UI.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.body }
	)
	local claim = Remotes.get(Remotes.Names.ClaimMission)
	local function render()
		for _, c in panel.body:GetChildren() do
			if not c:IsA("UIListLayout") then
				c:Destroy()
			end
		end
		local data = readJobs()
		if not data then
			return
		end
		local left = math.max(0, (data.resets or 0) - os.time())
		panel.subtitle.Text = "new jobs in " .. Format.duration(left)
		local allClaimed = true
		for i, it in data.items do
			local done = it.progress >= it.goal
			allClaimed = allClaimed and it.claimed
			local r = Panel.row(panel.body, i, 58)
			Panel.text("title", it.emoji .. "  " .. it.text, {
				Position = UDim2.fromOffset(12, 9),
				Size = UDim2.new(0.66, -12, 0, 18),
				Parent = r,
			})
			-- progress bar + count
			local bar = UI.new("Frame", {
				Position = UDim2.fromOffset(12, 36),
				Size = UDim2.new(0.5, -12, 0, 5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.88,
				Parent = r,
			}, { UI.corner(3) })
			UI.new("Frame", {
				Size = UDim2.fromScale(math.clamp(it.progress / it.goal, 0, 1), 1),
				BackgroundColor3 = if done
					then Color3.fromRGB(90, 220, 110)
					else Color3.fromRGB(255, 170, 60),
				Parent = bar,
			}, { UI.corner(3) })
			Panel.text("desc", string.format("%d / %d", it.progress, it.goal), {
				Position = UDim2.new(0.5, 6, 0, 30),
				Size = UDim2.new(0.16, 0, 0, 16),
				TextSize = 12,
				Parent = r,
			})
			local b = Panel.button(
				{
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.new(0.28, 0, 0, 44),
				},
				if done and not it.claimed
					then Color3.fromRGB(90, 220, 110)
					else Color3.fromRGB(190, 190, 190),
				Color3.fromRGB(30, 80, 40),
				if it.claimed then "✓ PAID" else Format.noodles(it.reward)
			)
			b.Parent = r
			b.Activated:Connect(function()
				if done and not it.claimed then
					Sound.play("Coin")
					claim:FireServer(i)
				elseif not it.claimed then
					Sound.play("Click", 0.4, 0.8)
					toast("Finish the job first", "info")
				end
			end)
		end
		-- the bonus for all three
		local r = Panel.row(panel.body, 10, 56)
		Panel.text("note", "🎁  Finish all three jobs", {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(0.66, -12, 1, 0),
			TextSize = 14,
			Parent = r,
		})
		local ready = allClaimed and not data.bonus
		local b = Panel.button(
			{
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.new(0.28, 0, 0, 44),
			},
			if ready then Color3.fromRGB(255, 200, 70) else Color3.fromRGB(190, 190, 190),
			Color3.fromRGB(110, 70, 0),
			if data.bonus then "✓ PAID" else Format.noodles(data.bonusReward)
		)
		b.Parent = r
		b.Activated:Connect(function()
			if ready then
				Sound.play("Coin")
				claim:FireServer(4)
			elseif not data.bonus then
				Sound.play("Click", 0.4, 0.8)
				toast("Claim all three jobs first", "info")
			end
		end)
	end
	panel.onOpen = render
	player:GetAttributeChangedSignal("Missions"):Connect(function()
		if panel.isOpen() then
			render()
		end
	end)
	return panel
end

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
			local row = Panel.row(panel.body, zone, 72)
			local complete = #list > 0
			for _, f in list do
				if not found[f.id] then
					complete = false
				end
			end
			-- the zone's name on its own line, its finds on the line under it
			Panel.text("title", z.name .. (if complete then " ✅" else ""), {
				Position = UDim2.fromOffset(12, 4),
				Size = UDim2.new(1, -24, 0, 22),
				TextSize = 16,
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
					Position = UDim2.fromOffset(12 + (i - 1) * 40, 30),
					Size = UDim2.fromOffset(36, 36),
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
		{ "🏃 Breakout", "breakout", nil },
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
		{ "🎬 Tour", "tour", nil },
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
			if c[2] == "tour" then
				panel.setOpen(false)
				if HUD.replayTour then
					HUD.replayTour()
				end
			elseif c[2] == "perf" then
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

	-- ===== LEFT: icon tiles (Store / Jobs / Pass, Index / Gift, Crew / Pets) =====
	-- (a bit bigger than the rest of the HUD: these are tap targets; the Music switch is a small
	-- chip in the top-left corner so the column clears the stat lines below it)
	local left = UI.new("Frame", {
		Name = "Left",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.4, 0),
		Size = UDim2.fromOffset(210, 190),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }) })
	UI.scaleObject(left, 1.15)
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
	local row1, row2, row3 = tileRow(1), tileRow(2), tileRow(3)
	local storeTile =
		UI.tile(row1, "Store", "🛒", "Store", Color3.fromRGB(255, 120, 200), Color3.fromRGB(110, 90, 255))
	storeTile.LayoutOrder = 1
	UI.badge(storeTile, "!")
	-- WORK DETAIL (the running event has its own card at the top)
	local jobsTile =
		UI.tile(row1, "Jobs", "📋", "Jobs", Color3.fromRGB(255, 190, 70), Color3.fromRGB(240, 100, 40))
	jobsTile.LayoutOrder = 2
	-- PRISON PASS (Controllers/PassUI)
	local passTile =
		UI.tile(row1, "Pass", "🎫", "Pass", Color3.fromRGB(255, 230, 120), Color3.fromRGB(220, 130, 30))
	passTile.LayoutOrder = 3
	HUD.passTile = passTile
	local jobsPanel = buildJobs()
	local function jobsBadge()
		local n = claimable(readJobs())
		UI.badge(jobsTile, if n > 0 then tostring(n) else "", Color3.fromRGB(60, 190, 90))
	end
	player:GetAttributeChangedSignal("Missions"):Connect(jobsBadge)
	task.defer(jobsBadge)
	jobsTile.Activated:Connect(function()
		Sound.play("Click")
		jobsPanel.toggle()
	end)
	Remotes.get(Remotes.Names.MissionDone).OnClientEvent:Connect(function(i: number)
		local data = readJobs()
		local it = data and data.items[i]
		if it then
			LootToast.show({
				icon = it.emoji,
				title = it.text,
				tag = "Job done · tap 📋 Jobs",
				value = Format.noodles(it.reward),
				color = Color3.fromRGB(255, 170, 60),
				seconds = 3.4,
			})
			Sound.play("Upgrade", 0.5, 1.1)
			UI.bump(jobsTile, 0.2)
		end
	end)
	local indexTile =
		UI.tile(row2, "Index", "📖", "Index", Color3.fromRGB(110, 200, 255), Color3.fromRGB(40, 90, 220))
	indexTile.LayoutOrder = 1
	UI.badge(indexTile, "")
	local giftTile =
		UI.tile(row2, "Gift", "🎁", "10m", Color3.fromRGB(140, 240, 120), Color3.fromRGB(30, 160, 80))
	giftTile.LayoutOrder = 2
	-- CREW: dig with friends (Controllers/Crew opens the panel)
	local crewTile =
		UI.tile(row3, "Crew", "👥", "Crew", Color3.fromRGB(120, 230, 255), Color3.fromRGB(40, 120, 220))
	crewTile.LayoutOrder = 1
	HUD.crewTile = crewTile
	-- CELLMATES (Controllers/Pets)
	local petsTile =
		UI.tile(row3, "Pets", "🐀", "Pets", Color3.fromRGB(255, 200, 120), Color3.fromRGB(190, 110, 40))
	petsTile.LayoutOrder = 2
	HUD.petsTile = petsTile
	left.Size = UDim2.fromOffset(210, 210)
	-- MUSIC: a small round 🎵 chip in the top-left corner (the now-playing chip slides in right of it)
	local musicOn = true
	local musicBtn: TextButton = UI.new("TextButton", {
		Name = "Music",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = Color3.fromRGB(16, 17, 22),
		BackgroundTransparency = 0.3,
		Text = "🎵",
		TextSize = 24,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = true,
		Parent = gui,
	}, { UI.corner(23), UI.stroke(Color3.new(1, 1, 1), 1, 0.8) })
	UI.scaleObject(musicBtn)
	local musicSlash = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.75, 0, 0, 3),
		Rotation = -45,
		BackgroundColor3 = Color3.fromRGB(255, 90, 90),
		BorderSizePixel = 0,
		Visible = false,
		Parent = musicBtn,
	})
	musicBtn.Activated:Connect(function()
		musicOn = not musicOn
		musicSlash.Visible = not musicOn
		musicBtn.TextTransparency = if musicOn then 0 else 0.5
		Sound.play("Click")
		Music.setEnabled(musicOn)
		toast(if musicOn then "🎵 Music on" else "🎵 Music off", "info")
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
	local boost = UI.slimText({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 19),
		Text = "",
		TextScaled = false,
		TextSize = 16,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = stats,
	})
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
	-- the goal: a thin bar to the next zone ("8m to BRICK"), always in view
	local goal = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 34),
		Size = UDim2.fromOffset(240, 24),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.scaleObject(goal)
	local goalBar = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = Color3.fromRGB(16, 17, 22),
		BackgroundTransparency = 0.35,
		Parent = goal,
	}, { UI.corner(2) })
	local goalFill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(255, 200, 90),
		Parent = goalBar,
	}, { UI.corner(2) })
	local goalText: TextLabel = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 5),
		Size = UDim2.new(1, 0, 0, 19),
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(236, 238, 244),
		Parent = goal,
	}, { UI.textStroke(UI.INK, 1) })
	local lastGoalZone = 0
	local function updateGoal()
		local depth = attr("RunDepth", 0) -- this run's tunnel (the record stays after an escape)
		local zi = Progression.zoneAt(depth)
		local nextZone = Zones[zi + 1]
		local from = Progression.zoneStart(zi)
		local to = if nextZone then Progression.zoneStart(zi + 1) else World.TunnelDepth
		if nextZone and to > Progression.diggableDepth() then
			goalText.Text = "NEW ZONES SOON"
			goalFill.Size = UDim2.fromScale(1, 1)
			return
		end
		local k = math.clamp((depth - from) / math.max(1, to - from), 0, 1)
		UI.tween(goalFill, 0.3, { Size = UDim2.fromScale(k, 1) })
		local c = if nextZone then nextZone.palette[1] else { 255, 200, 90 }
		goalFill.BackgroundColor3 =
			Color3.fromRGB(math.min(255, c[1] + 70), math.min(255, c[2] + 70), math.min(255, c[3] + 70))
		goalText.Text = string.format(
			"%dm to %s",
			math.max(0, to - depth),
			if nextZone then nextZone.name else "THE ESCAPE"
		)
		if zi ~= lastGoalZone then
			if lastGoalZone ~= 0 then
				UI.bump(goal, 0.2)
			end
			lastGoalZone = zi
		end
	end
	player:GetAttributeChangedSignal("RunDepth"):Connect(updateGoal)
	task.defer(updateGoal)

	-- toasts: their own layer above the panels (placeToasts moves them while a panel is open)
	local toastGui = UI.new("ScreenGui", {
		Name = "Toasts",
		ResetOnSpawn = false,
		DisplayOrder = 7,
		Parent = player:WaitForChild("PlayerGui"),
	})
	toastHolder = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 118),
		Size = UDim2.fromOffset(460, 160),
		BackgroundTransparency = 1,
		Parent = toastGui,
	}, {
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 5),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
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
		TextScaled = true, -- (long zone names shrink instead of spilling out)
		TextColor3 = Color3.new(1, 1, 1),
		Parent = banner,
	}, { UI.textStroke(UI.INK, 1), UI.new("UITextSizeConstraint", { MaxTextSize = 40 }) })
	UI.new("TextLabel", {
		Name = "Sub",
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextSize = 17,
		TextColor3 = Color3.fromRGB(215, 220, 228),
		Parent = banner,
	})

	-- FULL notice: a small dark chip with a red dot, shown for a few seconds when it changes
	-- (the rubble counter itself turns red while you're full)
	local fullBox = UI.new("Frame", {
		Name = "Full",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(16, 17, 22),
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = gui,
	}, {
		UI.corner(14),
		UI.stroke(Color3.new(1, 1, 1), 1, 0.85),
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 26), PaddingRight = UDim.new(0, 12) }),
	})
	UI.scaleObject(fullBox)
	UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -15, 0.5, 0),
		Size = UDim2.fromOffset(7, 7),
		BackgroundColor3 = Color3.fromRGB(255, 90, 90),
		Parent = fullBox,
	}, { UI.corner(4) })
	local fullText: TextLabel = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "",
		RichText = true,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(240, 242, 248),
		Parent = fullBox,
	})
	local shownKind: string? = nil
	local shownAt = 0
	-- PUNCH with a full backpack: the chip comes back (with a bump) for another few seconds
	DigController.onBagFull = function()
		shownAt = os.clock()
		if attr("Bag", 0) >= attr("BagCap", 20) then
			fullBox.Visible = true
			UI.bump(fullBox, 0.15)
		end
	end

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
	local releasePunch = holdable(punchBtn, function()
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
	local releaseVac = holdable(vacBtn, function()
		setVac(true)
	end, function()
		setVac(false)
	end)

	-- ===== RIGHT: admin tile =====
	-- (left of the top-right column: never under the loot cards or the clock)
	local right = UI.new("Frame", {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(56, 130),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
	UI.scaleObject(right)
	local function placeRight()
		right.Position = UDim2.new(1, -(14 + 310 * UI.screenScale()), 0, 10)
	end
	placeRight()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(placeRight)
	end
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
			local icons = {}
			for _, id in string.split(buffs, ",") do
				table.insert(icons, BUFF_ICON[id] or id)
			end
			table.insert(parts, table.concat(icons, " "))
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
	end)
	player:GetAttributeChangedSignal("Noodles"):Connect(function()
		UI.bump(noodles.Parent :: GuiObject, 0.08)
	end)
	-- UPGRADE READY: a card the first time you can afford the next tool / brush / backpack
	local told: { [string]: boolean } = {}
	local SHOP_OF = { Tools = "Tool Crib", Brushes = "Tool Crib", Backpack = "Commissary" }
	local function checkUpgrades()
		local money = attr("Noodles", 0)
		for _, track in { "Tools", "Brushes", "Backpack" } do
			local level = attr(track, 1)
			local cost = Progression.nextCost(track, level)
			local key = track .. level
			if cost and money >= cost and not told[key] then
				told[key] = true
				local nxt = (Upgrades :: any)[track][level + 1]
				LootToast.show({
					icon = nxt.emoji,
					title = nxt.name .. " is ready",
					tag = "Upgrade · " .. SHOP_OF[track],
					value = Format.noodles(cost),
					color = Color3.fromRGB(90, 220, 130),
					seconds = 3.6,
				})
				Sound.play("Upgrade", 0.45, 1.25)
				break -- one at a time
			end
		end
	end
	player:GetAttributeChangedSignal("Noodles"):Connect(checkUpgrades)

	-- context: zone label, full prompt, auto-vacuum (the gym has its own LIFT: GymController)
	local fullKind: string? = nil
	local buttonsLive = true
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		placeToasts()
		local cell, z = CameraController.where()
		if cell then
			local zone = Zones[CameraController.zone()]
			zoneText.Text = string.format("%s · %dm", zone.name, math.max(0, z))
		else
			zoneText.Text = string.format("⛏️ Record %dm", attr("MaxDepth", 0))
		end
		vacBtn.Visible = player:GetAttribute("AutoVacuum") ~= true
		-- buttons hidden (gym, bed, cinematic) mid-hold: let go, or PUNCH / VACUUM stay stuck on
		local live = buttons.Visible and gui.Enabled
		if not live then
			releasePunch()
			releaseVac()
			setVac(false)
			if buttonsLive then
				DigController.setHolding(false)
			end
		end
		buttonsLive = live
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
		local muted = '<font color="#A8ACBA" weight="medium">'
		if kind == "bag" then
			fullText.Text = "Backpack full"
				.. muted
				.. (if locked then "  ·  flush it down your toilet" else "  ·  dump it in the Yard")
				.. "</font>"
		elseif kind == "loose" then
			fullText.Text = "Rubble on the floor" .. muted .. "  ·  hold VACUUM</font>"
		elseif kind == "slots" then
			fullText.Text = "Find slots full" .. muted .. "  ·  new finds go to your Stash</font>"
		end
		-- only for a few seconds each time it changes: no nagging while you keep digging
		if kind ~= shownKind then
			shownKind = kind
			shownAt = os.clock()
			if kind then
				Sound.play("Full", 0.3)
			end
		end
		fullBox.Visible = kind ~= nil and os.clock() - shownAt < 5
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
