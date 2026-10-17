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
require(Controllers.Chambers).start()
require(Controllers.Quality).start()
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
		local t = DigController.tunnel()
		if t then
			DigFX.impact(
				Tunnel.blockCenter(t.frame, a.x, a.y, a.z),
				Tunnel.faceDirection(t.frame, Voxel.Faces[a.face]),
				VoxelRender.blockColor(a.x, a.y, a.z):Lerp(Color3.new(1, 1, 1), 0.5)
			)
			VoxelRender.jolt(t, a.x, a.y, a.z)
		end
	end
	local DigAudio = require(Controllers.DigAudio)
	VoxelRender.onHit = function(_t, puncher, z)
		if puncher ~= player.UserId then
			-- the punch is procedural (not replicated): animate their character here too
			local p = game:GetService("Players"):GetPlayerByUserId(puncher)
			if p and p.Character then
				PunchAnim.play(p.Character)
			end
			local r = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if r and r:IsA("BasePart") then
				DigAudio.remoteHit(z, r.Position + r.CFrame.LookVector * 3)
			end
		end
	end
end
require(Controllers.HUD).start()
require(Controllers.Combo).start()
require(Controllers.Breakout).start()
require(Controllers.Crew).start()
require(Controllers.HeldTools).start()
require(Controllers.PassUI).start()
require(Controllers.Shops).start()
require(Controllers.Catalog).start()
require(Controllers.Locker).start()
require(Controllers.CartFX).start()
require(Controllers.Clock).start()
require(Controllers.PvPController).start()
local ExtraShops = require(Controllers.ExtraShops)
ExtraShops.start()
require(Controllers.Shops).openDecor = function()
	ExtraShops.open("Decor")
end
require(Controllers.Moments).start()
local Tour = require(Controllers.Tour)
Tour.start()
require(Controllers.HUD).replayTour = Tour.play
require(Controllers.GymController).start()
require(Controllers.GuardController).start()
local Music = require(Controllers.Music)
Music.start()
do
	local CameraController = require(Controllers.CameraController)
	require(Controllers.DigAudio).start(function()
		return CameraController.inTunnel(), CameraController.zone()
	end, Music.setDuck)
end
