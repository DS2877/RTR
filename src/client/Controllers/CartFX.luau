--!strict
-- CART feel: while the server says you're carting (attribute "Carting": your own tunnel, a cart
-- of level 2+) and you're moving on the ground, a low dust trail kicks up behind your feet; the
-- Rocket Cart adds a short spray of sparks. Two emitters on your own character, nothing else
-- (Quality scales their rate like every other emitter).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)

local CartFX = {}

local player = Players.LocalPlayer

local dust: ParticleEmitter? = nil
local sparks: ParticleEmitter? = nil

local function attach(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not root:IsA("BasePart") then
		return
	end
	local a = Instance.new("Attachment")
	a.Name = "CartTrail"
	a.Position = Vector3.new(0, -2.7, 0.8)
	a.Parent = root
	local d = Instance.new("ParticleEmitter")
	d.Name = "CartDust"
	d.Enabled = false
	d.Rate = 18
	d.Lifetime = NumberRange.new(0.45, 0.8)
	d.Speed = NumberRange.new(1.5, 3)
	d.SpreadAngle = Vector2.new(35, 15)
	d.EmissionDirection = Enum.NormalId.Back
	d.Acceleration = Vector3.new(0, 2, 0)
	d.Drag = 3
	d.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.6) })
	d.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	d.Color = ColorSequence.new(Color3.fromRGB(176, 156, 128))
	d.LightInfluence = 1
	d.Parent = a
	local s = Instance.new("ParticleEmitter")
	s.Name = "CartSparks"
	s.Enabled = false
	s.Rate = 26
	s.Lifetime = NumberRange.new(0.15, 0.3)
	s.Speed = NumberRange.new(6, 10)
	s.SpreadAngle = Vector2.new(25, 25)
	s.EmissionDirection = Enum.NormalId.Back
	s.Acceleration = Vector3.new(0, -20, 0)
	s.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
	s.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 120, 40))
	s.LightEmission = 1
	s.Parent = a
	dust, sparks = d, s
end

function CartFX.start()
	player.CharacterAdded:Connect(function(character)
		dust, sparks = nil, nil
		attach(character)
	end)
	if player.Character then
		task.spawn(attach, player.Character)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local d, s = dust, sparks
		if not d or not s or not d.Parent then
			return
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local level = player:GetAttribute("Cart")
		local lv = if typeof(level) == "number" then level else 1
		local on = player:GetAttribute("Carting") == true
			and humanoid ~= nil
			and humanoid.MoveDirection.Magnitude > 0.2
			and humanoid.FloorMaterial ~= Enum.Material.Air
			and lv >= 2
		if d.Enabled ~= on then
			d.Enabled = on
		end
		local rocket = on and lv >= #Upgrades.Cart
		if s.Enabled ~= rocket then
			s.Enabled = rocket
		end
	end)
end

return CartFX
