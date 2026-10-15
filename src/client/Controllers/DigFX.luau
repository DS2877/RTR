--!strict
-- The juice: every broken block pops out of the wall as a big cube that tumbles and piles up on
-- the floor (plus chips and dust), the vacuum nozzle with air streaks that sucks the cubes in,
-- and the zone-unlock confetti. Everything here is client-only and capped (World.MaxDebris).

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

-- chunk = a big cube the size of a block (piles up until vacuumed), chip = small, short-lived
type Debris = {
	part: Part,
	born: number,
	life: number?,
	kind: string,
	sucked: boolean,
	t: number,
	from: Vector3,
}
local debris: { Debris } = {}
local free: { Part } = {}

-- the server's loose piles (truth for vacuuming): id -> { pos, n }
type Pile = { pos: Vector3, n: number }
local piles: { [number]: Pile } = {}

local vacuumOn = false
local streaks: { Part } = {}
local nozzle: Model? = nil

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

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

local function zoneMaterial(z: number): Enum.Material
	local zone = Zones[Progression.zoneAt(z)]
	return (Enum.Material :: any)[zone.material] or Enum.Material.Concrete
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
	c.CastShadow = true
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

-- oldest chips go first, then the oldest resting chunks
local function makeRoom()
	if #debris < World.MaxDebris then
		return
	end
	for i, d in debris do
		if d.kind == "chip" then
			recycle(d)
			table.remove(debris, i)
			return
		end
	end
	recycle(table.remove(debris, 1) :: Debris)
end

local function spawnCube(
	kind: string,
	pos: Vector3,
	size: number,
	color: Color3,
	material: Enum.Material,
	vel: Vector3
)
	makeRoom()
	local c = newCube()
	c.Size = Vector3.new(size, size, size)
	c.Color = color
	c.Material = material
	c.Anchored = false
	c.CanCollide = true
	c.Transparency = 0
	c.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 0.6, math.random() * 0.6, math.random() * 0.6)
	c.Parent = folder
	c.AssemblyLinearVelocity = vel
	c.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
		* (if kind == "chunk" then 6 else 18)
	table.insert(debris, {
		part = c,
		born = os.clock(),
		life = if kind == "chip" then 1.4 + math.random() else nil,
		kind = kind,
		sucked = false,
		t = 0,
		from = Vector3.zero,
	})
end

local function puff(pos: Vector3, color: Color3, amount: number, size: number)
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
	pe.Texture = SMOKE
	pe.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25))
	pe.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 2.6) })
	pe.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(0.6, 1.1)
	pe.Speed = NumberRange.new(1.5, 4)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Drag = 3
	pe.RotSpeed = NumberRange.new(-60, 60)
	pe.Rate = 0
	pe.Parent = a
	pe:Emit(amount)
	task.delay(1.4, function()
		a:Destroy()
	end)
end

local function sparks(pos: Vector3, color: Color3)
	puff(pos, color, 4, 0.6)
end

