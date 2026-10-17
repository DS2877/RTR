--!strict
-- Moments that make progress felt:
--  * NEW TOOL / BRUSH / BACKPACK: the item pops big in the middle for a beat with what it changes
--    ("BRICK  18 → 9 hits"), and your first punch with a new tool lands extra hard (DigFX).
--  * "+N 🍜" floats up from the vacuum while rubble flies in: what the backpack is worth now.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Upgrades = require(Shared.Config.Upgrades)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Format)

local Util = script.Parent.Parent.Util
local UI = require(Util.UI)
local Sound = require(Util.Sound)
local DigFX = require(script.Parent.DigFX)

local Juice = {}

local player = Players.LocalPlayer

local function attr(name: string, default: number): number
	local v = player:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

-- ===== the new-item moment =====

local gui: ScreenGui
local card: Frame
local icon: TextLabel
local nameLabel: TextLabel
local subLabel: TextLabel
local cardScale: UIScale
local token = 0

local function build()
	gui = UI.new("ScreenGui", {
		Name = "Juice",
		ResetOnSpawn = false,
		DisplayOrder = 8, -- above the shop panel you just bought it in
		IgnoreGuiInset = true,
		Parent = player:WaitForChild("PlayerGui"),
	})
	card = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(360, 150),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	UI.scaleObject(card)
	cardScale = UI.new("UIScale", { Name = "Pop", Parent = card })
	icon = UI.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(90, 80),
		BackgroundTransparency = 1,
		Text = "",
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Parent = card,
	})
	nameLabel = UI.bigText({
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 34),
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		Parent = card,
	}, UI.INK, 2)
	subLabel = UI.bigText({
		Position = UDim2.fromOffset(0, 116),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		TextColor3 = Color3.fromRGB(150, 240, 160),
		Parent = card,
	}, UI.INK, 1.6)
end

local function show(emoji: string, title: string, sub: string)
	token += 1
	local mine = token
	icon.Text = emoji
	nameLabel.Text = title
	subLabel.Text = sub
	for _, l in { icon, nameLabel, subLabel } do
		l.TextTransparency = 0
	end
	card.Visible = true
	cardScale.Scale = 0.35
	icon.Rotation = -12
	TweenService:Create(cardScale, TweenInfo.new(0.32, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(icon, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Rotation = 0 }):Play()
	Sound.play("Upgrade", 0.55, 1.05)
	task.delay(1.7, function()
		if token ~= mine then
			return
		end
		for _, l in { icon, nameLabel, subLabel } do
			TweenService:Create(l, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		end
		TweenService:Create(cardScale, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Scale = 0.85 }):Play()
		task.delay(0.36, function()
			if token == mine then
				card.Visible = false
			end
		end)
	end)
end

local function hits(hp: number, power: number): number
	return math.max(1, math.ceil(hp / math.max(1, power)))
end

local function onLevel(track: string, from: number, to: number)
	if to <= from then
		return -- (an escape resets you: no party for that)
	end
	local item = (Upgrades :: any)[track][to]
	if not item then
		return
	end
	if track == "Tools" then
		local old = (Upgrades :: any).Tools[from]
		local zone = Zones[math.clamp(attr("Zone", 1), 1, #Zones)]
		-- (Stats.sync writes Power before Tools, so Power is already the new punch)
		local newPower = math.max(1, attr("Power", 1))
		local ratio = item.value / math.max(1, old and old.value or 1)
		local before = hits(zone.hp, newPower / ratio)
		local after = hits(zone.hp, newPower)
		show(
			item.emoji,
			string.upper(item.name),
			if after < before
				then string.format("%s  %d → %d hits", zone.name, before, after)
				else string.format("x%s punch", Format.number(item.value))
		)
		DigFX.empowerNext = true
	elseif track == "Brushes" then
		show(
			item.emoji,
			string.upper(item.name) .. " BRUSH",
			string.format("%d blocks per punch", #item.cells)
		)
	elseif track == "Backpack" then
		local old = (Upgrades :: any).Backpack[from]
		show(
			item.emoji,
			string.upper(item.name),
			string.format(
				"%s → %s rubble",
				Format.number(old and old.value or 0),
				Format.number(item.value)
			)
		)
	end
end

-- ===== "+N 🍜" from the vacuum =====

local pending = 0
local flushAt = 0
local function flushWorth()
	if pending <= 0 then
		return
	end
	local character = player.Character
	local r = character and character:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then
		local at = r.Position + Vector3.new(0, 2.6, 0) + r.CFrame.LookVector * 1.5
		DigFX.popText(
			at,
			"+" .. Format.number(math.floor(pending + 0.5)) .. " 🍜",
			Color3.fromRGB(255, 215, 80),
			3.2,
			0.9
		)
	end
	pending = 0
end

function Juice.start()
	build()
	local levels: { [string]: number } = {}
	for _, track in { "Tools", "Brushes", "Backpack" } do
		levels[track] = attr(track, 1)
		player:GetAttributeChangedSignal(track):Connect(function()
			local now = attr(track, 1)
			local was = levels[track]
			levels[track] = now
			onLevel(track, was, now)
		end)
	end
	local lastValue = attr("BagValue", 0)
	player:GetAttributeChangedSignal("BagValue"):Connect(function()
		local v = attr("BagValue", 0)
		local gain = v - lastValue
		lastValue = v
		if gain > 0 then
			-- worth in Noodles once dumped (BagValue x every multiplier), gathered into one pop
			pending += gain * attr("NoodleMult", 1)
			local now = os.clock()
			if now >= flushAt then
				flushAt = now + 0.45
				task.delay(0.45, flushWorth)
			end
		end
	end)
end

return Juice
