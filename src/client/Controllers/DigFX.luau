--!strict
-- The juice: every broken block pops out of the wall as a big cube that tumbles and piles up on
-- the floor (plus chips and dust), the vacuum nozzle with air streaks that sucks the cubes in,
-- and the zone-unlock confetti. Everything here is client-only and capped (World.MaxDebris).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Zones = require(Shared.Config.Zones)
local Voxel = require(Shared.Voxel)
local Progression = require(Shared.Progression)
local Tunnel = require(Shared.Tunnel)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local Client = script.Parent.Parent
local VoxelRender = require(script.Parent.VoxelRender)
local DigAudio = require(script.Parent.DigAudio)
local Shake = require(Client.Util.Shake)
local Sound = require(Client.Util.Sound)

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
	vy: number, -- last vertical speed (a sudden stop = it hit the floor: tap)
}
local debris: { Debris } = {}
local maxDebris = World.MaxDebris -- Controllers/Quality lowers it on slow devices
local free: { Part } = {}
local confettiLive = 0 -- confetti bits in the air (they count toward the debris budget)

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

function DigFX.setMaxDebris(n: number)
	maxDebris = n
end

function DigFX.debrisCount(): number
	return #debris + confettiLive
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
	if #debris + confettiLive < maxDebris or #debris == 0 then
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
		vy = 0,
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

