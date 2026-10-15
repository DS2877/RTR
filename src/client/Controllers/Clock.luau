--!strict
-- The day/night clock: a big HUD clock with the countdown to the next phase, the LIGHTS OUT
-- countdown with a siren, and the sky/lighting fading between day and night.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Cycle = require(Shared.Config.Cycle)

local Client = script.Parent.Parent
local UI = require(Client.Util.UI)
local Sound = require(Client.Util.Sound)
local Shake = require(Client.Util.Shake)

local Clock = {}

local player = Players.LocalPlayer
local DARK = Color3.fromRGB(20, 20, 28)

function Clock.phase(): string
	local p = ReplicatedStorage:GetAttribute("Phase")
	return if typeof(p) == "string" then p else "Day"
end

function Clock.start()
	local gui = UI.new("ScreenGui", {
		Name = "Clock",
		ResetOnSpawn = false,
		DisplayOrder = 3,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local box = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(170, 44),
		BackgroundColor3 = Color3.fromRGB(255, 220, 110),
		Parent = gui,
	}, { UI.corner(12), UI.stroke(DARK, 3) })
	UI.scaleObject(box)
	local text = UI.bigText({
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.new(1, -12, 1, -8),
		Text = "☀️ DAY",
		Parent = box,
	})
	local warning = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.fromScale(0.7, 0.1),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 80, 80),
		Visible = false,
		Parent = gui,
	}, DARK, 4)

	local tint = 0 -- 0 = day, 1 = night
	local lastPhase = ""
	local lastSecond = -1
	RunService.RenderStepped:Connect(function(dt)
		local phase = Clock.phase()
		local ends = ReplicatedStorage:GetAttribute("PhaseEnds")
		local left = if typeof(ends) == "number" then math.max(0, ends - workspace:GetServerTimeNow()) else 0
		local mins = math.floor(left / 60)
		local secs = math.floor(left % 60)
		if phase == "Day" then
			text.Text = string.format("☀️ DAY %d:%02d", mins, secs)
			box.BackgroundColor3 = Color3.fromRGB(255, 220, 110)
		elseif phase == "LightsOut" then
			text.Text = string.format("🚨 %d", math.ceil(left))
			box.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
		else
			text.Text = string.format("🌙 NIGHT %d:%02d", mins, secs)
			box.BackgroundColor3 = Color3.fromRGB(120, 140, 255)
		end
		-- LIGHTS OUT countdown
		warning.Visible = phase == "LightsOut"
		if phase == "LightsOut" then
			local s = math.ceil(left)
			warning.Text = "LIGHTS OUT! " .. s
			if s ~= lastSecond then
				lastSecond = s
				Sound.play("Siren", 0.35, 0.9)
				UI.bump(warning :: any, 0.2)
			end
		end
		if phase ~= lastPhase then
			if phase == "Night" then
				Shake.kick(0.3)
			end
			lastPhase = phase
		end
		-- lighting fades over a few seconds
		local target = if phase == "Night" then 1 elseif phase == "LightsOut" then 0.6 else 0
		tint += (target - tint) * math.min(1, dt * 0.8)
		Lighting.ClockTime = Cycle.DayClock + (24 + Cycle.NightClock - Cycle.DayClock) * tint
		Lighting.Brightness = 2 - 1.4 * tint
		Lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 140):Lerp(Color3.fromRGB(40, 45, 80), tint)
	end)
end

return Clock
