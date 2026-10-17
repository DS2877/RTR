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
	local baseSaturation = if tint then tint.Saturation else -0.35
	local look = require(Shared.Config.Cycle).Look
	local tunnelAmbient =
		Color3.fromRGB(look.Tunnel.ambient[1], look.Tunnel.ambient[2], look.Tunnel.ambient[3])
	local Clock = require(script.Parent.Clock)
	local Strata = require(Shared.Strata)
	-- floating particles around the camera, per zone (dust, drips, embers, sparkles)
	local airPart = Instance.new("Part")
	airPart.Name = "TunnelAir"
	airPart.Anchored = true
	airPart.CanCollide = false
	airPart.CanQuery = false
	airPart.CanTouch = false
	airPart.Transparency = 1
	airPart.Size = Vector3.new(26, 14, 26)
	airPart.Parent = workspace
	local air = Instance.new("ParticleEmitter")
	air.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	air.Lifetime = NumberRange.new(3, 5)
	air.Speed = NumberRange.new(0.1, 0.4)
	air.SpreadAngle = Vector2.new(180, 180)
	air.Shape = Enum.ParticleEmitterShape.Box
	air.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	air.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	air.Rate = 0
	air.Parent = airPart
	local airZone = ""
	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if cam and inTunnel then
			airPart.CFrame = CFrame.new(cam.CFrame.Position + cam.CFrame.LookVector * 8)
		end
	end)
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
		local spec = Strata.Air[zone.id]
		local key = if inTunnel and spec then zone.id else ""
		if key ~= airZone then
			airZone = key
			if spec and inTunnel then
				air.Color = ColorSequence.new(Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3]))
				air.Size = NumberSequence.new(spec.size)
				air.Acceleration = Vector3.new(0, spec.rise, 0)
				air.LightEmission = spec.light
				air.Rate = spec.rate
			else
				air.Rate = 0
			end
		end
		if lamp then
			lamp.Enabled = inTunnel
			lamp.Brightness = 1.4 * zone.brightness
		end
		local targetTint = if inTunnel then rgb(zone.tint) else Color3.new(1, 1, 1)
		local k = 0.35
		if tint then
			tint.TintColor = tint.TintColor:Lerp(targetTint, k)
			-- the prison is washed-out grey; every zone down the tunnel has its own color grading
			local sat = if inTunnel and zone.saturation then zone.saturation else baseSaturation
			tint.Saturation += (sat - tint.Saturation) * k
		end
		if lamp and inTunnel then
			-- the headlamp takes a hint of the zone's light
			lamp.Color = Color3.fromRGB(255, 240, 215):Lerp(rgb(zone.tint), 0.35)
		end
		if not Clock.override then -- (a cinematic owns the sky)
			Lighting.Ambient = Lighting.Ambient:Lerp(if inTunnel then tunnelAmbient else Clock.ambient(), k)
		end
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