local function onBroken(t: VoxelRender.T, broken: { number }, puncher: number)
	local mine = puncher == player.UserId
	local r = root()
	local many = #broken > 9
	for i, idx in broken do
		local x, y, z = Voxel.unindex(t.grid, idx)
		local pos = Tunnel.blockCenter(t.frame, x, y, z)
		local color = VoxelRender.blockColor(x, y, z)
		local mat = zoneMaterial(z)
		-- out of the wall toward the player, then it falls
		local out = if r then Vector3.new(r.Position.X - pos.X, 0, r.Position.Z - pos.Z) else Vector3.zero
		out = if out.Magnitude > 0.01 then out.Unit else -t.frame.LookVector
		-- the big cube (one per block; every 2nd block on huge brushes / dynamite)
		if not many or i % 2 == 0 then
			local size = World.BlockSize * (0.78 + math.random() * 0.14)
			spawnCube(
				"chunk",
				pos,
				size,
				color,
				mat,
				out * (3 + math.random() * 5)
					+ Vector3.new((math.random() - 0.5) * 4, 2 + math.random() * 4, (math.random() - 0.5) * 4)
			)
		end
		-- a couple of chips
		for _ = 1, if many then 1 else 2 do
			spawnCube(
				"chip",
				pos + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5),
				0.3 + math.random() * 0.35,
				color,
				mat,
				out * (6 + math.random() * 8)
					+ Vector3.new(
						(math.random() - 0.5) * 10,
						4 + math.random() * 8,
						(math.random() - 0.5) * 10
					)
			)
		end
		if i <= 4 then
			puff(pos, color, if many then 3 else 6, 1)
		end
	end
	if mine then
		Sound.play("Crumble", 0.6, 0.5 + math.random() * 0.1)
		Shake.kick(math.min(0.5, 0.22 + #broken * 0.02))
	end
end

local function onDamaged(t: VoxelRender.T, damaged: { number }, puncher: number)
	if puncher ~= player.UserId then
		return
	end
	local r = root()
	for i, idx in damaged do
		if i > 3 then
			break
		end
		local x, y, z = Voxel.unindex(t.grid, idx)
		local pos = Tunnel.blockCenter(t.frame, x, y, z)
		local color = VoxelRender.blockColor(x, y, z)
		local out = if r then (r.Position - pos).Unit else Vector3.yAxis
		spawnCube(
			"chip",
			pos + out * 1.1,
			0.25 + math.random() * 0.25,
			color,
			zoneMaterial(z),
			out * 6 + Vector3.new(0, 5, 0)
		)
		puff(pos + out * 1.1, color, 3, 0.7)
	end
end

-- ===== the server's piles =====

local function floorBelow(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, player.Character :: Instance }
	local hit = workspace:Raycast(pos + Vector3.new(0, 0.5, 0), Vector3.new(0, -30, 0), params)
	return if hit then hit.Position else pos
end

local function chunksNear(pos: Vector3, radius: number): number
	local n = 0
	for _, d in debris do
		if d.kind == "chunk" and not d.sucked and (d.part.Position - pos).Magnitude <= radius then
			n += 1
		end
	end
	return n
end

local function suck(d: Debris)
	if d.sucked then
		return
	end
	d.sucked = true
	d.t = 0
	d.from = d.part.Position
	d.part.Anchored = true
	d.part.CanCollide = false
end

local function setPiles(list: { { number } })
	local seen: { [number]: boolean } = {}
	for _, p in list do
		local id, n = p[1], p[5]
		seen[id] = true
		local pos = Vector3.new(p[2], p[3], p[4])
		if not piles[id] then
			piles[id] = { pos = pos, n = n }
			-- rubble we never saw fall (joined later, cap reached): put a few cubes on the floor
			task.delay(1.5, function()
				if piles[id] and chunksNear(pos, World.PileMergeRadius + 2) == 0 then
					local floor = floorBelow(pos)
					local t = VoxelRender.own()
					local color = Color3.fromRGB(140, 142, 146)
					local z = 0
					if t then
						local bx, by, bz = Tunnel.toBlock(t.frame, pos)
						z = math.max(0, bz)
						color = VoxelRender.blockColor(math.clamp(bx, 0, 17), math.clamp(by, 0, 11), z)
					end
					for k = 1, math.clamp(math.ceil(n / 3), 1, 4) do
						spawnCube(
							"chunk",
							floor + Vector3.new(math.cos(k) * 1.2, 1 + k * 0.4, math.sin(k) * 1.2),
							1.5,
							color,
							zoneMaterial(z),
							Vector3.zero
						)
					end
				end
			end)
		else
			piles[id].n = n
		end
	end
	for id, pile in piles do
		if not seen[id] then
			-- vacuumed: every cube lying there flies into you
			piles[id] = nil
			for _, d in debris do
				if
					d.kind == "chunk"
					and (d.part.Position - pile.pos).Magnitude <= World.PileMergeRadius + 3
				then
					suck(d)
				end
			end
		end
	end
end

function DigFX.heapCount(): number
	local n = 0
	for _ in piles do
		n += 1
	end
	return n
end

-- Nearest pile (for the tutorial arrow), or nil.
function DigFX.nearestHeap(): Vector3?
	local r = root()
	if not r then
		return nil
	end
	local best, bestD = nil, math.huge
	for _, p in piles do
		local d = (p.pos - r.Position).Magnitude
		if d < bestD then
			best, bestD = p.pos, d
		end
	end
	return best
end

-- ===== vacuum: a nozzle in your hand, air streaks, cubes fly into it =====

function DigFX.setVacuum(on: boolean)
	if on == vacuumOn then
		return
	end
	vacuumOn = on
	if on then
		Sound.play("Vacuum", 0.5, 0.8)
	end
end

local function buildNozzle(): Model
	local m = Instance.new("Model")
	m.Name = "VacuumNozzle"
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat or Enum.Material.Metal
		p.Shape = Enum.PartType.Cylinder
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = m
		return p
	end
	-- along local -Z (cylinders run along X, so turn them)
	local turn = CFrame.Angles(0, math.pi / 2, 0)
	part("Mouth", Vector3.new(0.5, 1.1, 1.1), CFrame.new(0, 0, -2.2) * turn, Color3.fromRGB(160, 130, 60))
	part("Pipe", Vector3.new(1.6, 0.7, 0.7), CFrame.new(0, 0, -1.2) * turn, Color3.fromRGB(150, 120, 55))
	part(
		"Grip",
		Vector3.new(0.9, 0.55, 0.55),
		CFrame.new(0, 0, -0.2) * turn,
		Color3.fromRGB(30, 30, 32),
		Enum.Material.Rubber
	)
	for i = 0, 4 do
		part(
			"Hose",
			Vector3.new(0.45, 0.6, 0.6),
			CFrame.new(0.15 * i, -0.3 * i, 0.4 + i * 0.4) * turn,
			Color3.fromRGB(25, 25, 28),
			Enum.Material.Rubber
		)
	end
	return m
end

local function streak(i: number): Part
	local p = streaks[i]
	if not p then
		p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(235, 240, 245)
		p.Size = Vector3.new(0.06, 0.06, 1.4)
		streaks[i] = p
	end
	return p :: Part
end

local function mouthCFrame(r: BasePart): CFrame
	local c = player.Character
	local hand = c and (c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm"))
	local base = if hand and hand:IsA("BasePart")
		then CFrame.new(hand.Position) * r.CFrame.Rotation
		else r.CFrame * CFrame.new(1, -0.5, -1)
	return base * CFrame.new(0, 0, -0.6)
end

local function updateVacuum(dt: number)
	local r = root()
	local active = vacuumOn
		or player:GetAttribute("AutoVacuum") == true
		or player:GetAttribute("Magnet") == true
	local now = os.clock()
	-- nozzle + streaks while you hold VACUUM
	if r and vacuumOn then
		if not nozzle or not nozzle.Parent then
			nozzle = buildNozzle();
			(nozzle :: Model).Parent = folder
		end
		local base = mouthCFrame(r);
		(nozzle :: Model):PivotTo(base)
		local mouth = base * CFrame.new(0, 0, -2.4)
		for i = 1, 8 do
			local p = streak(i)
			local k = (now * 2.2 + i / 8) % 1 -- 0 = far, 1 = in the mouth
			local a = i * 2.4 + now * 3
			local spread = (1 - k) * 2.2
			local pos = mouth * CFrame.new(math.cos(a) * spread, math.sin(a) * spread, -(1 - k) * 5)
			p.CFrame = CFrame.lookAt(pos.Position, mouth.Position)
			p.Transparency = 0.2 + k * 0.7
			p.Parent = folder
		end
	else
		if nozzle then
			nozzle:Destroy()
			nozzle = nil
		end
		for _, p in streaks do
			p.Parent = nil
		end
	end
	if not r then
		return
	end
	local range = vacuumRange()
	local target = if vacuumOn then (mouthCFrame(r) * CFrame.new(0, 0, -2.4)).Position else r.Position
	for i = #debris, 1, -1 do
		local d = debris[i]
		local part = d.part
		if
			active
			and not d.sucked
			and d.kind == "chunk"
			and (part.Position - r.Position).Magnitude <= range
		then
			suck(d)
		end
		if d.sucked then
			d.t += dt * 2.6
			local k = math.min(1, d.t)
			local wobble = r.CFrame.RightVector * math.sin(k * 10) * (1 - k) * 1.2
			part.CFrame = CFrame.new(d.from:Lerp(target, k * k) + wobble) * CFrame.Angles(k * 8, k * 6, 0)
			local s = math.max(0.15, part.Size.X * (1 - dt * 2.2))
			part.Size = Vector3.new(s, s, s)
			if k >= 1 then
				recycle(d)
				table.remove(debris, i)
			end
		elseif d.life and now - d.born > d.life then
			recycle(d)
			table.remove(debris, i)
		elseif
			not part.Anchored
			and (now - d.born > 6 or (now - d.born > 0.9 and part.AssemblyLinearVelocity.Magnitude < 0.7))
		then
			-- settled on the pile (or tumbling too long): freeze it, no physics cost while it waits
			part.Anchored = true
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
