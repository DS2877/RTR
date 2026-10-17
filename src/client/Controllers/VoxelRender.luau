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
local Strata = require(Shared.Strata)

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
VoxelRender.onHit = nil :: ((t: T, puncher: number, z: number) -> ())?
VoxelRender.onBroken = nil :: ((t: T, broken: { number }, puncher: number) -> ())?
VoxelRender.onDamaged = nil :: ((t: T, damaged: { number }, puncher: number) -> ())?
VoxelRender.onChamber = nil :: ((t: T, zone: number) -> ())?
VoxelRender.onLoaded = nil :: ((t: T) -> ())? -- a tunnel snapshot arrived
VoxelRender.onDropped = nil :: ((owner: number) -> ())?

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
	local shade = 0.95 + Progression.hash01(0, x, y, z, 11) * 0.07
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

-- glowing features (crystals, lava, slime) with a PointLight, per client
-- (Controllers/Quality lowers it on slow devices, together with the stream radius)
local MAX_LIGHTS = 28
local streamRadius = World.StreamRadius
local lit: { [Part]: boolean } = {}
local litCount = 0
local function unlight(p: Part)
	if lit[p] then
		lit[p] = nil
		litCount -= 1
	end
end

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
	local q = p :: Part
	q.Shape = Enum.PartType.Block
	q.CanCollide = true
	q.Transparency = 0
	return q
end

-- running hit-jolt tweens (cancelled when the part goes back to the pool)
local jolting: { [BasePart]: Tween } = {}

local function release(p: Part)
	local tw = jolting[p]
	if tw then
		jolting[p] = nil
		tw:Cancel()
	end
	partCount -= 1
	unlight(p)
	p.Parent = nil
	for _, c in p:GetChildren() do
		c:Destroy()
	end
	table.insert(pool, p)
end

-- cracks are built once per (stage, variant) and cloned: 8 looks per stage are plenty, and a
-- clone is far cheaper than ~40 new Frames per face on every hit
local crackTemplates: { [number]: SurfaceGui } = {}

