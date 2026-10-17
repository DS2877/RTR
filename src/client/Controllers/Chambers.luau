--!strict
-- Builds each opened chamber's set piece (Shared/ChamberSets) inside the tunnel that owns it:
-- props, particle effects (steam, embers, drips, sparkles, fire) and flickering lights. Built
-- when a tunnel snapshot arrives with the chamber already open, and with a little pop-in the
-- moment someone breaks into it. Cosmetic only, client side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Zones = require(Shared.Config.Zones)
local Voxel = require(Shared.Voxel)
local Progression = require(Shared.Progression)
local ChamberSets = require(Shared.ChamberSets)

local VoxelRender = require(script.Parent.VoxelRender)

local Chambers = {}

local B = World.BlockSize
local W = World.TunnelWidth
local built: { [number]: { [number]: Model } } = {} -- owner -> zone -> model
local flickers: { { light: PointLight, base: number, seed: number } } = {}
local folder: Folder

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function emitter(kind: string, parent: BasePart)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
	pe.Rate = 6
	pe.Lifetime = NumberRange.new(2, 3.5)
	pe.Speed = NumberRange.new(1, 2)
	pe.SpreadAngle = Vector2.new(25, 25)
	if kind == "steam" then
		pe.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 5) })
		pe.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		pe.Acceleration = Vector3.new(0, 3, 0)
		pe.Rate = 10
	elseif kind == "embers" then
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(255, 160, 60), Color3.fromRGB(255, 70, 20))
		pe.LightEmission = 1
		pe.Size = NumberSequence.new(0.25)
		pe.Acceleration = Vector3.new(0, 4, 0)
		pe.Speed = NumberRange.new(0.5, 2)
		pe.Rate = 25
		pe.SpreadAngle = Vector2.new(180, 180)
	elseif kind == "drips" then
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(150, 200, 255))
		pe.Size = NumberSequence.new(0.15)
		pe.Acceleration = Vector3.new(0, -30, 0)
		pe.Speed = NumberRange.new(0, 0.2)
		pe.Rate = 4
	elseif kind == "sparkle" then
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(230, 220, 255))
		pe.LightEmission = 1
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 0),
		})
		pe.Speed = NumberRange.new(0.2, 0.8)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Rate = 14
	elseif kind == "fire" then
		pe.Texture = "rbxasset://textures/particles/fire_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 80, 20))
		pe.LightEmission = 1
		pe.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0.1) })
		pe.Lifetime = NumberRange.new(0.4, 0.8)
		pe.Acceleration = Vector3.new(0, 6, 0)
		pe.Rate = 30
	end
	pe.Parent = parent
end

local function isOpen(t: VoxelRender.T, zone: number): boolean
	local b = Progression.chamberBox(zone)
	if not b then
		return false
	end
	return Voxel.isDug(t.grid, b.x0, b.y0, b.z0)
		and Voxel.isDug(t.grid, b.x1, b.y1, b.z1)
		and Voxel.isDug(t.grid, (b.x0 + b.x1) // 2, b.y1 // 2, (b.z0 + b.z1) // 2)
end

function Chambers.build(t: VoxelRender.T, zone: number, reveal: boolean?)
	local mine = built[t.owner]
	if not mine then
		mine = {}
		built[t.owner] = mine
	end
	if mine[zone] or not isOpen(t, zone) then
		return
	end
	local b = Progression.chamberBox(zone)
	if not b then
		return
	end
	local w, h, d = (b.x1 - b.x0 + 1) * B, (b.y1 - b.y0 + 1) * B, (b.z1 - b.z0 + 1) * B
	local specs = ChamberSets.specs(zone, w, h, d)
	if not specs then
		return
	end
	local cx = ((b.x0 + b.x1) / 2 + 0.5) * B - W * B / 2
	local base = t.frame * CFrame.new(cx, 0, -b.z0 * B)
	local m = Instance.new("Model")
	m.Name = "Chamber" .. zone
	for _, s in specs do
		local part: BasePart
		if s.shape == "Wedge" then
			part = Instance.new("WedgePart")
		else
			local p = Instance.new("Part")
			if s.shape == "Cylinder" then
				p.Shape = Enum.PartType.Cylinder
			elseif s.shape == "Ball" then
				p.Shape = Enum.PartType.Ball
			end
			part = p
		end
		part.Anchored = true
		part.CanCollide = s.collide == true
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = s.material ~= "Neon"
		part.Size = Vector3.new(s.size[1], s.size[2], s.size[3])
		local r = s.rot or { 0, 0, 0 }
		part.CFrame = base
			* CFrame.new(s.pos[1], s.pos[2], -s.pos[3])
			* CFrame.Angles(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
		part.Color = rgb(s.color)
		pcall(function()
			part.Material = (Enum.Material :: any)[s.material]
		end)
		part.Transparency = s.transparency or 0
		if s.light then
			local l = Instance.new("PointLight")
			l.Color = rgb(s.light.color)
			l.Range = s.light.range
			l.Brightness = s.light.brightness
			l.Shadows = true
			l.Parent = part
			if s.light.flicker then
				table.insert(flickers, { light = l, base = s.light.brightness, seed = math.random() * 100 })
			end
		end
		if s.emit then
			emitter(s.emit, part)
		end
		local sign = (s :: any).sign
		if typeof(sign) == "string" then
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Back -- toward the entrance
			gui.LightInfluence = 1
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.GothamBlack
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(60, 40, 30)
			label.Text = sign
			label.Parent = gui
			gui.Parent = part
		end
		part.Parent = m
		if reveal then
			-- pop in: everything settles into place over a beat
			local final = part.CFrame
			part.CFrame = final * CFrame.new(0, -1.5, 0)
			TweenService
				:Create(
					part,
					TweenInfo.new(0.6 + math.random() * 0.4, Enum.EasingStyle.Back),
					{ CFrame = final }
				)
				:Play()
		end
	end
	m.Parent = folder
	mine[zone] = m
end

function Chambers.drop(owner: number)
	local mine = built[owner]
	if not mine then
		return
	end
	for _, m in mine do
		m:Destroy()
	end
	built[owner] = nil
end

local askedFavorite = false

function Chambers.start()
	folder = Instance.new("Folder")
	folder.Name = "Chambers"
	folder.Parent = workspace
	local prevChamber = VoxelRender.onChamber
	VoxelRender.onChamber = function(t, zone)
		if prevChamber then
			prevChamber(t, zone)
		end
		Chambers.build(t, zone, true)
		-- the first vault in your own tunnel is the best moment to ask for a ⭐ (once a session)
		if zone == 2 and t.owner == Players.LocalPlayer.UserId and not askedFavorite then
			askedFavorite = true
			task.delay(5, function()
				pcall(function()
					game:GetService("AvatarEditorService")
						:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
				end)
			end)
		end
	end
	VoxelRender.onLoaded = function(t)
		for zone in Zones do
			Chambers.build(t, zone, false)
		end
	end
	VoxelRender.onDropped = Chambers.drop
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for i = #flickers, 1, -1 do
			local f = flickers[i]
			if not f.light.Parent then
				table.remove(flickers, i)
			else
				local n = math.noise(now * 3, f.seed) * 0.5 + math.noise(now * 11, f.seed + 7) * 0.25
				f.light.Brightness = f.base * math.clamp(0.75 + n, 0.2, 1.3)
			end
		end
	end)
end

return Chambers
