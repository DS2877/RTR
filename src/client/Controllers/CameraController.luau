--!strict
-- Third-person camera (kept in its own controller so first person can be tried later).
-- Inside a tunnel: over-the-shoulder offset and a short max zoom so walls never block the view
-- (the default camera's popper zooms in further when needed), a headlamp, and the zone's tint.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Zones = require(Shared.Config.Zones)
local Progression = require(Shared.Progression)
local Tunnel = require(Shared.Tunnel)

local CameraController = {}

local player = Players.LocalPlayer

local OUTSIDE_ZOOM = 40
local TUNNEL_ZOOM = 13
local SHOULDER = Vector3.new(1.4, 0.7, 0)

local inTunnel = false
local currentZone = 1
local lamp: PointLight? = nil

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Which tunnel (cell) the character is in, and the depth layer.
function CameraController.where(): (number?, number)
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if not r or not r:IsA("BasePart") then
		return nil, 0
	end
	for cell = 1, World.CellCount do
		local frame = Tunnel.frame(cell)
		if Tunnel.inside(frame, r.Position, 0) then
			local _, _, z = Tunnel.toBlock(frame, r.Position)
			return cell, z
		end
	end
	return nil, 0
end

function CameraController.zone(): number
	return currentZone
end

function CameraController.inTunnel(): boolean
	return inTunnel
end

function CameraController.start()
	local tint = Lighting:WaitForChild("ZoneTint", 10) :: ColorCorrectionEffect?
	local baseAmbient = Lighting.Ambient
	local tunnelAmbient = Color3.fromRGB(70, 68, 76)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		local cell, z = CameraController.where()
		local now = cell ~= nil and z >= 1
		currentZone = if cell then Progression.zoneAt(math.max(0, z)) else 1
		if now ~= inTunnel then
			inTunnel = now
			player.CameraMaxZoomDistance = if now then TUNNEL_ZOOM else OUTSIDE_ZOOM
			local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if h then
				h.CameraOffset = if now then SHOULDER else Vector3.zero
			end
		end
		-- headlamp + tint
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if r and (not lamp or lamp.Parent ~= r) then
			lamp = Instance.new("PointLight")
			assert(lamp, "lamp")
			lamp.Name = "Headlamp"
			lamp.Range = 26
			lamp.Shadows = false
			lamp.Color = Color3.fromRGB(255, 240, 215)
			lamp.Parent = r
		end
		local zone = Zones[currentZone]
		if lamp then
			lamp.Enabled = inTunnel
			lamp.Brightness = 1.4 * zone.brightness
		end
		local targetTint = if inTunnel then rgb(zone.tint) else Color3.new(1, 1, 1)
		local k = 0.35
		if tint then
			tint.TintColor = tint.TintColor:Lerp(targetTint, k)
		end
		Lighting.Ambient = Lighting.Ambient:Lerp(if inTunnel then tunnelAmbient else baseAmbient, k)
	end)
	player.CharacterAdded:Connect(function(c)
		inTunnel = false
		player.CameraMaxZoomDistance = OUTSIDE_ZOOM
		local h = c:WaitForChild("Humanoid", 5) :: Humanoid?
		if h then
			h.CameraOffset = Vector3.zero
		end
	end)
end

return CameraController
