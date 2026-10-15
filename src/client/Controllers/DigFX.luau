--!strict
-- The juice: crumbling debris cubes, the vacuum swirl that sucks debris and rubble piles into you,
-- rubble heaps waiting to be vacuumed, impact sparks and the zone-unlock confetti.
-- Everything here is client-only and capped (World.MaxDebris).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Zones = require(Shared.Config.Zones)
local Voxel = require(Shared.Voxel)
local Progression = require(Shared.Progression)
local Tunnel = require(Shared.Tunnel)
local Remotes = require(Shared.Remotes)

local Client = script.Parent.Parent
local VoxelRender = require(script.Parent.VoxelRender)
local Sound = require(Client.Util.Sound)
local Shake = require(Client.Util.Shake)

local DigFX = {}

local player = Players.LocalPlayer
local folder: Folder

type Debris = { part: Part, born: number, life: number, sucked: boolean, t: number, from: Vector3 }
local debris: { Debris } = {}
local free: { Part } = {}

type Heap = { model: Model, pos: Vector3, n: number }
local heaps: { [number]: Heap } = {}

local vacuumOn = false
local swirl: { Part } = {}

local function root(): BasePart?
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function vacuumRange(): number
	return Progression.vacuumRange(player:GetAttribute("Vacuum") or 1)
end

function DigFX.debrisCount(): number
	return #debris
end

-- ===== debris =====

local function newCube(): Part
	local p = table.remove(free)
	if p then
		return p
	end
	local c = Instance.new("Part")
	c.Name = "Debris"
	c.CanTouch = false
	c.CanQuery = false
	c.CastShadow = false
	c.CollisionGroup = "Debris"
	c.TopSurface = Enum.SurfaceType.Smooth
	c.BottomSurface = Enum.SurfaceType.Smooth
	return c
end

local function recycle(d: Debris)
	d.part.Parent = nil
	d.part.Anchored = false
	table.insert(free, d.part)
end

local function spawnDebris(pos: Vector3, color: Color3, material: Enum.Material, out: Vector3, count: number)
	for _ = 1, count do
		if #debris >= World.MaxDebris then
			recycle(table.remove(debris, 1) :: Debris)
		end
		local c = newCube()
		local s = 0.35 + math.random() * 0.45
		c.Size = Vector3.new(s, s, s)
		c.Color = color
		c.Material = material
		c.Anchored = false
		c.CanCollide = true
		c.CFrame = CFrame.new(
			pos + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.4
		) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		c.Parent = folder
		c.AssemblyLinearVelocity = out * (8 + math.random() * 10)
			+ Vector3.new((math.random() - 0.5) * 12, 6 + math.random() * 10, (math.random() - 0.5) * 12)
		c.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
			* 20
		table.insert(debris, {
			part = c,
			born = os.clock(),
			life = World.DebrisLifetime * (0.7 + math.random() * 0.6),
			sucked = false,
			t = 0,
			from = Vector3.zero,
		})
	end
end

local function sparks(pos: Vector3, color: Color3)
	local a = Instance.new("Part")
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.Transparency = 1
	a.Size = Vector3.new(0.2, 0.2, 0.2)
	a.CFrame = CFrame.new(pos)
	a.Parent = folder
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = 0.6
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.2, 0.4)
	pe.Speed = NumberRange.new(10, 18)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Rate = 0
	pe.Parent = a
	pe:Emit(10)
	task.delay(0.6, function()
		a:Destroy()
	end)
end

