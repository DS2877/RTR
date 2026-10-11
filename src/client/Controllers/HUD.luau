--!strict
-- Main HUD (mobile first): currency pills top-left, menu buttons on the left edge, the
-- 👑 richest bar at the top center, Lock + Slow Mode buttons, toasts and announcements.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Progression = require(Shared.Progression)
local Products = require(Shared.Config.Products)

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

local function pill(parent: Instance, order: number, emoji: string, color: Color3): TextLabel
	local f = UI.new("Frame", {
		Size = UDim2.fromOffset(190, 40),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.25,
		LayoutOrder = order,
		Parent = parent,
	}, { UI.corner(20), UI.stroke(color, 2.5) })
	UI.label({
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.fromOffset(32, 32),
		Text = emoji,
		Font = Enum.Font.GothamBold,
		Parent = f,
	})
	return UI.bigText({
		Position = UDim2.fromOffset(42, 5),
		Size = UDim2.new(1, -50, 1, -10),
		Text = "0",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color,
		Parent = f,
	})
end

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
		Size = UDim2.fromOffset(74, 74),
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
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 0, 42),
		Text = emoji,
		Font = Enum.Font.GothamBold,
		Parent = b,
	})
	UI.bigText({
		Name = "Text",
		Position = UDim2.new(0, 2, 1, -26),
		Size = UDim2.new(1, -4, 0, 22),
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

	-- currency pills (top-left)
	local box = UI.new("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(360, 140),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.scaleObject(box)
	local pills = UI.new("Frame", {
		Size = UDim2.fromOffset(200, 140),
		BackgroundTransparency = 1,
		Parent = box,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local cashL = pill(pills, 1, "💵", Color3.fromRGB(120, 255, 120))
	local rateL = pill(pills, 2, "📈", Color3.fromRGB(255, 230, 110))
	local speedL = pill(pills, 3, "⚡", Color3.fromRGB(110, 210, 255))

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
	HUD.cashPill = cashL.Parent :: GuiObject

	-- second column next to the pills: a speed deal chip and (during the season) the candy count
	local deal = UI.new("TextButton", {
		Position = UDim2.fromOffset(200, 0),
		Size = UDim2.fromOffset(150, 40),
		BackgroundColor3 = Color3.fromRGB(40, 190, 90),
		Text = "",
		AutoButtonColor = true,
		Visible = false,
		Parent = box,
	}, { UI.corner(20), UI.stroke(Color3.fromRGB(10, 80, 30), 2.5) })
	local dealText = UI.bigText({
		Position = UDim2.fromOffset(8, 5),
		Size = UDim2.new(1, -16, 1, -10),
		Text = "",
		Parent = deal,
	}, Color3.fromRGB(10, 60, 20), 2)
	local speedDeal = nil
	for _, p in Products.Items do
		if p.kind == "speed" and p.id > 0 and (not speedDeal or p.price < speedDeal.price) then
			speedDeal = p
		end
	end
	if speedDeal then
		deal.Visible = true
		dealText.Text = "⚡ +SPEED  R$" .. speedDeal.price
		deal.Activated:Connect(function()
			Sound.play("Click", 0.4)
			MarketplaceService:PromptProductPurchase(player, speedDeal.id)
		end)
	end
	local candyPill = pill(pills, 4, "🍬", Color3.fromRGB(255, 160, 60))
	-- the candy pill sits in its own holder so the list layout doesn't stack it under the others
	local candyFrame = candyPill.Parent :: Frame
	local holder = UI.new("Frame", {
		Position = UDim2.fromOffset(200, 92),
		Size = UDim2.fromOffset(150, 40),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = box,
	})
	candyFrame.Size = UDim2.fromScale(1, 1)
	candyFrame.Parent = holder
	local function refreshCandy()
		holder.Visible = workspace:GetAttribute("Season") == "Halloween"
		candyPill.Text = Format.number(player:GetAttribute("Candy") or 0)
	end
	player:GetAttributeChangedSignal("Candy"):Connect(refreshCandy)
	workspace:GetAttributeChangedSignal("Season"):Connect(refreshCandy)
	refreshCandy()

	local function refresh()
		cashTarget = player:GetAttribute("Cash") or 0
		countCash()
		local boost = player:GetAttribute("FriendBoost") or 0
		rateL.Text = Format.cash(player:GetAttribute("CashPerSec") or 0)
			.. "/s"
			.. (if boost > 0 then string.format("  👥+%d%%", math.floor(boost * 100 + 0.5)) else "")
		local pts = player:GetAttribute("SpeedPoints") or 0
		speedL.Text = Format.number(pts) .. "  (" .. math.floor(Progression.walkSpeed(pts)) .. ")"
	end
	for _, a in { "Cash", "CashPerSec", "SpeedPoints", "FriendBoost" } do
		player:GetAttributeChangedSignal(a):Connect(refresh)
	end
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		UI.bump(cashL.Parent :: GuiObject, 0.06)
	end)
	refresh()

	-- menu buttons (left edge, 2 columns)
	local menu = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 40),
		Size = UDim2.fromOffset(160, 242),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(74, 74),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	UI.scaleObject(menu)
	HUD.button("Shop", "🛒", "SHOP", Color3.fromRGB(255, 80, 100), menu, 1)
	HUD.button("Index", "📖", "INDEX", Color3.fromRGB(80, 170, 255), menu, 2)
	local lockB = HUD.button("Lock", "🔒", "LOCK", Color3.fromRGB(255, 190, 50), menu, 3)
	local slowB = HUD.button("Slow", "🐢", "SLOW", Color3.fromRGB(120, 220, 120), menu, 4)
	local musicB = HUD.button("Music", "🎵", "MUSIC", Color3.fromRGB(190, 120, 255), menu, 5)
	musicB.Activated:Connect(function()
		Music.setEnabled(not Music.isEnabled());
		(musicB:FindFirstChild("Text") :: TextLabel).Text = if Music.isEnabled() then "MUSIC" else "OFF"
		musicB.BackgroundColor3 = if Music.isEnabled()
			then Color3.fromRGB(190, 120, 255)
			else Color3.fromRGB(150, 150, 150)
	end)

	lockB.Activated:Connect(function()
		Remotes.get(Remotes.Names.Lock):FireServer()
	end)
	slowB.Activated:Connect(function()
		Remotes.get(Remotes.Names.SetSlowMode):FireServer(not (player:GetAttribute("SlowMode") == true))
	end)
	player:GetAttributeChangedSignal("SlowMode"):Connect(function()
		local on = player:GetAttribute("SlowMode") == true;
		(slowB:FindFirstChild("Text") :: TextLabel).Text = if on then "SLOW ON" else "SLOW"
		slowB.BackgroundColor3 = if on then Color3.fromRGB(60, 200, 90) else Color3.fromRGB(120, 220, 120)
	end)

	-- lock status text
	local lockText = lockB:FindFirstChild("Text") :: TextLabel
	task.spawn(function()
		while true do
			task.wait(0.25)
			local bases = workspace:FindFirstChild("Bases")
			local base = bases and bases:FindFirstChild("Base_" .. tostring(player:GetAttribute("BaseId")))
			if base then
				local t = workspace:GetServerTimeNow()
				local lockedUntil = base:GetAttribute("LockedUntil") or 0
				local readyAt = base:GetAttribute("LockReadyAt") or 0
				if player:GetAttribute("Richest") then
					lockText.Text = "👑 NO"
					lockB.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
				elseif t < lockedUntil then
					lockText.Text = math.ceil(lockedUntil - t) .. "s"
					lockB.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
				elseif t < readyAt then
					lockText.Text = "in " .. math.ceil(readyAt - t) .. "s"
					lockB.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
				else
					lockText.Text = "LOCK"
					lockB.BackgroundColor3 = Color3.fromRGB(255, 190, 50)
				end
			end
		end
	end)

	-- 👑 richest bar (top center)
	local crownBar = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(360, 36),
		BackgroundColor3 = Color3.fromRGB(40, 30, 10),
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, { UI.corner(18), UI.stroke(Color3.fromRGB(255, 205, 40), 3) })
	UI.scaleObject(crownBar)
	local crownText = UI.bigText({
		Position = UDim2.fromOffset(10, 5),
		Size = UDim2.new(1, -20, 1, -10),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 215, 60),
		Parent = crownBar,
	})
	local function refreshCrown()
		local name = workspace:GetAttribute("RichestName")
		if not name then
			crownText.Text = "👑 No Richest yet — get rich!"
		elseif workspace:GetAttribute("RichestUserId") == player.UserId then
			crownText.Text = "👑 YOU ARE THE RICHEST! +50% cash"
		else
			local g = workspace:GetAttribute("RichestGrowth") or 1
			crownText.Text = "👑 "
				.. tostring(name)
				.. "  •  BOUNTY "
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
		Position = UDim2.new(0.5, 0, 0, 46),
		Size = UDim2.fromOffset(700, 44),
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
		Position = UDim2.new(0.5, 0, 0, 92),
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
	toastHolder.Position = UDim2.new(0.5, 0, 0, 132)

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
