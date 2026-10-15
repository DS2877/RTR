--!strict
-- Aiming and punching. Auto-aim picks the exposed block of your own tunnel closest to where the
-- camera looks (within reach); a grid outline previews every block the brush will hit. PUNCH: tap =
-- one punch, hold = auto-punch at the attack rate. Mouse click / gamepad R2 / X work too.
-- The punch itself plays instantly (arm jab, shake, hit flash); the server's delta then cracks or
-- breaks the blocks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Voxel = require(Shared.Voxel)
local Progression = require(Shared.Progression)
local Tunnel = require(Shared.Tunnel)
local Remotes = require(Shared.Remotes)

local Client = script.Parent.Parent
local VoxelRender = require(script.Parent.VoxelRender)
local Sound = require(Client.Util.Sound)
local Shake = require(Client.Util.Shake)

local DigController = {}

local player = Players.LocalPlayer
local B = World.BlockSize
local MAX_Z = Progression.diggableDepth()

export type Aim = { x: number, y: number, z: number, face: number }

local aim: Aim? = nil
local holding = false
local lastPunch = 0
local outlines: { Part } = {}
local outlineFolder: Folder
local punchRemote: RemoteEvent

-- hooks for FX / HUD
DigController.onPunch = nil :: ((aim: Aim, targets: { { number } }) -> ())?
-- PUNCH with no block in reach: PvPController tries to punch a player (returns true if it did)
DigController.onEmptyPunch = nil :: (() -> boolean)?

local function root(): BasePart?
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

-- ===== aiming =====

local function findAim(): Aim?
	local t = VoxelRender.own()
	local r = root()
	local cam = workspace.CurrentCamera
	if not t or not r or not cam then
		return nil
	end
	local hrp = r.Position
	if not Tunnel.inside(t.frame, hrp, 4) then
		return nil
	end
	local g = t.grid
	local bx, by, bz = Tunnel.toBlock(t.frame, hrp)
	local reach = World.Reach
	local rb = math.ceil(reach / B) + 1
	local look = cam.CFrame.LookVector
	local camPos = cam.CFrame.Position
	local best: Aim? = nil
	local bestScore = math.huge
	for z = math.max(0, bz - rb), math.min(MAX_Z - 1, bz + rb) do
		for y = math.max(0, by - rb), math.min(g.h - 1, by + rb) do
			for x = math.max(0, bx - rb), math.min(g.w - 1, bx + rb) do
				if Voxel.isSolid(g, x, y, z) then
					local center = Tunnel.blockCenter(t.frame, x, y, z)
					local toHrp = (center - hrp).Magnitude
					if toHrp <= reach then
						-- best open face: the one facing the player most
						local face, faceDot = 0, -2
						local toPlayer = (hrp - center).Unit
						for f, n in Voxel.Faces do
							if Voxel.isOpen(g, x + n[1], y + n[2], z + n[3]) then
								local d = Tunnel.faceDirection(t.frame, n):Dot(toPlayer)
								if d > faceDot then
									face, faceDot = f, d
								end
							end
						end
						if face > 0 then
							local dir = (center - camPos).Unit
							local score = (1 - dir:Dot(look)) * 10 + toHrp * 0.05
							if dir:Dot(look) > 0.2 and score < bestScore then
								bestScore = score
								best = { x = x, y = y, z = z, face = face }
							end
						end
					end
				end
			end
		end
	end
	return best
end

-- ===== preview outlines =====

local function outline(i: number): Part
	local p = outlines[i]
	if not p then
		p = Instance.new("Part")
		p.Name = "Outline"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(B + 0.04, B + 0.04, B + 0.04)
		-- a thin 3D wireframe cube (white = gets hit, red = breaks with this punch)
		local box = Instance.new("SelectionBox")
		box.Name = "Box"
		box.Adornee = p
		box.LineThickness = 0.035
		box.Color3 = Color3.fromRGB(240, 240, 240)
		box.SurfaceColor3 = Color3.fromRGB(255, 255, 255)
		box.SurfaceTransparency = 1
		box.Parent = p
		outlines[i] = p
	end
	return p
end

local function targetsFor(a: Aim): { { number } }
	local t = VoxelRender.own()
	if not t then
		return {}
	end
	local brush = player:GetAttribute("Brushes") or 1
	return Progression.brushTargets(t.grid, a.x, a.y, a.z, a.face, brush, function(_, _, z)
		return z < MAX_Z
	end)
end

-- Will this punch break the block? (hp left is estimated from the crack stage the server sent)
local function willBreak(t: any, x: number, y: number, z: number): boolean
	local power = player:GetAttribute("Power")
	local p = if typeof(power) == "number" then power else 10
	local hp = Progression.blockHp(z)
	local stage = t.damage[Voxel.index(t.grid, x, y, z)]
	local left = if stage then hp * (1 - (stage - 0.5) / 3) else hp
	return left <= p
