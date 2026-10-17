--!strict
-- DAILY STREAK calendar: 7 day-pips with their known prizes (the server sends them in the
-- "DailyInfo" attribute as JSON; nothing is worked out here), today's highlighted.
-- Daily.strip builds the strip (top of the Jobs panel); when the daily reward lands a compact
-- card with the same strip slides in at the top for a few seconds (tap it to close).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)

local Client = script.Parent.Parent
local UI = require(Client.Util.UI)
local Panel = require(Client.Util.Panel)
local Sound = require(Client.Util.Sound)
local LootToast = require(Client.Util.LootToast)

local Daily = {}

local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 200, 70)
local GREEN = Color3.fromRGB(90, 220, 110)
local BRONZE = Color3.fromRGB(196, 150, 110)

export type Info = {
	streak: number,
	claimed: boolean,
	tomorrow: number,
	days: { { day: number, noodles: number, dynamite: number, uniform: string? } },
	uniformName: string,
	gift: number,
	giftEvery: number,
}

function Daily.info(): Info?
	local raw = player:GetAttribute("DailyInfo")
	if typeof(raw) ~= "string" then
		return nil
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if ok and typeof(data) == "table" and typeof(data.days) == "table" then
		return data :: any
	end
	return nil
end

-- "Come back tomorrow for day 4 (+🍜 1,200)"
function Daily.tomorrowText(info: Info): string
	local nextDay = info.days[info.tomorrow]
	local prize = if nextDay then " (+" .. Format.noodles(nextDay.noodles) .. ")" else ""
	if info.claimed and info.tomorrow == info.streak then
		return "Full streak! Come back tomorrow to keep it" .. prize
	elseif info.claimed then
		return "Come back tomorrow for day " .. info.tomorrow .. prize
	end
	return "Day " .. info.streak .. " is on its way!"
end

-- One pip: DAY n on top, the prize under it. done = already claimed in this streak.
local function pip(parent: Instance, d: any, today: boolean, done: boolean, count: number)
	local fill = if today then GOLD elseif done then GREEN else Color3.new(1, 1, 1)
	local f = UI.new("Frame", {
		Name = "Day" .. d.day,
		LayoutOrder = d.day,
		Size = UDim2.new(1 / count, -6, 1, 0),
		BackgroundColor3 = fill,
		BackgroundTransparency = if today then 0.15 elseif done then 0.72 else 0.93,
		Parent = parent,
	}, {
		UI.corner(10),
		-- (the exclusive day gets a bronze rim)
		UI.stroke(
			if today then Color3.fromRGB(255, 240, 180) elseif d.uniform then BRONZE else Color3.new(1, 1, 1),
			if today or d.uniform then 2 else 1,
			if today then 0 elseif d.uniform then 0.2 else 0.88
		),
	})
	local ink = if today then UI.INK else Panel.TEXT
	Panel.text("title", if today then "TODAY" else "DAY " .. d.day, {
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = if today then UI.INK elseif done then GREEN else Panel.MUTED,
		Parent = f,
	})
	local extra = ""
	if (d.dynamite or 0) > 0 then
		extra ..= "🧨"
	end
	if d.uniform then
		extra ..= "⛓️"
	end
	Panel.text("title", if extra ~= "" then extra else if done then "✓" else "🍜", {
		Position = UDim2.fromOffset(0, 19),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = if done and extra == "" then GREEN else ink,
		Parent = f,
	})
	Panel.text("title", Format.number(d.noodles), {
		Position = UDim2.new(0, 2, 1, -20),
		Size = UDim2.new(1, -4, 0, 16),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = ink,
		Parent = f,
	})
end

