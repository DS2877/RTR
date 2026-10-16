--!strict
-- The COMBO counter above the PUNCH button: the chain length (server-counted, Remotes.Combo), the
-- tier name and multiplier, and a bar that drains over World.ComboWindow (frozen while you
-- vacuum). It bumps on every punch, pops on a new tier, and when the chain runs out it shows what
-- the chain earned. Tiny chains (under ShowAt) stay hidden.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local Client = script.Parent.Parent
local UI = require(Client.Util.UI)
local Sound = require(Client.Util.Sound)
local Shake = require(Client.Util.Shake)
local DigFX = require(script.Parent.DigFX)
local HUD = require(script.Parent.HUD)

local Combo = {}

local SHOW_AT = 5
local TIER_COLORS = {
	Color3.fromRGB(245, 246, 250),
	Color3.fromRGB(255, 220, 90),
	Color3.fromRGB(255, 150, 50),
	Color3.fromRGB(255, 80, 110),
	Color3.fromRGB(180, 120, 255),
}

function Combo.start()
	local parent = HUD.buttons
	if not parent then
		return
	end
	-- above the PUNCH button (its center sits at 75, 180 in the 280 x 260 button frame)
	local box: Frame = UI.new("Frame", {
		Name = "Combo",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(1, -205, 1, -138),
		Size = UDim2.fromOffset(150, 74),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	})
	local scale = UI.new("UIScale", { Parent = box })
	local count: TextLabel = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		Font = Enum.Font.GothamBlack,
		TextSize = 36,
		TextColor3 = TIER_COLORS[1],
		Text = "",
		Parent = box,
	}, { UI.stroke(Color3.fromRGB(20, 12, 4), 2.5, 0) })
	local tierText: TextLabel = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextColor3 = TIER_COLORS[1],
		Text = "",
		Parent = box,
	}, { UI.stroke(Color3.fromRGB(20, 12, 4), 1.5, 0) })
	local track = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(90, 4),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Parent = box,
	}, { UI.corner(2) })
	local fill: Frame = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = TIER_COLORS[1],
		BorderSizePixel = 0,
		Parent = track,
	}, { UI.corner(2) })

	local hits, tier, bonus = 0, 1, 0
	local left = 0 -- seconds of chain left (paused while vacuuming)
	local alive = false

	local function paint()
		local c = TIER_COLORS[tier] or TIER_COLORS[#TIER_COLORS]
		local t = World.ComboTiers[tier]
		count.Text = "x" .. hits
		count.TextColor3 = c
		tierText.TextColor3 = c
		fill.BackgroundColor3 = c
		tierText.Text = if t.name ~= "" then string.format("%s  ×%s", t.name, tostring(t.mult)) else "COMBO"
	end

	-- the chain ran out: a short summary, then away
	local function finish()
		alive = false
		if hits >= World.ComboTiers[2].hits then
			count.Text = "COMBO " .. hits
			tierText.Text = if bonus > 0 then "+" .. Format.number(bonus) .. " 🍜 bonus" else ""
			fill.Size = UDim2.fromScale(0, 1)
			scale.Scale = 1.15
			UI.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			task.delay(1.4, function()
				if not alive then
					box.Visible = false
				end
			end)
		else
			box.Visible = false
		end
		hits, tier, bonus = 0, 1, 0
	end

	Remotes.get(Remotes.Names.Combo).OnClientEvent:Connect(function(n: number, t: number, b: number)
		if typeof(n) ~= "number" or typeof(t) ~= "number" then
			return
		end
		local tierUp = t > tier and n > 1
		hits, tier, bonus = n, math.clamp(t, 1, #World.ComboTiers), if typeof(b) == "number" then b else 0
		left = World.ComboWindow
		alive = true
		if hits < SHOW_AT then
			return
		end
		box.Visible = true
		paint()
		if tierUp then
			-- a new tier: big pop, a sting, a kick
			scale.Scale = 1.6
			UI.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			Sound.play("Upgrade", 0.45, 0.9 + tier * 0.12)
			Shake.kick(0.25)
			local character = Players.LocalPlayer.Character
			local head = character and character:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				DigFX.popText(
					head.Position + Vector3.new(0, 2, 0),
					World.ComboTiers[tier].name,
					TIER_COLORS[tier],
					6,
					1.2
				)
			end
		else
			scale.Scale = 1.12
			UI.tween(scale, 0.12, { Scale = 1 })
		end
		-- a soft rising chime every 5 hits: the chain is audible
		if hits % 5 == 0 then
			Sound.play("Chime", 0.18, 0.8 + math.min(hits, 150) / 150 * 0.9)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		if not alive then
			return
		end
		if not DigFX.isVacuuming() then
			left -= dt
		end
		if left <= 0 then
			finish()
			return
		end
		if box.Visible then
			fill.Size = UDim2.fromScale(math.clamp(left / World.ComboWindow, 0, 1), 1)
		end
	end)
end

return Combo
