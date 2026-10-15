--!strict
-- The day/night clock: slim "🌙 in 2:31" text with the countdown to the next phase, the LIGHTS OUT
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

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- the indoor ambient for this moment of the day (CameraController darkens it in tunnels)
local baseAmbient = rgb(Cycle.Look.Day.ambient)
function Clock.ambient(): Color3
	return baseAmbient
end

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
	-- slim "🌙 in 2:31" text above the action buttons, no box (the phase that comes next)
	local text = UI.bigText({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -246),
		Size = UDim2.fromOffset(170, 28),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = gui,
	}, UI.INK, 1.6)
	UI.scaleObject(text)
	local box = text
	local warning = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.fromScale(0.7, 0.1),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 80, 80),
		Visible = false,
		Parent = gui,
	}, DARK, 2)

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
			text.Text = if mins > 0
				then string.format("🌙 in %d:%02d", mins, secs)
				else string.format("🌙 in %ds", secs)
			box.TextColor3 = Color3.fromRGB(255, 255, 255)
		elseif phase == "LightsOut" then
			text.Text = string.format("🚨 lights out in %ds", math.ceil(left))
			box.TextColor3 = Color3.fromRGB(255, 110, 110)
		else
			text.Text = if mins > 0
				then string.format("☀️ in %d:%02d", mins, secs)
				else string.format("☀️ in %ds", secs)
			box.TextColor3 = Color3.fromRGB(190, 205, 255)
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
		local day, night = Cycle.Look.Day, Cycle.Look.Night
		Lighting.Brightness = day.brightness + (night.brightness - day.brightness) * tint
		Lighting.OutdoorAmbient = rgb(day.outdoor):Lerp(rgb(night.outdoor), tint)
		baseAmbient = rgb(day.ambient):Lerp(rgb(night.ambient), tint)
	end)
end

return Clock
