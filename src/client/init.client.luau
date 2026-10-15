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
local DigController = require(Controllers.DigController)
DigController.start()
-- impact sparks on every punch (before the server's answer arrives)
do
	local DigFX = require(Controllers.DigFX)
	local VoxelRender = require(Controllers.VoxelRender)
	local Tunnel = require(game:GetService("ReplicatedStorage").Shared.Tunnel)
	DigController.onPunch = function(a)
		local t = VoxelRender.own()
		if t then
			DigFX.sparks(
				Tunnel.blockCenter(t.frame, a.x, a.y, a.z),
				VoxelRender.blockColor(a.x, a.y, a.z):Lerp(Color3.new(1, 1, 1), 0.5)
			)
		end
	end
end
require(Controllers.HUD).start()
require(Controllers.Shops).start()
require(Controllers.Clock).start()
require(Controllers.PvPController).start()
local ExtraShops = require(Controllers.ExtraShops)
ExtraShops.start()
require(Controllers.Shops).openDecor = function()
	ExtraShops.open("Decor")
end
require(Controllers.Moments).start()
require(Controllers.Guide).start()
require(Controllers.Music).start()
