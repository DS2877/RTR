--!strict
-- Main HUD (mobile first): currency pills top-left, menu buttons on the left edge, the
-- 👑 richest bar at the top center, Lock + Slow Mode buttons, toasts and announcements.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Economy = require(Shared.Config.Economy)

local UI = require(script.Parent.Parent.Util.UI)
local Sound = require(script.Parent.Parent.Util.Sound)
local Music = require(script.Parent.Parent.Util.Music)

local HUD = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local toastHolder: Frame
local announceLabel: TextLabel

HUD.buttons = {} :: { [string]: TextButton }

local DARK = Color3.fromRGB(20, 20, 28)

function HUD.button(
	name: string,
	emoji: string,
	text: string,
	color: Color3,
	parent: Instance,
	order: number
): TextButton
	local b: TextButton = UI.new("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = color,
		Text = "",
		AutoButtonColor = true,
		LayoutOrder = order,
		Parent = parent,
	}, {
		UI.corner(18),
		UI.stroke(color:Lerp(Color3.new(0, 0, 0), 0.55), 3.5),
		UI.gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
	})
	UI.label({
		Name = "Emoji",
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 34),
		Text = emoji,
		Font = Enum.Font.GothamBold,
		Parent = b,
	})
	UI.bigText({
		Name = "Text",
		Position = UDim2.new(0, 3, 1, -22),
		Size = UDim2.new(1, -6, 0, 18),
		Text = text,
		Parent = b,
	}, color:Lerp(Color3.new(0, 0, 0), 0.6), 2)
	b.Activated:Connect(function()
		Sound.play("Click", 0.4)
		UI.bump(b, 0.12)
	end)
	HUD.buttons[name] = b
	return b
end

function HUD.toast(text: string, kind: string?)
	if not toastHolder then
		return
	end
	local colors = {
		good = Color3.fromRGB(110, 255, 130),
		bad = Color3.fromRGB(255, 100, 100),
		cash = Color3.fromRGB(120, 255, 120),
		upgrade = Color3.fromRGB(120, 200, 255),
		info = Color3.fromRGB(255, 255, 255),
	}
	local l = UI.bigText({
		Size = UDim2.new(1, 0, 0, 30),
		Text = text,
		TextColor3 = (colors :: any)[kind or "info"] or Color3.new(1, 1, 1),
		TextTransparency = 0,
		Parent = toastHolder,
	}, DARK, 2.5)
	UI.bump(l, 0.25)
	if kind == "cash" then
		Sound.play("Collect", 0.6)
	elseif kind == "upgrade" then
		Sound.play("Upgrade", 0.6)
	end
	task.delay(2.6, function()
		UI.tween(l, 0.4, { TextTransparency = 1 })
		local s = l:FindFirstChildOfClass("UIStroke")
		if s then
			UI.tween(s, 0.4, { Transparency = 1 })
		end
		task.wait(0.45)
		l:Destroy()
	end)
	local kids = toastHolder:GetChildren()
	local labels = 0
	for _, k in kids do
		if k:IsA("TextLabel") then
			labels += 1
		end
	end
	if labels > 4 then
		for _, k in kids do
			if k:IsA("TextLabel") then
				k:Destroy()
				break
			end
		end
	end
end

function HUD.announce(text: string, color: { number }?, sound: string?)
	if not announceLabel then
		return
	end
	announceLabel.Text = text
	announceLabel.TextColor3 = if color then UI.rgb(color) else Color3.fromRGB(255, 215, 60)
	announceLabel.Visible = true
	announceLabel.TextTransparency = 0
	UI.bump(announceLabel, 0.3)
	Sound.play(sound or "Announce", if sound then 0.6 else 0.35)
	local stamp = os.clock()
	announceLabel:SetAttribute("Stamp", stamp)
	task.delay(5, function()
		if announceLabel:GetAttribute("Stamp") == stamp then
			announceLabel.Visible = false
		end
	end)
end

function HUD.gui(): ScreenGui
	return gui
end

