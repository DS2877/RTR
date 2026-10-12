--!strict
-- Day / night cycle (looks only): a bright day, then a purple moonlit night, on a fixed loop.
-- The HUD counts down to the next phase from workspace attributes DayPhase + PhaseEndsAt
-- (a real time, never a fake timer).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local World = require(ReplicatedStorage.Shared.Config.World)

local DayNight = {}

local FADE = 6 -- seconds the sky takes to turn

local DAY = {
	Brightness = 2.4,
	Ambient = Color3.fromRGB(95, 95, 110),
	OutdoorAmbient = Color3.fromRGB(150, 150, 160),
}
-- night stays playable: bright purple ambient instead of darkness
local NIGHT = {
	Brightness = 1.2,
	Ambient = Color3.fromRGB(90, 80, 130),
	OutdoorAmbient = Color3.fromRGB(135, 120, 185),
}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function tween(props: { [string]: any })
	TweenService:Create(Lighting, TweenInfo.new(FADE, Enum.EasingStyle.Sine), props):Play()
end

local function setPhase(phase: string, seconds: number)
	workspace:SetAttribute("DayPhase", phase)
	workspace:SetAttribute("PhaseEndsAt", now() + seconds)
end

function DayNight.start()
	setPhase("Day", World.DaySeconds)
	task.spawn(function()
		while true do
			task.wait(World.DaySeconds)
			-- dusk: the sun goes down past 18:00 to midnight
			setPhase("Night", World.NightSeconds)
			local props = table.clone(NIGHT) :: { [string]: any }
			props.ClockTime = 23.9
			tween(props)
			task.wait(World.NightSeconds)
			-- dawn: from midnight up to the afternoon sun
			setPhase("Day", World.DaySeconds)
			Lighting.ClockTime = 0
			local day = table.clone(DAY) :: { [string]: any }
			day.ClockTime = 14
			tween(day)
		end
	end)
end

return DayNight
