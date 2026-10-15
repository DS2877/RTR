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
-- every punch lands instantly (before the server's answer): shock ring, dust, the block jolts;
-- other players' hits (their deltas) play their punch so everyone sees everyone dig
do
	local DigFX = require(Controllers.DigFX)
	local VoxelRender = require(Controllers.VoxelRender)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Tunnel = require(Shared.Tunnel)
	local Voxel = require(Shared.Voxel)
	local PunchAnim = require(script.Util.PunchAnim)
	PunchAnim.start()
	DigController.onPunch = function(a)
		local t = VoxelRender.own()
		if t then
			DigFX.impact(
				Tunnel.blockCenter(t.frame, a.x, a.y, a.z),
				Tunnel.faceDirection(t.frame, Voxel.Faces[a.face]),
				VoxelRender.blockColor(a.x, a.y, a.z):Lerp(Color3.new(1, 1, 1), 0.5)
			)
			VoxelRender.jolt(t, a.x, a.y, a.z)
		end
	end
	VoxelRender.onHit = function(_t, puncher)
		if puncher ~= player.UserId then
			PunchAnim.playPlayer(puncher)
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
require(Controllers.GymController).start()
require(Controllers.Music).start()