function HUD.start()
	gui = UI.new("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- No UIScale on the ScreenGui itself (that scales from the top-left corner and drags centered
	-- or right-anchored widgets off their spots). Each widget box scales around its own anchor.

	-- Layout follows the genre (Steal From The Rich): app-icon buttons on the left, a Slow Mode
	-- switch, the stats as outlined text in the bottom-left corner, "You earn $X/Day offline!"
	-- across the top, the base lock + next-event timer by the jump button. No dark panels.

	-- ===== left: Store / Event / Index app icons + Slow Mode switch =====
	local left = UI.new("Frame", {
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.fromOffset(190, 260),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.scaleObject(left)
	local function appIcon(
		name: string,
		emoji: string,
		text: string,
		top: Color3,
		bottom: Color3,
		pos: UDim2,
		size: number
	): TextButton
		local b: TextButton = UI.new("TextButton", {
			Name = name,
			Position = pos,
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Text = "",
			AutoButtonColor = true,
			Parent = left,
		}, {
			UI.corner(math.floor(size * 0.24)),
			UI.stroke(Color3.fromRGB(255, 255, 255), 3),
			UI.gradient(top, bottom),
		})
		UI.label({
			Position = UDim2.fromOffset(size * 0.14, size * 0.06),
			Size = UDim2.new(1, -size * 0.28, 0.62, 0),
			Text = emoji,
			Font = Enum.Font.GothamBold,
			Parent = b,
		})
		UI.bigText({
			Name = "Text",
			Position = UDim2.new(0, 2, 1, -size * 0.32),
			Size = UDim2.new(1, -4, 0, size * 0.28),
			Text = text,
			Parent = b,
		}, Color3.fromRGB(20, 20, 30), 2)
		b.Activated:Connect(function()
			Sound.play("Click", 0.4)
			UI.bump(b, 0.12)
		end)
		HUD.buttons[name] = b
		return b
	end
	local function badge(button: GuiObject, text: string)
		local d = UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = Color3.fromRGB(230, 40, 50),
			ZIndex = 3,
			Parent = button,
		}, { UI.corner(13), UI.stroke(Color3.new(1, 1, 1), 2) })
		UI.bigText(
			{ Size = UDim2.fromScale(1, 1), Text = text, ZIndex = 4, Parent = d },
			Color3.fromRGB(90, 0, 0),
			1.5
		)
	end
	local store = appIcon(
		"Shop",
		"🛍️",
		"Store",
		Color3.fromRGB(255, 120, 200),
		Color3.fromRGB(120, 90, 255),
		UDim2.fromOffset(0, 0),
		84
	)
	badge(store, "!")
	local event = appIcon(
		"Event",
		"🎃",
		"Event",
		Color3.fromRGB(255, 170, 40),
		Color3.fromRGB(230, 90, 20),
		UDim2.fromOffset(92, 16),
		62
	)
	local function refreshEvent()
		event.Visible = workspace:GetAttribute("Season") == "Halloween"
	end
	workspace:GetAttributeChangedSignal("Season"):Connect(refreshEvent)
	refreshEvent()
	appIcon(
		"Index",
		"📖",
		"Index",
		Color3.fromRGB(90, 190, 255),
		Color3.fromRGB(40, 90, 220),
		UDim2.fromOffset(0, 92),
		84
	)
	-- Slow Mode switch
	local switch = UI.new("TextButton", {
		Position = UDim2.fromOffset(0, 188),
		Size = UDim2.fromOffset(56, 32),
		BackgroundColor3 = Color3.fromRGB(70, 70, 80),
		Text = "",
		Parent = left,
	}, { UI.corner(10), UI.stroke(Color3.fromRGB(20, 20, 28), 2.5) })
	local knob = UI.new("Frame", {
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = switch,
	}, { UI.corner(8) })
	UI.bigText({
		Position = UDim2.fromOffset(64, 190), -- next to the switch (was stuck at the top)
		Size = UDim2.fromOffset(120, 28),
		Text = "Slow Mode",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = left,
	}, Color3.fromRGB(20, 20, 28), 2)
	local function refreshSwitch()
		local on = player:GetAttribute("SlowMode") == true
		switch.BackgroundColor3 = if on then Color3.fromRGB(70, 210, 80) else Color3.fromRGB(70, 70, 80)
		UI.tween(knob, 0.12, { Position = UDim2.fromOffset(if on then 27 else 3, 3) })
	end
	switch.Activated:Connect(function()
		Sound.play("Click", 0.4)
		Remotes.get(Remotes.Names.SetSlowMode):FireServer(not (player:GetAttribute("SlowMode") == true))
	end)
	player:GetAttributeChangedSignal("SlowMode"):Connect(refreshSwitch)
	refreshSwitch()

	-- ===== bottom-left: stats as outlined text (no panels) =====
	local stats = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -8),
		Size = UDim2.fromOffset(260, 150),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	UI.scaleObject(stats)
	local function statRow(order: number, emoji: string, color: Color3, height: number): (Frame, TextLabel)
		local row = UI.new("Frame", {
			Size = UDim2.new(1, 0, 0, height),
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = stats,
		})
		UI.label({
			Size = UDim2.fromOffset(height, height),
			Text = emoji,
			Font = Enum.Font.GothamBold,
			Parent = row,
		})
		local t = UI.bigText({
			Position = UDim2.fromOffset(height + 4, 0),
			Size = UDim2.new(1, -height - 4, 1, 0),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color,
			Parent = row,
		}, Color3.fromRGB(15, 15, 20), 2.5)
		return row, t
	end
	local boostRow = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = stats,
	})
	local boostL = UI.bigText({
		Size = UDim2.new(1, 0, 1, 0),
		Text = "Friend Boost: +0%",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = boostRow,
	}, Color3.fromRGB(15, 15, 20), 2)
	local _, speedL = statRow(2, "👟", Color3.fromRGB(255, 190, 60), 34)
	local candyRow, candyL = statRow(3, "🍬", Color3.fromRGB(255, 170, 70), 34)
	local cashRow, cashL = statRow(4, "💵", Color3.fromRGB(120, 255, 120), 38)
	local rateL = UI.bigText({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 46, 1, 16),
		Size = UDim2.fromOffset(200, 16),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 230, 120),
		Parent = cashRow,
	}, Color3.fromRGB(15, 15, 20), 1.5)
	local function refreshCandy()
		candyRow.Visible = workspace:GetAttribute("Season") == "Halloween"
		candyL.Text = Format.number(player:GetAttribute("Candy") or 0)
	end
	player:GetAttributeChangedSignal("Candy"):Connect(refreshCandy)
	workspace:GetAttributeChangedSignal("Season"):Connect(refreshCandy)
	refreshCandy()

	-- the cash number counts up/down instead of jumping
	local shownCash = player:GetAttribute("Cash") or 0
	local cashTarget = shownCash
	local counting = false
	local function countCash()
		if counting then
			return
		end
		counting = true
		task.spawn(function()
			local from = shownCash
			local t0 = os.clock()
			while os.clock() - t0 < 0.45 do
				local a = (os.clock() - t0) / 0.45
				a = 1 - (1 - a) * (1 - a)
				shownCash = from + (cashTarget - from) * a
				cashL.Text = Format.cash(shownCash)
				task.wait()
			end
			shownCash = cashTarget
			cashL.Text = Format.cash(shownCash)
			counting = false
			if shownCash ~= (player:GetAttribute("Cash") or 0) then
				cashTarget = player:GetAttribute("Cash") or 0
				countCash()
			end
		end)
	end
	HUD.cashPill = cashRow

	-- ===== top center: "You earn $X/Day offline!" (announcements take its place for a moment) =====
	local topHolder = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(620, 40),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.scaleObject(topHolder)
	local offlineL = UI.bigText({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		RichText = true,
		Parent = topHolder,
	}, Color3.fromRGB(15, 15, 20), 3)
	HUD.offlineLabel = offlineL
	-- while you carry loot the top belongs to RUN!!
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		topHolder.Visible = player:GetAttribute("Carrying") == nil
	end)

	local function refresh()
		cashTarget = player:GetAttribute("Cash") or 0
		countCash()
		local perSec = player:GetAttribute("CashPerSec") or 0
		rateL.Text = "+" .. Format.cash(perSec) .. "/s"
		local boost = player:GetAttribute("FriendBoost") or 0
		boostL.Text = string.format("Friend Boost: +%d%%", math.floor(boost * 100 + 0.5))
		speedL.Text = Format.number(player:GetAttribute("SpeedPoints") or 0)
		local perDay = perSec * Economy.OfflineRate * math.min(86400, Economy.OfflineMaxHours * 3600)
		offlineL.Text = if perDay > 0
			then string.format(
				'You earn <font color="#78FF6E">%s</font>/Day offline! 😈',
				Format.cash(perDay)
			)
			else ""
	end
	for _, a in { "Cash", "CashPerSec", "SpeedPoints", "FriendBoost" } do
		player:GetAttributeChangedSignal(a):Connect(refresh)
	end
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		UI.bump(cashRow, 0.05)
	end)
	refresh()

	-- ===== top right: trails + music =====
	local right = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(132, 62),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 8),
		}),
	})
	UI.scaleObject(right)
	local function smallIcon(name: string, emoji: string, top: Color3, bottom: Color3): TextButton
		local b: TextButton = UI.new("TextButton", {
			Name = name,
			Size = UDim2.fromOffset(60, 60),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Text = "",
			Parent = right,
		}, { UI.corner(14), UI.stroke(Color3.new(1, 1, 1), 3), UI.gradient(top, bottom) })
		UI.label({
			Position = UDim2.fromOffset(9, 9),
			Size = UDim2.new(1, -18, 1, -18),
			Text = emoji,
			Font = Enum.Font.GothamBold,
			Name = "Emoji",
			Parent = b,
		})
		b.Activated:Connect(function()
			Sound.play("Click", 0.4)
			UI.bump(b, 0.12)
		end)
		HUD.buttons[name] = b
		return b
	end
	smallIcon("Trails", "🌈", Color3.fromRGB(255, 150, 255), Color3.fromRGB(140, 80, 255))
	local musicB = smallIcon("Music", "🎵", Color3.fromRGB(190, 140, 255), Color3.fromRGB(110, 60, 220))
	musicB.Activated:Connect(function()
		Music.setEnabled(not Music.isEnabled());
		(musicB:FindFirstChild("Emoji") :: TextLabel).Text = if Music.isEnabled() then "🎵" else "🔇"
	end)

	-- ===== bottom right (left of the jump button): base lock + day/night timer =====
	local lockHolder = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -190, 1, -10),
		Size = UDim2.fromOffset(260, 70),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.scaleObject(lockHolder)
	local lockB: TextButton = UI.new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = Color3.fromRGB(60, 60, 70),
		BackgroundTransparency = 0.25,
		Text = "🔒",
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Parent = lockHolder,
	}, { UI.corner(28), UI.stroke(Color3.new(1, 1, 1), 3) })
	HUD.buttons.Lock = lockB
	local lockText = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(1, -28, 0, 54),
		Size = UDim2.fromOffset(90, 18),
		Text = "LOCK",
		Parent = lockHolder,
	}, Color3.fromRGB(15, 15, 20), 2)
	local eventTimer = UI.bigText({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -66, 0, 28),
		Size = UDim2.fromOffset(190, 30),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = lockHolder,
	}, Color3.fromRGB(15, 15, 20), 2.5)
	lockB.Activated:Connect(function()
		Sound.play("Click", 0.4)
		UI.bump(lockB, 0.15)
		Remotes.get(Remotes.Names.Lock):FireServer()
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local t = workspace:GetServerTimeNow()
			-- day / night: the icon of what comes next + a real countdown (like the genre)
			local endsAt = workspace:GetAttribute("PhaseEndsAt") or 0
			local left = math.max(0, math.ceil(endsAt - t))
			local icon = if workspace:GetAttribute("DayPhase") == "Night" then "☀️" else "🌙"
			eventTimer.Text = if endsAt <= 0
				then ""
				else icon .. " in " .. (if left < 60 then left .. "s" else Format.duration(left))
			local bases = workspace:FindFirstChild("Bases")
			local base = bases and bases:FindFirstChild("Base_" .. tostring(player:GetAttribute("BaseId")))
			if base then
				local lockedUntil = base:GetAttribute("LockedUntil") or 0
				local readyAt = base:GetAttribute("LockReadyAt") or 0
				if player:GetAttribute("Richest") then
					lockText.Text = "👑 NO"
					lockB.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
				elseif t < lockedUntil then
					lockText.Text = math.ceil(lockedUntil - t) .. "s"
					lockB.BackgroundColor3 = Color3.fromRGB(230, 60, 70)
				elseif t < readyAt then
					lockText.Text = math.ceil(readyAt - t) .. "s"
					lockB.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
				else
					lockText.Text = "LOCK"
					lockB.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
				end
			end
		end
	end)

	-- ===== THE RICHEST: one gold line under the top text, only while someone wears the crown =====
	local crownHolder = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 30),
		Size = UDim2.fromOffset(480, 26),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.scaleObject(crownHolder)
	local crownText = UI.bigText({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 215, 60),
		Parent = crownHolder,
	}, Color3.fromRGB(40, 25, 0), 2.5)
	local function refreshCrown()
		local name = workspace:GetAttribute("RichestName")
		crownHolder.Visible = name ~= nil
		if not name then
			crownText.Text = ""
		elseif workspace:GetAttribute("RichestUserId") == player.UserId then
			crownText.Text = "👑 YOU ARE THE RICHEST! +50% cash — everyone wants your loot"
		else
			local g = workspace:GetAttribute("RichestGrowth") or 1
			crownText.Text = "👑 "
				.. tostring(name)
				.. " is THE RICHEST  •  BOUNTY "
				.. Format.cash(workspace:GetAttribute("RichestBounty") or 0)
				.. (if g >= 1.1 then string.format(" (x%.1f)", g) else "")
		end
	end
	for _, a in { "RichestName", "RichestUserId", "RichestBounty", "RichestGrowth" } do
		workspace:GetAttributeChangedSignal(a):Connect(refreshCrown)
	end
	refreshCrown()

	-- toasts (center, below the crown bar)
	toastHolder = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(520, 170),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	UI.scaleObject(toastHolder)

	-- the label gets its own "Bump" UIScale, so the screen scale sits on a holder frame
	local announceHolder = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(700, 40),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.scaleObject(announceHolder)
	announceLabel = UI.bigText({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Visible = false,
		Parent = announceHolder,
	}, DARK, 3)
	announceLabel:GetPropertyChangedSignal("Visible"):Connect(function()
		HUD.offlineLabel.Visible = not announceLabel.Visible
	end)

	Remotes.get(Remotes.Names.Notice).OnClientEvent:Connect(function(text: string, kind: string)
		HUD.toast(text, kind)
	end)
	Remotes.get(Remotes.Names.Announce).OnClientEvent
		:Connect(function(text: string, color: { number }, sound: string?)
			HUD.announce(text, color, sound)
		end)

	-- server event banner with a real countdown (ends at workspace.EventEnds, server time)
	local eventHolder = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(300, 34),
		BackgroundColor3 = Color3.fromRGB(30, 20, 50),
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	}, { UI.corner(17), UI.stroke(Color3.fromRGB(255, 255, 255), 2.5) })
	UI.scaleObject(eventHolder)
	local eventText = UI.bigText({
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 1, -8),
		Text = "",
		Parent = eventHolder,
	})
	task.spawn(function()
		while true do
			task.wait(0.25)
			local name = workspace:GetAttribute("EventName")
			local ends = workspace:GetAttribute("EventEnds") or 0
			local left = ends - workspace:GetServerTimeNow()
			if name and left > 0 then
				eventHolder.Visible = true
				eventText.Text = tostring(name) .. "  " .. Format.duration(left)
				local id = workspace:GetAttribute("EventId")
				local stroke = eventHolder:FindFirstChildOfClass("UIStroke") :: UIStroke
				stroke.Color = if id == "GoldRush"
					then Color3.fromRGB(255, 210, 60)
					elseif id == "GuardStrike" then Color3.fromRGB(120, 200, 255)
					else Color3.fromRGB(110, 255, 130)
				eventText.TextColor3 = stroke.Color
			else
				eventHolder.Visible = false
			end
		end
	end)
	toastHolder.Position = UDim2.new(0.5, 0, 0, 96)

	-- coins fly from the collect pad (or the screen center) into the cash counter
	Remotes.get(Remotes.Names.CashFX).OnClientEvent:Connect(function(amount: number, from: Vector3?)
		local camera = workspace.CurrentCamera
		local start = Vector2.new(gui.AbsoluteSize.X / 2, gui.AbsoluteSize.Y * 0.55)
		if from and camera then
			local p, onScreen = camera:WorldToViewportPoint(from)
			if onScreen then
				-- viewport space includes the top bar inset, this gui doesn't
				start = Vector2.new(p.X, p.Y - (camera.ViewportSize.Y - gui.AbsoluteSize.Y))
			end
		end
		local pill = HUD.cashPill
		local target = pill.AbsolutePosition + pill.AbsoluteSize * Vector2.new(0.2, 0.5)
		local n = math.clamp(math.floor(math.log10(math.max(10, amount)) * 2), 4, 14)
		for i = 1, n do
			task.delay(i * 0.04, function()
				local coin = UI.label({
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(
						start.X + math.random(-40, 40),
						start.Y + math.random(-30, 30)
					),
					Size = UDim2.fromOffset(30, 30),
					Text = "🪙",
					Font = Enum.Font.GothamBold,
					ZIndex = 20,
					Parent = gui,
				})
				local tw = UI.tween(
					coin,
					0.55,
					{ Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(18, 18) },
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.In
				)
				tw.Completed:Connect(function()
					coin:Destroy()
					Sound.play("Coin", 0.25, 1 + i * 0.03)
					UI.bump(pill, 0.08)
				end)
			end)
		end
	end)

	-- chat tags: 👑 for the richest, 💎 for VIP (client-side display only)
	pcall(function()
		TextChatService.OnIncomingMessage = function(message: TextChatMessage)
			local props = Instance.new("TextChatMessageProperties")
			local source = message.TextSource
			local speaker = source and Players:GetPlayerByUserId(source.UserId)
			if speaker then
				local tags = ""
				if workspace:GetAttribute("RichestUserId") == speaker.UserId then
					tags ..= "<font color='#FFD23C'>[👑 RICHEST]</font> "
				end
				if speaker:GetAttribute("Pass_VIP") then
					tags ..= "<font color='#78E6FF'>[💎 VIP]</font> "
				end
				if tags ~= "" then
					props.PrefixText = tags .. message.PrefixText
				end
			end
			return props
		end
	end)
	-- welcome back card: what you earned while away + what your plot makes offline per day
	Remotes.get(Remotes.Names.Offline).OnClientEvent
		:Connect(function(earned: number, seconds: number, perDay: number?)
			local card = UI.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(420, 210),
				BackgroundColor3 = Color3.fromRGB(25, 30, 45),
				BackgroundTransparency = 0.05,
				ZIndex = 30,
				Parent = gui,
			}, { UI.corner(22), UI.stroke(Color3.fromRGB(120, 255, 130), 4) })
			UI.scaleObject(card)
			UI.bigText({
				Position = UDim2.fromOffset(12, 10),
				Size = UDim2.new(1, -24, 0, 34),
				Text = "💤 WELCOME BACK!",
				TextColor3 = Color3.fromRGB(255, 215, 60),
				ZIndex = 31,
				Parent = card,
			})
			UI.bigText({
				Position = UDim2.fromOffset(12, 50),
				Size = UDim2.new(1, -24, 0, 46),
				Text = "+" .. Format.cash(earned),
				TextColor3 = Color3.fromRGB(120, 255, 130),
				ZIndex = 31,
				Parent = card,
			})
			UI.label({
				Position = UDim2.fromOffset(12, 98),
				Size = UDim2.new(1, -24, 0, 40),
				Text = "earned in " .. Format.duration(seconds) .. (if perDay
					then "\nYour plot earns " .. Format.cash(perDay) .. "/day offline!"
					else ""),
				Font = Enum.Font.GothamBold,
				ZIndex = 31,
				Parent = card,
			})
			local ok = UI.new("TextButton", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -12),
				Size = UDim2.fromOffset(180, 48),
				BackgroundColor3 = Color3.fromRGB(70, 210, 90),
				Text = "",
				ZIndex = 31,
				Parent = card,
			}, { UI.corner(14), UI.stroke(Color3.fromRGB(20, 90, 30), 3) })
			UI.bigText({
				Position = UDim2.fromOffset(6, 6),
				Size = UDim2.new(1, -12, 1, -12),
				Text = "NICE!",
				ZIndex = 32,
				Parent = ok,
			}, Color3.fromRGB(20, 90, 30), 2.5)
			Sound.play("Collect", 0.7)
			local function close()
				if card.Parent then
					card:Destroy()
				end
			end
			ok.Activated:Connect(close)
			task.delay(12, close)
		end)
	Remotes.get(Remotes.Names.Crown).OnClientEvent:Connect(function(gained: boolean)
		if gained then
			Sound.play("Crown", 0.7)
			HUD.announce("👑 YOU ARE THE RICHEST! Everyone can rob you now... 👑", { 255, 215, 60 })
		else
			HUD.toast("You lost the crown!", "bad")
		end
	end)
end

return HUD
