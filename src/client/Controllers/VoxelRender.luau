--!strict
-- Draws the tunnels near the camera. The server sends a snapshot of a tunnel when you come near it
-- and small deltas after every punch; this keeps a copy of each grid and renders only its shell
-- (solid blocks touching dug air + the intact back wall, merged into runs), per 8x8x8 chunk, within
-- World.StreamRadius blocks of the camera, with pooled parts and a hard part budget.
-- Your character collides with these local parts (each client simulates its own character).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Zones = require(Shared.Config.Zones)
local Finds = require(Shared.Config.Finds)
local Rarity = require(Shared.Config.Rarity)
local Voxel = require(Shared.Voxel)
local Shell = require(Shared.Shell)
local Progression = require(Shared.Progression)
local Tunnel = require(Shared.Tunnel)
local Remotes = require(Shared.Remotes)
local Economy = require(Shared.Config.Economy)

local VoxelRender = {}

local W, H, D, CS = World.TunnelWidth, World.TunnelHeight, World.TunnelDepth, World.ChunkSize
local B = World.BlockSize
local MAX_Z = Progression.diggableDepth()

export type T = {
	owner: number,
	cell: number,
	frame: CFrame,
	seed: number,
	grid: any,
	damage: { [number]: number }, -- idx -> crack stage 1..3
	parts: { [number]: Part }, -- idx -> part
	glints: { [number]: Part },
	chunkBlocks: { [number]: { number } },
	runParts: { [number]: { Part } },
	rendered: { [number]: boolean },
	dirty: { [number]: boolean },
}

local tunnels: { [number]: T } = {}
local folder: Folder
local pool: { Part } = {}
local glintPool: { Part } = {}
local partCount = 0
local imposters: { [number]: Part } = {}

-- callbacks for FX (set by other controllers)
VoxelRender.onBroken = nil :: ((t: T, broken: { number }, puncher: number) -> ())?
VoxelRender.onDamaged = nil :: ((t: T, damaged: { number }, puncher: number) -> ())?
VoxelRender.onChamber = nil :: ((t: T, zone: number) -> ())?

-- ===== appearance =====

local materialCache: { [number]: Enum.Material } = {}
local function zoneMaterial(zone: number): Enum.Material
	local m = materialCache[zone]
	if not m then
		local ok, value = pcall(function()
			return (Enum.Material :: any)[Zones[zone].material]
		end)
		m = if ok and value then value else Enum.Material.SmoothPlastic
		materialCache[zone] = m
	end
	return m :: Enum.Material
end

local LOCKED = Color3.fromRGB(34, 32, 38)

