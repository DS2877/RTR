--!strict
-- Client-side world animation (visual only, never replicated):
-- treadmill stripes + your run animation while you stand on your belt, express-lane chevrons,
-- guards swinging arms and legs, blinking LEDs, bobbing balloons, spinning diamonds and the
-- pulsing COLLECT pad. Everything far away is skipped to stay cheap on phones.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Config.Assets)
local Economy = require(Shared.Config.Economy)

local Ambient = {}

local player = Players.LocalPlayer
local NEAR = 160

local function rootPart(): BasePart?
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function myBase(): Model?
	local bases = workspace:FindFirstChild("Bases")
	local b = bases and bases:FindFirstChild("Base_" .. tostring(player:GetAttribute("BaseId")))
	return if b and b:IsA("Model") then b else nil
end

-- ===== treadmills: scrolling stripes on every belt =====
type Belt = { part: BasePart, stripes: { BasePart } }
local belts: { Belt } = {}
local STRIPES = 7

local function setupBelts()
	local folder = Instance.new("Folder")
	folder.Name = "LocalBeltStripes"
	folder.Parent = workspace
	local bases = workspace:WaitForChild("Bases")
	for _, base in bases:GetChildren() do
		local belt = base:FindFirstChild("Treadmill")
		if belt and belt:IsA("BasePart") then
			local color = belt:GetAttribute("BeltColor")
			local b: Belt = { part = belt, stripes = {} }
			for _ = 1, STRIPES do
				local s = Instance.new("Part")
				s.Anchored = true
				s.CanCollide = false
				s.CanQuery = false
				s.CanTouch = false
				s.CastShadow = false
				s.Material = Enum.Material.Neon
				s.Color = if typeof(color) == "Color3" then color else Color3.new(1, 1, 1)
				s.Size = Vector3.new(belt.Size.X - 0.6, 0.06, 0.5)
				s.Parent = folder
				table.insert(b.stripes, s)
			end
			table.insert(belts, b)
		end
	end
end

local function updateBelts(t: number, r: BasePart?)
	for _, b in belts do
		local belt = b.part
		if r and (belt.Position - r.Position).Magnitude > NEAR then
			continue
		end
		local len = belt.Size.Z
		for i, s in b.stripes do
			-- scroll toward the entrance (local +Z of the belt points out of the base)
			local z = ((i / STRIPES) * len + t * Economy.Treadmill.BeltSpeed) % len - len / 2
			s.CFrame = belt.CFrame * CFrame.new(0, belt.Size.Y / 2 + 0.03, z)
		end
	end
end

-- ===== your run animation on your own belt =====
local runTrack: AnimationTrack? = nil
local runFor: Model? = nil

local function onMyBelt(r: BasePart): boolean
	local base = myBase()
	local belt = base and base:FindFirstChild("Treadmill")
	if not belt or not belt:IsA("BasePart") then
		return false
	end
	local l = belt.CFrame:PointToObjectSpace(r.Position)
	return math.abs(l.X) <= belt.Size.X / 2 + 0.5 and math.abs(l.Z) <= belt.Size.Z / 2 and l.Y > 0 and l.Y < 7
end

local function updateRun(r: BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not character or not humanoid or not animator then
		return
	end
	if runFor ~= character then
		runTrack = nil
		runFor = character
	end
	local want = r ~= nil
		and onMyBelt(r)
		and humanoid.MoveDirection.Magnitude < 0.1
		and player:GetAttribute("Carrying") == nil
	if want and not runTrack then
		local anim = Instance.new("Animation")
		anim.AnimationId = Assets.Animations.Run
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and track then
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			runTrack = track
		end
	end
	local track = runTrack
	if track then
		if want and not track.IsPlaying then
			track:Play(0.2)
			track:AdjustSpeed(1.2)
		elseif not want and track.IsPlaying then
			track:Stop(0.2)
		end
	end
end

-- ===== guards: swing limbs by speed =====
local function updateGuards(t: number, r: BasePart?)
	local folder = workspace:FindFirstChild("Guards")
	if not folder then
		return
	end
	for _, g in folder:GetChildren() do
		local root = g:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			continue
		end
		if r and (root.Position - r.Position).Magnitude > NEAR then
			continue
		end
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local amount = math.min(1, speed / 12) * 0.9
		local asleep = g:GetAttribute("Asleep") == true
		local swing = math.sin(t * (6 + speed * 0.25)) * amount
		for _, m in root:GetChildren() do
			if m:IsA("Motor6D") then
				local s = swing
				if m.Name == "LegRJoint" or m.Name == "ArmLJoint" then
					s = -swing
				end
				if asleep then
					s = if string.sub(m.Name, 1, 3) == "Arm" then 0.15 else 0
				elseif g:GetAttribute("Chasing") and string.sub(m.Name, 1, 3) == "Arm" then
					s = -1.3 + swing * 0.3 -- arms forward: grabbing!
				end
				m.Transform = CFrame.Angles(s, 0, 0)
			end
		end
	end
end

-- ===== tagged decor =====
local origins: { [BasePart]: CFrame } = {}
local function updateTags(t: number, r: BasePart?)
	local blinkOn = math.floor(t * 2) % 2 == 0
	for i, p in CollectionService:GetTagged("Blink") do
		if p:IsA("BasePart") and (not r or (p.Position - r.Position).Magnitude < NEAR) then
			p.Transparency = if (i % 3 == 0) == blinkOn then 0.6 else 0
		end
	end
	for _, tag in { "Bob", "Spin" } do
		for _, p in CollectionService:GetTagged(tag) do
			if p:IsA("BasePart") then
				local o = origins[p]
				if not o then
					o = p.CFrame
					origins[p] = o
				end
				if not r or (o.Position - r.Position).Magnitude < NEAR then
					if tag == "Bob" then
						p.CFrame = o * CFrame.new(0, math.sin(t * 1.5 + o.Position.X) * 0.5, 0)
					else
						p.CFrame = o * CFrame.Angles(0, t * 1.2, 0)
					end
				end
			end
		end
	end
end

-- chevrons light up in a wave running the lane's direction
local function updateChevrons(t: number, r: BasePart?)
	if not r then
		return
	end
	for _, c in CollectionService:GetTagged("Chevron") do
		if c:IsA("BasePart") then
			local dx = c.Position.X - r.Position.X
			if math.abs(dx) < 140 then
				local dir = if c.Position.Z < 0 then 1 else -1
				local wave = (c.Position.X * dir * 0.08 - t * 4) % 3
				c.Transparency = if wave < 1 then 0 else 0.65
			end
		end
	end
end

local function updatePad(t: number)
	local base = myBase()
	local pad = base and base:FindFirstChild("CollectPad")
	if pad and pad:IsA("BasePart") then
		pad.Transparency = 0.25 + 0.25 * math.sin(t * 4)
	end
end

function Ambient.start()
	setupBelts()
	local t = 0
	local acc = 0
	-- limb swings go in before physics so the joints are solved with them this frame
	RunService.PreSimulation:Connect(function()
		updateGuards(t, rootPart())
	end)
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		local r = rootPart()
		updateBelts(t, r)
		-- cheaper stuff at ~20 Hz
		acc += dt
		if acc >= 0.05 then
			acc = 0
			updateRun(r)
			updateTags(t, r)
			updateChevrons(t, r)
			updatePad(t)
		end
	end)
end

return Ambient
