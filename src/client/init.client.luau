--!strict
-- Rob the Rich! client entry point. The client only renders and sends intents.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local Controllers = script.Controllers
local Util = script.Util

local Music = require(Util.Music)
local Shake = require(Util.Shake)
local HUD = require(Controllers.HUD)
local CarryFX = require(Controllers.CarryFX)
local WorldFX = require(Controllers.WorldFX)
local Panels = require(Controllers.Panels)
local Ambient = require(Controllers.Ambient)
local Items = require(Controllers.Items)

local waited = 0
while player:GetAttribute("Loaded") ~= true and waited < 60 do
	waited += task.wait(0.1)
end

Music.start()
Shake.start()
HUD.start()
CarryFX.start()
WorldFX.start()
Panels.start()
Items.start()
Ambient.start()
