--!strict
-- Main HUD (mobile first): currency pills top-left, menu buttons on the left edge, the
-- 👑 richest bar at the top center, Lock + Slow Mode buttons, toasts and announcements.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Progression = require(Shared.Progression)

local UI = require(script.Parent.Parent.Util.UI)
local Sound = require(script.Parent.Parent.Util.Sound)

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

function HUD.announce(text: string, color: { number }?)
	if not announceLabel then
		return
	end
	announceLabel.Text = text
	announceLabel.TextColor3 = if color then UI.rgb(color) else Color3.fromRGB(255, 215, 60)
	announceLabel.Visible = true
	announceLabel.TextTransparency = 0
	UI.bump(announceLabel, 0.3)
	Sound.play("Announce", 0.35)
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
	UI.autoScale(gui)

	-- currency pills (top-left)
	local pills = UI.new("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(200, 140),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local cashL = pill(pills, 1, "💵", Color3.fromRGB(120, 255, 120))
	local rateL = pill(pills, 2, "📈", Color3.fromRGB(255, 230, 110))
	local speedL = pill(pills, 3, "⚡", Color3.fromRGB(110, 210, 255))

	local function refresh()
		cashL.Text = Format.cash(player:GetAttribute("Cash") or 0)
		rateL.Text = Format.cash(player:GetAttribute("CashPerSec") or 0) .. "/s"
		local pts = player:GetAttribute("SpeedPoints") or 0
		speedL.Text = Format.number(pts) .. "  (" .. math.floor(Progression.walkSpeed(pts)) .. ")"
	end
	for _, a in { "Cash", "CashPerSec", "SpeedPoints" } do
		player:GetAttributeChangedSignal(a):Connect(refresh)
	end
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		UI.bump(cashL.Parent :: GuiObject, 0.06)
	end)
	refresh()

	-- menu buttons (left edge, 2x2)
	local menu = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 30),
		Size = UDim2.fromOffset(160, 160),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(74, 74),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	HUD.button("Shop", "🛒", "SHOP", Color3.fromRGB(255, 80, 100), menu, 1)
	HUD.button("Index", "📖", "INDEX", Color3.fromRGB(80, 170, 255), menu, 2)
	local lockB = HUD.button("Lock", "🔒", "LOCK", Color3.fromRGB(255, 190, 50), menu, 3)
	local slowB = HUD.button("Slow", "🐢", "SLOW", Color3.fromRGB(120, 220, 120), menu, 4)

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
			crownText.Text = "👑 "
				.. tostring(name)
				.. "  •  BOUNTY "
				.. Format.cash(workspace:GetAttribute("RichestBounty") or 0)
		end
	end
	for _, a in { "RichestName", "RichestUserId", "RichestBounty" } do
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

	announceLabel = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 46),
		Size = UDim2.fromOffset(700, 44),
		Text = "",
		Visible = false,
		Parent = gui,
	}, DARK, 3)

	Remotes.get(Remotes.Names.Notice).OnClientEvent:Connect(function(text: string, kind: string)
		HUD.toast(text, kind)
	end)
	Remotes.get(Remotes.Names.Announce).OnClientEvent:Connect(function(text: string, color: { number })
		HUD.announce(text, color)
	end)
	Remotes.get(Remotes.Names.Offline).OnClientEvent:Connect(function(earned: number, seconds: number)
		HUD.announce(
			"💤 Welcome back! Your loot earned "
				.. Format.cash(earned)
				.. " in "
				.. Format.duration(seconds),
			{ 120, 255, 130 }
		)
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
