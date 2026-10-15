--!strict
-- Dig Out! client entry.

local Players = game:GetService("Players")

local Controllers = script.Controllers
local Shake = require(script.Util.Shake)

local player = Players.LocalPlayer
while player:GetAttribute("Loaded") ~= true do
	player:GetAttributeChangedSignal("Loaded"):Wait()
end

Shake.start()
require(Controllers.CameraController).start()
require(Controllers.VoxelRender).start()
require(Controllers.DigFX).start()
require(Controllers.DigController).start()
require(Controllers.HUD).start()
require(Controllers.Shops).start()