function VoxelRender.blockColor(x: number, y: number, z: number): Color3
	if z >= MAX_Z then
		return LOCKED
	end
	local zone = Zones[Progression.zoneAt(z)]
	local pal = zone.palette
	if z == 0 then
		-- the intact wall is one seamless surface: every face block has exactly the same color
		local c = pal[1]
		return Color3.fromRGB(c[1], c[2], c[3])
	end
	-- inside the hole every voxel is a touch lighter or darker, so its edges read like carved stone
	local h = Progression.hash01(0, x, y, z, 9)
	local c = pal[1 + math.floor(h * #pal) % #pal]
	local shade = 0.9 + Progression.hash01(0, x, y, z, 11) * 0.14
	return Color3.fromRGB(
		math.min(255, c[1] * shade),
		math.min(255, c[2] * shade),
		math.min(255, c[3] * shade)
	)
end

local FACE_IDS = {
	Enum.NormalId.Right,
	Enum.NormalId.Left,
	Enum.NormalId.Top,
	Enum.NormalId.Bottom,
	Enum.NormalId.Front, -- grid +z = deeper = part local -Z
	Enum.NormalId.Back,
}

local function acquire(): Part
	local p = table.remove(pool)
	if not p then
		p = Instance.new("Part")
		p.Anchored = true
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Name = "V"
	end
	partCount += 1
	return p :: Part
end

local function release(p: Part)
	partCount -= 1
	p.Parent = nil
	for _, c in p:GetChildren() do
		c:Destroy()
	end
	table.insert(pool, p)
end

local function crackGui(p: Part, face: Enum.NormalId, stage: number, seed: number)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Crack"
	gui.Face = face
	gui.LightInfluence = 1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(64, 64)
	-- jagged, branching cracks: chains of short segments that drift in direction
	local r = Random.new(seed)
	local chains = ({ 2, 4, 7 })[math.clamp(stage, 1, 3)]
	for c = 1, chains do
		local x, y = 32 + r:NextNumber(-12, 12), 32 + r:NextNumber(-12, 12)
		local angle = r:NextNumber(0, math.pi * 2)
		for _ = 1, 3 + r:NextInteger(0, stage) do
			local len = r:NextNumber(5, 11)
			local nx, ny = x + math.cos(angle) * len, y + math.sin(angle) * len
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			f.BackgroundColor3 = Color3.fromRGB(24, 22, 22)
			f.BackgroundTransparency = if c % 2 == 0 then 0.25 else 0.05
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromOffset((x + nx) / 2, (y + ny) / 2)
			f.Size = UDim2.fromOffset(len + 1, if c == 1 then 2 else 1)
			f.Rotation = math.deg(angle)
			f.Parent = gui
			x, y = nx, ny
			angle += r:NextNumber(-0.9, 0.9)
		end
	end
	gui.Parent = p
end

-- escaped prisoners land in tougher prisons: their tunnel gets that prison's tint
local function tierTint(owner: number): Color3?
	local p = Players:GetPlayerByUserId(owner)
	local r = p and p:GetAttribute("Rebirths")
	if typeof(r) ~= "number" or r <= 0 then
		return nil
	end
	local prisons = Economy.Prisons
	local tier = prisons[math.min(r + 1, #prisons)]
	return Color3.fromRGB(tier.tint[1], tier.tint[2], tier.tint[3])
end

local function styleBlock(t: T, idx: number, p: Part)
	local x, y, z = Voxel.unindex(t.grid, idx)
	local zone = Progression.zoneAt(z)
	p.Size = Vector3.new(B, B, B)
	p.CFrame = t.frame * CFrame.new(Tunnel.localCenter(x, y, z))
	p.Material = if z >= MAX_Z then Enum.Material.Basalt else zoneMaterial(zone)
	local color = VoxelRender.blockColor(x, y, z)
	local find = if z < MAX_Z then Progression.findAt(t.seed, x, y, z) else nil
	if find then
		color = color:Lerp(Color3.new(0, 0, 0), 0.45)
	end
	local stage = t.damage[idx]
	if stage then
		color = color:Lerp(Color3.new(0, 0, 0), 0.08 * stage)
		for f, n in Voxel.Faces do
			if Voxel.isOpen(t.grid, x + n[1], y + n[2], z + n[3]) then
				crackGui(p, FACE_IDS[f], stage, idx * 7 + stage)
			end
		end
	end
	local tint = tierTint(t.owner)
	if tint then
		color = color:Lerp(tint, 0.3)
	end
	p.Color = color
	-- ore: a glowing vein through the block, the color of the find's rarity
	local glint = t.glints[idx]
	if find and not glint then
		local g = table.remove(glintPool)
		if not g then
			g = Instance.new("Part")
			g.Anchored = true
			g.CanCollide = false
			g.CanTouch = false
			g.CanQuery = false
			g.CastShadow = false
			g.Material = Enum.Material.Neon
			g.Name = "Glint"
		end
		assert(g, "glint")
		local tier = Rarity.Tiers[Finds.ById[find].rarity]
		g.Color = Color3.fromRGB(tier.color[1], tier.color[2], tier.color[3])
		g.Size = Vector3.new(B * 1.04, 0.32, 0.32)
		local spin = Progression.hash01(t.seed, x, y, z, 5) * math.pi
		g.CFrame = p.CFrame * CFrame.Angles(spin, 0, math.pi / 4)
		g.Parent = folder
		t.glints[idx] = g
	elseif not find and glint then
		glint.Parent = nil
		table.insert(glintPool, glint)
		t.glints[idx] = nil
	end
end

local function dropBlock(t: T, idx: number)
	local p = t.parts[idx]
	if p then
		release(p)
		t.parts[idx] = nil
	end
	local g = t.glints[idx]
	if g then
		g.Parent = nil
		table.insert(glintPool, g)
		t.glints[idx] = nil
	end
end

local function dropChunk(t: T, id: number)
	for _, idx in t.chunkBlocks[id] or {} do
		dropBlock(t, idx)
	end
	t.chunkBlocks[id] = nil
	for _, p in t.runParts[id] or {} do
		release(p)
	end
	t.runParts[id] = nil
	t.rendered[id] = nil
end

local function buildChunk(t: T, id: number)
	local special = function(x: number, y: number, z: number): boolean
		local idx = Voxel.index(t.grid, x, y, z)
		return t.damage[idx] ~= nil or Progression.findAt(t.seed, x, y, z) ~= nil
	end
	local blocks, runs = Shell.chunk(t.grid, id, special)
	local keep: { [number]: boolean } = {}
	for _, idx in blocks do
		keep[idx] = true
	end
	for _, idx in t.chunkBlocks[id] or {} do
		if not keep[idx] then
			dropBlock(t, idx)
		end
	end
	for _, idx in blocks do
		local p = t.parts[idx]
		if not p then
			p = acquire()
			t.parts[idx] = p
		else
			for _, c in p:GetChildren() do
				c:Destroy()
			end
		end
		assert(p, "part")
		styleBlock(t, idx, p)
		p.Parent = folder
	end
	t.chunkBlocks[id] = blocks
	for _, p in t.runParts[id] or {} do
		release(p)
	end
	local runParts = {}
	for _, r in runs do
		local p = acquire()
		local len = r.x1 - r.x0 + 1
		local cx = (r.x0 + r.x1) / 2
		p.Size = Vector3.new(len * B, B, B)
		p.CFrame = t.frame * CFrame.new(Tunnel.localCenter(cx, r.y, 0))
		p.Material = zoneMaterial(1)
		p.Color = VoxelRender.blockColor(r.x0, r.y, 0)
		p.Parent = folder
		table.insert(runParts, p)
	end
	t.runParts[id] = runParts
	t.rendered[id] = true
	t.dirty[id] = nil
end

-- marks the chunk of a block (and neighbor chunks when it sits on a chunk edge) for a rebuild
local function touch(t: T, x: number, y: number, z: number)
	local g = t.grid
	t.dirty[Voxel.chunkOf(g, x, y, z)] = true
	for _, f in Voxel.Faces do
		local nx, ny, nz = x + f[1], y + f[2], z + f[3]
		if Voxel.inBounds(g, nx, ny, nz) then
			t.dirty[Voxel.chunkOf(g, nx, ny, nz)] = true
		end
	end
end

local function dropTunnel(owner: number)
	local t = tunnels[owner]
	if not t then
		return
	end
	for id in table.clone(t.rendered) do
		dropChunk(t, id)
	end
	tunnels[owner] = nil
	local imp = imposters[t.cell]
	if imp then
		imp.Parent = folder
	end
end

-- ===== streaming =====

local function cameraPos(): Vector3
	local cam = workspace.CurrentCamera
	return if cam then cam.CFrame.Position else Vector3.zero
end

-- Rebuilds up to `budget` chunks (nearest first), drops chunks out of range.
local function stream(budget: number)
	local pos = cameraPos()
	local want: { { t: T, id: number, d: number } } = {}
	for _, t in tunnels do
		local g = t.grid
		local bx, by, bz = Tunnel.toBlock(t.frame, pos)
		local inside = Tunnel.inside(t.frame, pos, 1)
		local R = World.StreamRadius
		local zMax = if inside then D - 1 else math.min(D - 1, World.OutsideRenderDepth - 1)
		local czLo = math.max(0, (math.max(0, bz - R)) // CS)
		local czHi = math.min(g.ncz - 1, math.max(0, math.min(zMax, bz + R)) // CS)
		local desired: { [number]: boolean } = {}
		local lateral = math.abs(bx - W / 2) - W / 2 -- blocks to the side of the volume
		if lateral <= R and bz - R <= zMax then
			for cz = czLo, czHi do
				for cy = 0, g.ncy - 1 do
					for cx = 0, g.ncx - 1 do
						local id = Voxel.chunkId(g, cx, cy, cz)
						desired[id] = true
						if not t.rendered[id] or t.dirty[id] then
							local dz = math.abs((cz + 0.5) * CS - bz)
							local dx = math.abs((cx + 0.5) * CS - bx)
							local dy = math.abs((cy + 0.5) * CS - by)
							table.insert(want, { t = t, id = id, d = dz + dx * 0.5 + dy * 0.5 })
						end
					end
				end
			end
		end
		for id in table.clone(t.rendered) do
			if not desired[id] then
				dropChunk(t, id)
			end
		end
		-- the imposter wall hides while the real back wall is drawn
		local imp = imposters[t.cell]
		if imp then
			local front = true
			for cy = 0, g.ncy - 1 do
				for cx = 0, g.ncx - 1 do
					if not t.rendered[Voxel.chunkId(g, cx, cy, 0)] then
						front = false
					end
				end
			end
			imp.Parent = if front then nil else folder
		end
	end
	table.sort(want, function(a, b)
		return a.d < b.d
	end)
	for i, w in want do
		if i > budget then
			break
		end
		if partCount >= World.MaxVoxelParts and not w.t.rendered[w.id] then
			break
		end
		buildChunk(w.t, w.id)
	end
end

-- ===== public =====

function VoxelRender.get(owner: number): T?
	return tunnels[owner]
end

function VoxelRender.own(): T?
	return tunnels[Players.LocalPlayer.UserId]
end

function VoxelRender.partCount(): number
	return partCount
end

function VoxelRender.all(): { [number]: T }
	return tunnels
end

local function buildImposters()
	for cell = 1, World.CellCount do
		local frame = Tunnel.frame(cell)
		local p = Instance.new("Part")
		p.Name = "Wall" .. cell
		p.Anchored = true
		p.CanTouch = false
		p.CastShadow = false
		p.Material = zoneMaterial(1)
		p.Color = VoxelRender.blockColor(3, 3, 0)
		p.Size = Vector3.new(W * B, H * B, B)
		p.CFrame = frame * CFrame.new(0, H * B / 2, -B / 2)
		p.Parent = folder
		imposters[cell] = p
	end
end

function VoxelRender.start()
	folder = Instance.new("Folder")
	folder.Name = "Voxels"
	folder.Parent = workspace
	buildImposters()

	Remotes.get(Remotes.Names.Snapshot).OnClientEvent:Connect(function(owner, cell, seed, data, damage)
		dropTunnel(owner)
		local t: T = {
			owner = owner,
			cell = cell,
			frame = Tunnel.frame(cell),
			seed = seed,
			grid = Voxel.deserialize(data, W, H, D, CS),
			damage = {},
			parts = {},
			glints = {},
			chunkBlocks = {},
			runParts = {},
			rendered = {},
			dirty = {},
		}
		for i = 1, #damage - 1, 2 do
			t.damage[damage[i]] = damage[i + 1]
		end
		tunnels[owner] = t
		stream(40)
	end)

	Remotes.get(Remotes.Names.Delta).OnClientEvent:Connect(function(owner, broken, damaged, puncher)
		local t = tunnels[owner]
		if not t then
			return
		end
		local g = t.grid
		for _, idx in broken do
			local x, y, z = Voxel.unindex(g, idx)
			Voxel.dig(g, x, y, z)
			t.damage[idx] = nil
			touch(t, x, y, z)
		end
		local damagedIdx = {}
		for i = 1, #damaged - 1, 2 do
			local idx, stage = damaged[i], damaged[i + 1]
			t.damage[idx] = stage
			table.insert(damagedIdx, idx)
			local p = t.parts[idx]
			if p then
				for _, c in p:GetChildren() do
					c:Destroy()
				end
				styleBlock(t, idx, p)
				-- the block jolts from the hit
				local base = p.CFrame
				local j = 0.14
				p.CFrame = base
					* CFrame.new((math.random() - 0.5) * j, (math.random() - 0.5) * j, -j)
					* CFrame.Angles((math.random() - 0.5) * 0.08, (math.random() - 0.5) * 0.08, 0)
				TweenService:Create(p, TweenInfo.new(0.16, Enum.EasingStyle.Back), { CFrame = base }):Play()
			else
				local x, y, z = Voxel.unindex(g, idx)
				t.dirty[Voxel.chunkOf(g, x, y, z)] = true
			end
		end
		if VoxelRender.onBroken and #broken > 0 then
			VoxelRender.onBroken(t, broken, puncher)
		end
		if VoxelRender.onDamaged and #damagedIdx > 0 then
			VoxelRender.onDamaged(t, damagedIdx, puncher)
		end
		-- rebuild the touched chunks right away (no waiting for the stream tick)
		for id in table.clone(t.dirty) do
			if t.rendered[id] then
				buildChunk(t, id)
			end
		end
	end)

	Remotes.get(Remotes.Names.Chamber).OnClientEvent:Connect(function(owner, zone)
		local t = tunnels[owner]
		local b = Progression.chamberBox(zone)
		if not t or not b then
			return
		end
		for z = b.z0, b.z1 do
			for y = b.y0, b.y1 do
				for x = b.x0, b.x1 do
					Voxel.dig(t.grid, x, y, z)
					t.damage[Voxel.index(t.grid, x, y, z)] = nil
				end
			end
		end
		for z = b.z0 - 1, b.z1 + 1, CS // 2 do
			for x = b.x0 - 1, b.x1 + 1, CS // 2 do
				for y = 0, b.y1 + 1, CS // 2 do
					if Voxel.inBounds(t.grid, x, y, z) then
						t.dirty[Voxel.chunkOf(t.grid, x, y, z)] = true
					end
				end
			end
		end
		for id in table.clone(t.dirty) do
			if t.rendered[id] then
				buildChunk(t, id)
			end
		end
		if VoxelRender.onChamber then
			VoxelRender.onChamber(t, zone)
		end
	end)

	Remotes.get(Remotes.Names.Drop).OnClientEvent:Connect(dropTunnel)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.15 then
			acc = 0
			stream(6)
		end
	end)

	Remotes.get(Remotes.Names.Ready):FireServer()
end

return VoxelRender