-- The punch landing: a quick white shock ring flat on the hit face + a dust puff.
local function impact(pos: Vector3, normal: Vector3, color: Color3)
	local at = pos + normal * (World.BlockSize / 2 + 0.06)
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.new(1, 1, 1)
	ring.Transparency = 0.25
	-- a cylinder's axis is its X: point it along the face normal
	ring.CFrame = CFrame.lookAt(at, at + normal) * CFrame.Angles(0, math.pi / 2, 0)
	ring.Size = Vector3.new(0.05, 0.6, 0.6)
	ring.Parent = folder
	TweenService:Create(
		ring,
		TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.05, 3.2, 3.2), Transparency = 1 }
	):Play()
	task.delay(0.2, function()
		ring:Destroy()
	end)
	puff(at, color, 4, 0.6)
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
	do
		local x, y, z = Voxel.unindex(t.grid, broken[1])
		DigAudio.broken(z, #broken, mine, Tunnel.blockCenter(t.frame, x, y, z))
	end
	if mine then
		Shake.punch(math.min(3.5, 1.2 + #broken * 0.15))
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
end

function DigFX.isVacuuming(): boolean
	return vacuumOn
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
	local inFlight = 0
	for _, d in debris do
		if d.sucked then
			inFlight += 1
		end
	end
	DigAudio.vacuum(vacuumOn, math.min(1, inFlight / 4))
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
				DigAudio.suck()
			end
		elseif not part.Anchored and d.kind == "chunk" then
			local vy = part.AssemblyLinearVelocity.Y
			if d.vy < -7 and vy > d.vy + 6 then
				DigAudio.land(part.Position, part.Size.X)
			end
			d.vy = vy
			if now - d.born > 6 or (now - d.born > 0.9 and part.AssemblyLinearVelocity.Magnitude < 0.7) then
				-- settled on the pile (or tumbling too long): freeze it, no physics cost while it waits
				part.Anchored = true
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
	-- fewer on a slower device (Controllers/Quality lowered the cap), and within the debris budget
	local count = if maxDebris < World.MaxDebris then 25 else 50
	count = math.min(count, math.max(10, maxDebris - #debris - confettiLive))
	confettiLive += count
	for i = 1, count do
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
			confettiLive -= 1
			p:Destroy()
		end)
	end
end

-- ===== gold, jackpots, cave-ins =====

-- Text that pops off a spot in the world and floats up (CRIT!, +1.2K, CAVE-IN!).
local function popText(at: Vector3, text: string, color: Color3, size: number, life: number)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = at
	holder.Parent = folder
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(size, 0, size * 0.32, 0)
	gui.StudsOffset = Vector3.new(0, 0.6, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.Rotation = math.random(-6, 6)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = color:Lerp(Color3.new(0, 0, 0), 0.75)
	stroke.Thickness = 2
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService
		:Create(gui, TweenInfo.new(life, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, 3, 0) })
		:Play()
	task.delay(life * 0.55, function()
		TweenService:Create(label, TweenInfo.new(life * 0.45), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(life * 0.45), { Transparency = 1 }):Play()
	end)
	task.delay(life + 0.05, function()
		holder:Destroy()
	end)
end
DigFX.popText = popText

local GOLD = Color3.fromRGB(255, 200, 60)
local JACKPOT = Color3.fromRGB(120, 230, 255)

-- Coins burst out of the block, hang for a beat, then fly into you.
local function coinFountain(from: Vector3, count: number, color: Color3)
	local r = root()
	for i = 1, count do
		local c = Instance.new("Part")
		c.Shape = Enum.PartType.Cylinder
		c.Size = Vector3.new(0.12, 0.55, 0.55)
		c.Color = color
		c.Material = Enum.Material.Neon
		c.CanCollide = false
		c.CanQuery = false
		c.CanTouch = false
		c.CastShadow = false
		c.Anchored = true
		c.CFrame = CFrame.new(from) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		c.Parent = folder
		local out = from
			+ Vector3.new((math.random() - 0.5) * 6, 1.5 + math.random() * 3.5, (math.random() - 0.5) * 6)
		local up = TweenService:Create(
			c,
			TweenInfo.new(0.28 + math.random() * 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = CFrame.new(out) * CFrame.Angles(math.random() * 6, math.random() * 6, 0) }
		)
		up:Play()
		task.delay(0.35 + i * 0.025, function()
			local target = if r and r.Parent then r.Position + Vector3.new(0, 1, 0) else out
			local fly = TweenService:Create(
				c,
				TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ CFrame = CFrame.new(target), Size = Vector3.new(0.05, 0.2, 0.2) }
			)
			fly:Play()
			fly.Completed:Connect(function()
				c:Destroy()
				if i % 3 == 0 then
					Sound.play("Coin", 0.35, 1.2 + math.random() * 0.3)
				end
			end)
		end)
	end
end

local function onGold(
	owner: number,
	x: number,
	y: number,
	z: number,
	kind: string,
	paid: number,
	puncher: number?
)
	local t = VoxelRender.get(owner)
	if not t or typeof(x) ~= "number" then
		return
	end
	local pos = Tunnel.blockCenter(t.frame, x, y, z)
	local jackpot = kind == "jackpot"
	local color = if jackpot then JACKPOT else GOLD
	if (puncher or owner) ~= player.UserId then
		-- someone else's gold: a glitter + a clink where it broke
		puff(pos, color, 10, 1)
		Sound.at("Chime", pos, 0.5, 1.3)
		return
	end
	puff(pos, color, if jackpot then 40 else 16, if jackpot then 1.6 else 1.1)
	coinFountain(pos, if jackpot then 34 else 12, color)
	popText(
		pos,
		"+" .. Format.number(paid) .. " 🍜",
		color,
		if jackpot then 7 else 4.5,
		if jackpot then 1.6 else 1.1
	)
	Sound.play("Dump", if jackpot then 0.9 else 0.55, if jackpot then 1 else 1.15)
	Sound.play("Chime", 0.6, if jackpot then 0.8 else 1.4)
	if jackpot then
		Sound.play("Rare", 0.9)
		popText(pos + Vector3.new(0, 2, 0), "JACKPOT!", JACKPOT, 9, 1.8)
		DigFX.confetti(pos)
		Shake.kick(1)
		Shake.punch(5)
	else
		Shake.kick(0.35)
	end
end

local function onCaveIn(owner: number, x: number, y: number, z: number, blocks: number, puncher: number?)
	local t = VoxelRender.get(owner)
	if not t or typeof(x) ~= "number" then
		return
	end
	local pos = Tunnel.blockCenter(t.frame, x, y, z)
	local dust = VoxelRender.blockColor(x, y, z):Lerp(Color3.new(1, 1, 1), 0.3)
	for _ = 1, 5 do
		local off =
			Vector3.new((math.random() - 0.5) * 6, (math.random() - 0.5) * 4, (math.random() - 0.5) * 6)
		puff(pos + off, dust, 14, 1.5)
	end
	if (puncher or owner) ~= player.UserId then
		Sound.at("BigBreak", pos, 0.8, 0.85, 120)
		return
	end
	Sound.play("BigBreak", 0.9, 0.85)
	Sound.play("Boom", 0.35, 1.3)
	popText(pos + Vector3.new(0, 1.5, 0), "CAVE-IN! x" .. blocks, Color3.fromRGB(255, 170, 90), 6, 1.3)
	Shake.kick(0.9)
	Shake.punch(4)
end

-- ===== vault doors =====

local function findDoor(owner: number, zone: number): Model?
	local f = workspace:FindFirstChild("VaultDoors")
	if not f then
		return nil
	end
	for _, m in f:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("Owner") == owner and m:GetAttribute("Zone") == zone then
			return m
		end
	end
	return nil
end

local shaking: { [Model]: boolean } = {}
local function shakeDoor(m: Model, strength: number)
	if shaking[m] then
		return
	end
	shaking[m] = true
	local base = m:GetPivot()
	task.spawn(function()
		for k = 1, 5 do
			if not m.Parent then
				break
			end
			local a = strength * (1 - k / 6)
			m:PivotTo(base * CFrame.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0))
			task.wait(0.03)
		end
		if m.Parent then
			m:PivotTo(base)
		end
		shaking[m] = nil
	end)
end

local function onBoss(kind: string, owner: number, zone: number, hp: number?, max: number?, puncher: number?)
	local door = findDoor(owner, zone)
	local mine = owner == player.UserId or puncher == player.UserId
	local center = if door then door:GetPivot().Position else nil
	if kind == "appear" then
		if center then
			puff(center, Color3.fromRGB(150, 150, 150), 30, 2)
			Sound.at("CellDoor", center, 1, 0.6, 120)
		end
		if mine then
			Shake.kick(0.6)
		end
	elseif kind == "hit" then
		if door and center then
			shakeDoor(door, if puncher == player.UserId then 0.5 else 0.25)
			local toward = (door:GetPivot().LookVector * -1)
			impact(center + toward * 0.6, toward, Color3.fromRGB(255, 220, 140))
			Sound.at("HitMetal", center, 0.7, 0.8 + (1 - (hp or 0) / math.max(max or 1, 1)) * 0.4, 90)
		end
	elseif kind == "dead" then
		if door and center then
			for _ = 1, 6 do
				puff(
					center + Vector3.new((math.random() - 0.5) * 8, (math.random() - 0.5) * 6, 0),
					Color3.fromRGB(170, 160, 150),
					20,
					2
				)
			end
			Sound.at("Boom", center, 1, 0.9, 160)
			Sound.at("BigBreak", center, 1, 0.8, 160)
			-- the door tips over toward you
			local base = door:GetPivot()
			local value = Instance.new("CFrameValue")
			value.Value = base
			value.Changed:Connect(function(cf)
				if door.Parent then
					door:PivotTo(cf)
				end
			end)
			TweenService:Create(value, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Value = base * CFrame.new(0, -3, 2.5) * CFrame.Angles(math.rad(-80), 0, 0),
			}):Play()
			task.delay(1.2, function()
				value:Destroy()
			end)
			if mine then
				DigFX.confetti(center)
				Shake.kick(1)
				Shake.punch(6)
				popText(center + Vector3.new(0, 3, 0), "VAULT CRACKED!", Color3.fromRGB(255, 210, 90), 9, 1.8)
				Sound.play("Zone", 0.8)
			end
		end
	elseif kind == "reward" then
		local paid = hp or 0
		local at = center or (if root() then (root() :: BasePart).Position + Vector3.new(0, 3, 0) else nil)
		if at then
			coinFountain(at, 24, GOLD)
			popText(at + Vector3.new(0, 1, 0), "+" .. Format.number(paid) .. " 🍜", GOLD, 7, 1.6)
		end
		Sound.play("Dump", 0.9)
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
	Remotes.get(Remotes.Names.Gold).OnClientEvent:Connect(onGold)
	Remotes.get(Remotes.Names.CaveIn).OnClientEvent:Connect(onCaveIn)
	Remotes.get(Remotes.Names.Boss).OnClientEvent:Connect(onBoss)
	-- CRIT: a hot flash, a bigger kick and a "CRIT!" that pops off the block
	Remotes.get(Remotes.Names.Crit).OnClientEvent
		:Connect(function(x: number, y: number, z: number, owner: number?)
			local t = if owner then VoxelRender.get(owner) else VoxelRender.own()
			if not t or typeof(x) ~= "number" then
				return
			end
			local pos = Tunnel.blockCenter(t.frame, x, y, z)
			local r = root()
			local toward = if r then (r.Position - pos).Unit else Vector3.yAxis
			local at = pos + toward * 1.4
			puff(at, Color3.fromRGB(255, 200, 90), 1, 1.4)
			impact(at, toward, Color3.fromRGB(255, 210, 110))
			Shake.kick(0.45)
			Shake.punch(3.5)
			Sound.play("Fist", 0.9, 0.62)
			Sound.play("Chime", 0.5, 1.5)
			local holder = Instance.new("Part")
			holder.Anchored = true
			holder.CanCollide = false
			holder.CanQuery = false
			holder.Transparency = 1
			holder.Size = Vector3.one
			holder.Position = at
			holder.Parent = folder
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.new(5, 0, 1.6, 0)
			gui.StudsOffset = Vector3.new(0, 0.6, 0)
			gui.AlwaysOnTop = true
			gui.LightInfluence = 0
			gui.Parent = holder
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Text = "CRIT!"
			label.Font = Enum.Font.GothamBlack
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(255, 196, 60)
			label.Rotation = math.random(-8, 8)
			label.Parent = gui
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(80, 30, 0)
			stroke.Thickness = 2
			stroke.Parent = label
			local scale = Instance.new("UIScale")
			scale.Scale = 0.3
			scale.Parent = label
			TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			TweenService
				:Create(
					gui,
					TweenInfo.new(0.7, Enum.EasingStyle.Quad),
					{ StudsOffset = Vector3.new(0, 2.4, 0) }
				)
				:Play()
			task.delay(0.35, function()
				TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
				TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			end)
			task.delay(0.75, function()
				holder:Destroy()
			end)
		end)
end

-- hit sparks at the aimed block (called by the HUD wiring when a punch lands)
DigFX.sparks = sparks
DigFX.impact = impact

return DigFX