local function onBroken(t: VoxelRender.T, broken: { number }, puncher: number)
	local mine = puncher == player.UserId
	local perBlock = World.DebrisPerBlock
	if #broken > 9 then
		perBlock = math.max(1, math.floor(perBlock * 9 / #broken))
	end
	local r = root()
	for _, idx in broken do
		local x, y, z = Voxel.unindex(t.grid, idx)
		local pos = Tunnel.blockCenter(t.frame, x, y, z)
		local out = if r then (r.Position - pos).Unit else Vector3.yAxis
		local zone = Zones[Progression.zoneAt(z)]
		local mat = (Enum.Material :: any)[zone.material] or Enum.Material.SmoothPlastic
		spawnDebris(pos, VoxelRender.blockColor(x, y, z), mat, out, perBlock)
	end
	if mine then
		Sound.play("Crumble", 0.55, 0.55 + math.random() * 0.1)
		Shake.kick(math.min(0.45, 0.2 + #broken * 0.02))
	end
end

local function onDamaged(t: VoxelRender.T, damaged: { number }, puncher: number)
	if puncher ~= player.UserId then
		return
	end
	for i, idx in damaged do
		if i > 4 then
			break
		end
		local x, y, z = Voxel.unindex(t.grid, idx)
		local pos = Tunnel.blockCenter(t.frame, x, y, z)
		spawnDebris(pos, VoxelRender.blockColor(x, y, z), Enum.Material.SmoothPlastic, Vector3.yAxis, 1)
	end
end

-- ===== rubble heaps (the server's loose piles) =====

local function heapModel(n: number, color: Color3): Model
	local m = Instance.new("Model")
	m.Name = "Heap"
	local count = math.clamp(math.ceil(n / 2), 2, 6)
	for i = 1, count do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		local s = 0.6 + math.random() * 0.6
		p.Size = Vector3.new(s, s * 0.7, s)
		p.Color = color:Lerp(Color3.new(0, 0, 0), math.random() * 0.2)
		p.Material = Enum.Material.Slate
		local a = i / count * math.pi * 2
		p.CFrame = CFrame.new(math.cos(a) * 0.8, s * 0.35, math.sin(a) * 0.8) * CFrame.Angles(0, a, 0)
		p.Parent = m
	end
	return m
end

local function floorBelow(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, player.Character :: Instance }
	local hit = workspace:Raycast(pos + Vector3.new(0, 0.5, 0), Vector3.new(0, -30, 0), params)
	return if hit then hit.Position else pos
end

local function heapScale(model: Model, s: number)
	pcall(function()
		model:ScaleTo(s)
	end)
end

local function setPiles(list: { { number } })
	local seen: { [number]: boolean } = {}
	for _, p in list do
		local id, n = p[1], p[5]
		seen[id] = true
		local h = heaps[id]
		if not h then
			local pos = floorBelow(Vector3.new(p[2], p[3], p[4]))
			local t = VoxelRender.own()
			local color = Color3.fromRGB(150, 140, 130)
			if t then
				local x, y, z = Tunnel.toBlock(t.frame, Vector3.new(p[2], p[3], p[4]))
				color = VoxelRender.blockColor(math.clamp(x, 0, 17), math.clamp(y, 0, 11), math.max(0, z))
			end
			local m = heapModel(n, color)
			m:PivotTo(CFrame.new(pos))
			m.Parent = folder
			heaps[id] = { model = m, pos = pos, n = n }
		elseif h.n ~= n then
			h.n = n
			local s = math.clamp(0.6 + n / 20, 0.6, 1.4)
			heapScale(h.model, s)
		end
	end
	for id, h in heaps do
		if not seen[id] then
			-- sucked up: fly into the player
			local r = root()
			local m = h.model
			if r then
				task.spawn(function()
					local start = m:GetPivot().Position
					for i = 1, 8 do
						if not m.Parent then
							break
						end
						local rr = root()
						local target = if rr then rr.Position else start
						m:PivotTo(CFrame.new(start:Lerp(target, i / 8)))
						task.wait(0.02)
					end
					m:Destroy()
				end)
			else
				m:Destroy()
			end
			heaps[id] = nil
		end
	end
end

function DigFX.heapCount(): number
	local n = 0
	for _ in heaps do
		n += 1
	end
	return n
end

-- Nearest heap (for the HUD hint), or nil.
function DigFX.nearestHeap(): Vector3?
	local r = root()
	if not r then
		return nil
	end
	local best, bestD = nil, math.huge
	for _, h in heaps do
		local d = (h.pos - r.Position).Magnitude
		if d < bestD then
			best, bestD = h.pos, d
		end
	end
	return best
end

-- ===== vacuum =====

function DigFX.setVacuum(on: boolean)
	if on == vacuumOn then
		return
	end
	vacuumOn = on
	if on then
		Sound.play("Vacuum", 0.5, 0.8)
	end
end

local function ensureSwirl()
	if #swirl > 0 then
		return
	end
	for i = 1, 10 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(150, 230, 255)
		p.Transparency = 0.3
		p.Size = Vector3.new(0.25, 0.25, 0.25 + (i % 3) * 0.2)
		swirl[i] = p
	end
end

local function updateVacuum(dt: number)
	local r = root()
	local active = vacuumOn or player:GetAttribute("AutoVacuum") == true
	ensureSwirl()
	if not r or not vacuumOn then
		for _, p in swirl do
			p.Parent = nil
		end
	else
		local t = os.clock()
		local hand = r.CFrame * CFrame.new(0.8, -0.2, -2.2)
		for i, p in swirl do
			local a = t * 9 + i * (math.pi * 2 / #swirl)
			local radius = 0.5 + ((t * 2 + i / #swirl) % 1) * 1.4
			local depth = -((t * 3 + i / #swirl) % 1) * 2.5
			p.CFrame = hand
				* CFrame.new(math.cos(a) * radius, math.sin(a) * radius, depth)
				* CFrame.Angles(0, 0, a)
			p.Parent = folder
		end
	end
	if not r then
		return
	end
	local range = vacuumRange()
	local target = r.Position
	local now = os.clock()
	for i = #debris, 1, -1 do
		local d = debris[i]
		local part = d.part
		if active and not d.sucked and (part.Position - target).Magnitude <= range then
			d.sucked = true
			d.t = 0
			d.from = part.Position
			part.Anchored = true
			part.CanCollide = false
		end
		if d.sucked then
			d.t += dt * 3.2
			local k = math.min(1, d.t)
			local swirlAngle = k * 8
			local side = r.CFrame.RightVector * math.sin(swirlAngle) * (1 - k) * 2
			part.CFrame = CFrame.new(d.from:Lerp(target, k * k) + side) * CFrame.Angles(k * 9, k * 7, 0)
			part.Size = part.Size * (1 - dt * 1.5)
			if k >= 1 then
				recycle(d)
				table.remove(debris, i)
			end
		elseif now - d.born > d.life then
			recycle(d)
			table.remove(debris, i)
		end
	end
end

-- ===== confetti =====

function DigFX.confetti(at: Vector3?)
	local r = root()
	local origin = at or (if r then r.Position + Vector3.new(0, 3, 0) else nil)
	if not origin then
		return
	end
	local colors = {
		Color3.fromRGB(255, 80, 90),
		Color3.fromRGB(255, 210, 60),
		Color3.fromRGB(80, 200, 255),
		Color3.fromRGB(120, 230, 120),
		Color3.fromRGB(200, 120, 255),
	}
	for i = 1, 50 do
		local p = Instance.new("Part")
		p.Size = Vector3.new(0.4, 0.06, 0.25)
		p.Color = colors[i % #colors + 1]
		p.Material = Enum.Material.Neon
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CollisionGroup = "Debris"
		p.CFrame = CFrame.new(origin) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		p.Parent = folder
		p.AssemblyLinearVelocity =
			Vector3.new((math.random() - 0.5) * 40, 25 + math.random() * 25, (math.random() - 0.5) * 40)
		p.AssemblyAngularVelocity = Vector3.new(math.random() * 10, math.random() * 10, 0)
		task.delay(3 + math.random(), function()
			p:Destroy()
		end)
	end
end

function DigFX.start()
	folder = Instance.new("Folder")
	folder.Name = "DigFX"
	folder.Parent = workspace
	VoxelRender.onBroken = onBroken
	VoxelRender.onDamaged = onDamaged
	VoxelRender.onChamber = function(t, zone)
		local b = Progression.chamberBox(zone)
		if b and t.owner == player.UserId then
			local mid = Tunnel.blockCenter(t.frame, (b.x0 + b.x1) // 2, 2, (b.z0 + b.z1) // 2)
			DigFX.confetti(mid)
			Shake.kick(0.8)
		end
	end
	Remotes.get(Remotes.Names.Piles).OnClientEvent:Connect(setPiles)
	RunService.Heartbeat:Connect(updateVacuum)
end

-- hit sparks at the aimed block (called by the HUD wiring when a punch lands)
DigFX.sparks = sparks

return DigFX