end

local function showPreview(a: Aim?)
	local t = VoxelRender.own()
	local list = if a and t then targetsFor(a) else {}
	for i, p in list do
		local o = outline(i)
		o.CFrame = (t :: any).frame * CFrame.new(Tunnel.localCenter(p[1], p[2], p[3]))
		local box = o:FindFirstChild("Box") :: SelectionBox
		box.Color3 = if willBreak(t :: any, p[1], p[2], p[3])
			then Color3.fromRGB(255, 85, 70)
			else Color3.fromRGB(240, 240, 240)
		o.Parent = outlineFolder
	end
	for i = #list + 1, #outlines do
		outlines[i].Parent = nil
	end
end

local function flashPreview()
	for _, o in outlines do
		if o.Parent then
			local box = o:FindFirstChild("Box") :: SelectionBox
			box.SurfaceTransparency = 0.6
			box.LineThickness = 0.08
			task.delay(0.07, function()
				box.SurfaceTransparency = 1
				box.LineThickness = 0.035
			end)
		end
	end
end

-- ===== procedural punch (arm jab via the shoulder joint) =====

local arms = { "Right", "Left" }
local nextArm = 1
local jab: { [string]: number } = { Right = 0, Left = 0 }
local baseC0: { [Motor6D]: CFrame } = {}

local function shoulder(side: string): Motor6D?
	local c = player.Character
	if not c then
		return nil
	end
	local upper = c:FindFirstChild(side .. "UpperArm")
	local m = upper and upper:FindFirstChild(side .. "Shoulder")
	if not m then
		local torso = c:FindFirstChild("Torso")
		m = torso and torso:FindFirstChild(side .. " Shoulder")
	end
	return if m and m:IsA("Motor6D") then m else nil
end

local function animateArms(dt: number)
	for _, side in arms do
		local m = shoulder(side)
		if m then
			if not baseC0[m] then
				baseC0[m] = m.C0
			end
			jab[side] = math.max(0, jab[side] - dt * 5)
			local k = jab[side]
			-- quick out, slower back: ease with k^2
			local amount = math.sin(math.min(1, k) * math.pi * 0.5) ^ 2
			local isR15 = m.Parent and m.Parent.Name ~= "Torso"
			local rot = if isR15
				then CFrame.Angles(math.rad(95) * amount, 0, 0)
				else CFrame.Angles(0, 0, math.rad(if side == "Right" then 95 else -95) * amount)
			m.C0 = baseC0[m] * rot
		end
	end
end

-- ===== punching =====

local function punch()
	local now = os.clock()
	local fast = player:GetAttribute("FastPunch")
	local interval = World.AttackInterval * (1 - (if typeof(fast) == "number" then fast else 0))
	if now - lastPunch < interval then
		return
	end
	local a = aim
	if not a then
		if DigController.onEmptyPunch and DigController.onEmptyPunch() then
			lastPunch = now
			jab[arms[nextArm]] = 1
			nextArm = 3 - nextArm
		end
		return
	end
	lastPunch = now
	jab[arms[nextArm]] = 1
	nextArm = 3 - nextArm
	punchRemote:FireServer(a.x, a.y, a.z, a.face)
	Sound.play("Punch", 0.7, 0.75)
	Shake.kick(0.16)
	flashPreview()
	if DigController.onPunch then
		DigController.onPunch(a, targetsFor(a))
	end
end

function DigController.setHolding(on: boolean)
	holding = on
	if on then
		punch()
	end
end

function DigController.hasAim(): boolean
	return aim ~= nil
end

function DigController.getAim(): Aim?
	return aim
end

function DigController.start()
	punchRemote = Remotes.get(Remotes.Names.Punch)
	outlineFolder = Instance.new("Folder")
	outlineFolder.Name = "AimPreview"
	outlineFolder.Parent = workspace

	player.CharacterAdded:Connect(function()
		baseC0 = {}
	end)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= 0.08 then
			acc = 0
			aim = findAim()
			showPreview(aim)
		end
		if holding then
			punch()
		end
		animateArms(dt)
	end)

	-- PC / gamepad
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.KeyCode == Enum.KeyCode.ButtonR2
			or input.KeyCode == Enum.KeyCode.ButtonX
			or input.KeyCode == Enum.KeyCode.F
		then
			DigController.setHolding(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.KeyCode == Enum.KeyCode.ButtonR2
			or input.KeyCode == Enum.KeyCode.ButtonX
			or input.KeyCode == Enum.KeyCode.F
		then
			DigController.setHolding(false)
		end
	end)
end

return DigController