-- Fills `holder` (a Frame) with the 7 pips + a caption under them. Returns false without data.
function Daily.fill(holder: Frame, info: Info?): boolean
	for _, c in holder:GetChildren() do
		c:Destroy()
	end
	if not info then
		return false
	end
	local pips = UI.new("Frame", {
		Name = "Pips",
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 6, 0, 62),
		BackgroundTransparency = 1,
		Parent = holder,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for _, d in info.days do
		pip(pips, d, d.day == info.streak, d.day < info.streak, #info.days)
	end
	local last = info.days[#info.days]
	local caption = Daily.tomorrowText(info)
	if last and last.uniform then
		caption ..= "  ·  Day " .. last.day .. ": " .. info.uniformName .. " uniform"
	end
	Panel.text("desc", caption, {
		Name = "Caption",
		Position = UDim2.fromOffset(2, 74),
		Size = UDim2.new(1, -4, 0, 16),
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = holder,
	})
	return true
end

-- The strip as a panel row (Jobs panel): title line + pips + caption.
function Daily.strip(body: Instance, order: number): Frame
	local r = Panel.row(body, order, 122)
	local info = Daily.info()
	Panel.text(
		"title",
		"📅 Daily streak" .. (if info then ": day " .. info.streak .. " of " .. #info.days else ""),
		{
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -24, 0, 18),
			TextSize = 14,
			Parent = r,
		}
	)
	local holder = UI.new("Frame", {
		Position = UDim2.fromOffset(10, 22),
		Size = UDim2.new(1, -20, 1, -24),
		BackgroundTransparency = 1,
		Parent = r,
	})
	Daily.fill(holder, info)
	return r
end

-- ===== the card when the daily reward lands =====

local card: TextButton? = nil

local function showCard(text: string)
	local info = Daily.info()
	if not info then
		return
	end
	if card then
		card:Destroy()
	end
	local gui = player:WaitForChild("PlayerGui"):FindFirstChild("DailyCard")
		or UI.new("ScreenGui", {
			Name = "DailyCard",
			ResetOnSpawn = false,
			DisplayOrder = 5,
			Parent = player:WaitForChild("PlayerGui"),
		})
	local c: TextButton = UI.new("TextButton", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.fromOffset(470, 150),
		BackgroundColor3 = Panel.BG,
		BackgroundTransparency = 0.08,
		AutoButtonColor = false,
		Text = "",
		Parent = gui,
	}, {
		UI.corner(14),
		UI.stroke(GOLD, 1.5, 0.35),
	})
	UI.scaleObject(c)
	card = c
	Panel.text("title", "📅 DAY " .. info.streak .. " STREAK", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(0.5, -14, 0, 20),
		TextSize = 16,
		TextColor3 = GOLD,
		Parent = c,
	})
	-- the reward line from the server ("DAY 3 STREAK! +🍜 900 + 🧨"), minus the repeated head
	local prize = string.gsub(text, "^DAY %d+ STREAK! ", "")
	Panel.text("title", prize, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.new(0.5, -14, 0, 20),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = c,
	})
	local holder = UI.new("Frame", {
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.new(1, -24, 0, 94),
		BackgroundTransparency = 1,
		Parent = c,
	})
	Daily.fill(holder, info)
	Panel.text("desc", "Tap to close · see it any time in 📋 Jobs", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -6),
		Size = UDim2.new(1, -28, 0, 14),
		TextSize = 11,
		Parent = c,
	})
	local function close()
		if card == c then
			card = nil
		end
		UI.tween(c, 0.2, { Position = UDim2.new(0.5, 0, 0, -160) })
		task.delay(0.2, function()
			c:Destroy()
		end)
	end
	c.Activated:Connect(close)
	c.Position = UDim2.new(0.5, 0, 0, 20)
	UI.tween(c, 0.3, { Position = UDim2.new(0.5, 0, 0, 44) }, Enum.EasingStyle.Back)
	local pips = holder:FindFirstChild("Pips")
	local today = pips and pips:FindFirstChild("Day" .. info.streak)
	if today and today:IsA("GuiObject") then
		UI.bump(today, 0.25)
	end
	Sound.play("Upgrade", 0.6, 1.05)
	task.delay(7, function()
		if c.Parent then
			close()
		end
	end)
end

-- The daily reward landed (Controllers/Moments hands it over: it owns the Reward listener, so a
-- reward fired while the client was still loading isn't lost to a second listener).
function Daily.show(text: string)
	task.spawn(function()
		-- the attribute rides along with the event; the first-join tour goes first
		task.wait(0.2)
		local t0 = os.clock()
		while LootToast.isPaused() and os.clock() - t0 < 90 do
			task.wait(0.5)
		end
		showCard(text)
	end)
end

return Daily