local function buildCrack(stage: number, seed: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Crack"
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
	return gui
end

local function crackGui(p: Part, face: Enum.NormalId, stage: number, seed: number)
	local s = math.clamp(stage, 1, 3)
	local key = s * 8 + seed % 8
	local template = crackTemplates[key]
	if not template then
		template = buildCrack(s, key * 7919)
		crackTemplates[key] = template
	end
	local gui = (template :: SurfaceGui):Clone()
	gui.Face = face
	gui.Parent = p
end

-- ===== zone features (Shared/Strata): pipes, rebar, lava veins, crystals, carvings =====

local featureMaterial: { [string]: Enum.Material } = {}
local function materialOf(name: string): Enum.Material
	local m = featureMaterial[name]
	if not m then
		local ok, value = pcall(function()
			return (Enum.Material :: any)[name]
		end)
		m = if ok and value then value else Enum.Material.SmoothPlastic
		featureMaterial[name] = m
	end
	return m :: Enum.Material
end

-- a pattern scratched into an open face: prison tally marks or an ancient glyph
local function carveGui(p: Part, face: Enum.NormalId, kind: string, seed: number)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Carve"
	gui.Face = face
	gui.LightInfluence = 1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(64, 64)
	local r = Random.new(seed)
	local ink = if kind == "Tally"
		then Color3.fromRGB(40, 40, 44)
		elseif kind == "Rebar" then Color3.fromRGB(112, 58, 34)
		else Color3.fromRGB(110, 82, 40)
	local function bar(x: number, y: number, w: number, hgt: number, rot: number)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = ink
		f.BackgroundTransparency = 0.15
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(w, hgt)
		f.Rotation = rot
		f.Parent = gui
	end
	if kind == "Rebar" then
		-- rusty steel bars showing through the broken concrete
		bar(32, 22, 64, 6, 0)
		bar(32, 46, 64, 6, 0)
		bar(22, 32, 6, 64, 0)
		bar(44, 32, 6, 64, 0)
	elseif kind == "Tally" then
		local n = r:NextInteger(3, 5)
		for i = 1, n - (if n == 5 then 1 else 0) do
			bar(18 + i * 7, 32 + r:NextNumber(-1, 1), 2, 26, r:NextNumber(-4, 4))
		end
		if n == 5 then
			bar(35, 32, 2, 38, 62)
		end
	else
		-- a frame with a symbol: eye / sun / steps, chosen per block
		bar(32, 10, 40, 3, 0)
		bar(32, 54, 40, 3, 0)
		local pick = r:NextInteger(1, 3)
		if pick == 1 then
			bar(32, 32, 26, 3, 0)
			bar(32, 32, 10, 10, 45)
		elseif pick == 2 then
			bar(32, 32, 12, 12, 0)
			for a = 0, 3 do
				bar(32, 32, 30, 2, a * 45)
			end
		else
			for k = 0, 3 do
				bar(20 + k * 8, 46 - k * 8, 8, 3 + k * 8, 0)
			end
		end
	end
	gui.Parent = p
end

-- Gives a rendered block its feature look; returns the color to use (nil = plain rock).
local function applyFeature(t: T, x: number, y: number, z: number, p: Part): Color3?
	local id = Strata.featureAt(x, y, z)
	if not id then
		return nil
	end
	local look = Strata.Looks[id]
	if not look then
		return nil
	end
	p.Material = materialOf(look.material)
	local c = look.color
	local s = 1 + ((Progression.hash01(0, x, y, z, 13) - 0.5) * 2 * (look.shade or 0))
	if look.carve then
		for f, n in Voxel.Faces do
			if Voxel.isOpen(t.grid, x + n[1], y + n[2], z + n[3]) then
				carveGui(p, FACE_IDS[f], look.carve, x * 131 + y * 17 + z * 7 + f)
			end
		end
	end
	if look.glow and litCount < MAX_LIGHTS then
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(look.glow[1], look.glow[2], look.glow[3])
		l.Range = 9
		l.Brightness = 0.9
		l.Shadows = false
		l.Parent = p
		lit[p] = true
		litCount += 1
	end
	return Color3.fromRGB(math.min(255, c[1] * s), math.min(255, c[2] * s), math.min(255, c[3] * s))
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

local GOLD_ROCK = Color3.fromRGB(214, 160, 52)
local GOLD_GLOW = Color3.fromRGB(255, 214, 90)
local JACKPOT_ROCK = Color3.fromRGB(70, 150, 190)
local JACKPOT_GLOW = Color3.fromRGB(150, 245, 255)

local function styleBlock(t: T, idx: number, p: Part)
	local x, y, z = Voxel.unindex(t.grid, idx)
	local zone = Progression.zoneAt(z)
	p.Size = Vector3.new(B, B, B)
	p.CFrame = t.frame * CFrame.new(Tunnel.localCenter(x, y, z))
	p.Material = if z >= MAX_Z then Enum.Material.Basalt else zoneMaterial(zone)
	local color = VoxelRender.blockColor(x, y, z)
	local find = if z < MAX_Z then Progression.findAt(t.seed, x, y, z) else nil
	-- gold / jackpot blocks: the rock is shot through with metal (it pays the moment it breaks)
	local gold = if find == nil and z < MAX_Z then Progression.goldAt(t.seed, x, y, z) else nil
	if find then
		color = color:Lerp(Color3.new(0, 0, 0), 0.45)
	end
	unlight(p)
	if gold then
		color = if gold == "jackpot" then JACKPOT_ROCK else GOLD_ROCK
		p.Material = Enum.Material.Foil
	elseif not find and z < MAX_Z then
		color = applyFeature(t, x, y, z, p) or color
	end
	local stage = t.damage[idx]
	p:SetAttribute("Stage", stage) -- (the delta skips the restyle while this stays the same)
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
	-- ore: a glowing vein through the block, the color of the find's rarity (gold: a gold vein)
	local glint = t.glints[idx]
	if (find or gold) and not glint then
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
		if find then
			local tier = Rarity.Tiers[Finds.ById[find].rarity]
			g.Color = Color3.fromRGB(tier.color[1], tier.color[2], tier.color[3])
			g.Size = Vector3.new(B * 1.04, 0.32, 0.32)
		else
			g.Color = if gold == "jackpot" then JACKPOT_GLOW else GOLD_GLOW
			g.Size = Vector3.new(B * 1.04, 0.42, 0.42)
		end
		local spin = Progression.hash01(t.seed, x, y, z, 5) * math.pi
		g.CFrame = p.CFrame * CFrame.Angles(spin, 0, math.pi / 4)
		g.Parent = folder
		t.glints[idx] = g
	elseif not (find or gold) and glint then
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
		return t.damage[idx] ~= nil
			or Progression.findAt(t.seed, x, y, z) ~= nil
			or Progression.goldAt(t.seed, x, y, z) ~= nil
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
	-- dug floor (y = 0): a thin plate in the zone's material so you never walk on black bedrock
	-- (one plate per row of dug floor blocks). (No free lamps: you buy Decor lamps and place them.)
	local cx, cy, cz = Voxel.chunkCoords(t.grid, id)
	local x0, z0 = cx * CS, cz * CS
	if cy == 0 then
		for z = z0, math.min(z0 + CS - 1, MAX_Z - 1) do
			local runStart: number? = nil
			for x = x0, math.min(x0 + CS, W) do
				local open = x < math.min(x0 + CS, W) and Voxel.isDug(t.grid, x, 0, z)
				if open and not runStart then
					runStart = x
				elseif not open and runStart then
					local zone = Zones[Progression.zoneAt(z)]
					local c = zone.palette[1]
					local p = acquire()
					local len = x - runStart
					p.Size = Vector3.new(len * B, 0.2, B)
					p.CFrame = t.frame
						* CFrame.new(
							Tunnel.localCenter((runStart + x - 1) / 2, 0, z) - Vector3.new(0, B / 2 - 0.1, 0)
						)
					p.Material = zoneMaterial(Progression.zoneAt(z))
					p.Color = Color3.fromRGB(c[1] * 0.82, c[2] * 0.82, c[3] * 0.82)
					p.Parent = folder
					table.insert(runParts, p)
					runStart = nil
				end
			end
		end
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
	if VoxelRender.onDropped then
		VoxelRender.onDropped(owner)
	end
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
		local R = streamRadius
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

-- The rendered part of a block jolting from a hit (strength 0..1). Rests at its grid spot.
local function jolt(p: BasePart, strength: number)
	if jolting[p] then
		return
	end
	local base = p.CFrame
	local j = 0.18 * strength
	p.CFrame = base
		* CFrame.new((math.random() - 0.5) * j, (math.random() - 0.5) * j, -j)
		* CFrame.Angles((math.random() - 0.5) * 0.1 * strength, (math.random() - 0.5) * 0.1 * strength, 0)
	local tw = TweenService:Create(p, TweenInfo.new(0.18, Enum.EasingStyle.Back), { CFrame = base })
	jolting[p] = tw
	tw.Completed:Once(function()
		if jolting[p] == tw then
			jolting[p] = nil
		end
	end)
	tw:Play()
end

function VoxelRender.jolt(t: T, x: number, y: number, z: number)
	local p = t.parts[Voxel.index(t.grid, x, y, z)]
	if p then
		jolt(p, 1)
	end
end

-- Quality level: how far tunnels are drawn (blocks) and how many glowing parts get a real light.
function VoxelRender.setBudget(radius: number, lights: number)
	streamRadius = radius
	MAX_LIGHTS = lights
end

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
		if VoxelRender.onLoaded then
			VoxelRender.onLoaded(t)
		end
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
				-- same crack stage as drawn: no rebuild, the jolt alone shows the hit
				if p:GetAttribute("Stage") ~= stage then
					for _, c in p:GetChildren() do
						c:Destroy()
					end
					styleBlock(t, idx, p)
				end
				-- the block jolts from the hit (your own punches already jolted it locally)
				if puncher ~= Players.LocalPlayer.UserId then
					jolt(p, 1)
				end
			else
				local x, y, z = Voxel.unindex(g, idx)
				t.dirty[Voxel.chunkOf(g, x, y, z)] = true
			end
		end
		local first = broken[1] or damaged[1]
		if VoxelRender.onHit and first then
			local _, _, hz = Voxel.unindex(g, first)
			VoxelRender.onHit(t, puncher, hz)
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
