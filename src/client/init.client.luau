--!strict
-- Rob the Rich! client entry point. The client only renders and sends intents.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local Controllers = script.Controllers

local HUD = require(Controllers.HUD)
local CarryFX = require(Controllers.CarryFX)
local WorldFX = require(Controllers.WorldFX)
local Panels = require(Controllers.Panels)

local waited = 0
while player:GetAttribute("Loaded") ~= true and waited < 60 do
	waited += task.wait(0.1)
end

HUD.start()
CarryFX.start()
WorldFX.start()
Panels.start()
