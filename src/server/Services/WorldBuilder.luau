--!strict
-- Builds the whole map at runtime: home plaza, 8 player bases, Rich Street with its vaults,
-- the WANTED board (the richest player), the reign leaderboard and the fuse machine.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Vaults = require(Shared.Config.Vaults)
local Cosmetics = require(Shared.Config.Cosmetics)
local WorldDecor = require(script.Parent.WorldDecor)

local WorldBuilder = {}

local FLOOR = 0.4 -- top of base/vault floors
local BARRIER_HEIGHT = 50 -- invisible wall above the low base walls (no jumping in)

export type BaseRecord = {
	id: number,
	origin: CFrame, -- front center at ground level; LookVector points into the base
	model: Model,
	color: Color3,
	pedestals: { BasePart },
	laser: BasePart,
	belt: BasePart,
	collectPad: BasePart,
	pendingLabel: TextLabel,
	signLabel: TextLabel,
	plotSign: BasePart,
	treadSign: BasePart,
	beam: BasePart,
	rings: { BasePart }, -- glowing ring under each pedestal (lit when unlocked)
	spawnCFrame: CFrame,
}

export type VaultRecord = {
	index: number,
	origin: CFrame,
	center: Vector3,
	model: Model,
	pedestals: { BasePart },
	guardSpawns: { CFrame },
}

export type WorldInfo = {
	bases: { BaseRecord },
	vaults: { VaultRecord },
	wanted: { [string]: any }, -- Image (ImageLabel list), Title/Name/Bounty (TextLabel lists)
	reignLines: { TextLabel },
	fusePrompt: ProximityPrompt,
	trailsPrompt: ProximityPrompt,
	streetEnd: number,
	halloween: boolean,
}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function surfaceText(
	p: BasePart,
	face: Enum.NormalId,
	text: string,
	textColor: Color3,
	bg: Color3?,
	font: Enum.Font?
): TextLabel
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = if bg then 0 else 1
	l.BackgroundColor3 = bg or Color3.new()
	l.Font = font or Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = textColor
	local s = Instance.new("UIStroke")
	s.Thickness = 4
	s.Color = Color3.fromRGB(20, 20, 25)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = l
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.06, 0)
	pad.PaddingBottom = UDim.new(0.06, 0)
	pad.Parent = l
	l.Parent = sg
	return l
end

local function prompt(parent: BasePart, action: string, object: string, hold: number?): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = hold or 0
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	return pp
end

local function setupLighting()
	-- late golden afternoon: warm sun, long shadows, neon pops (Future lighting; Roblox scales it
	-- down automatically on low-end phones)
	Lighting.ClockTime = 16.2
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(95, 95, 115)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 160)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.StarCount = 1500
	sky.Parent = Lighting
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.3
	atm.Offset = 0.2
	atm.Haze = 1.4
	atm.Glare = 0.35
	atm.Color = Color3.fromRGB(255, 225, 200)
	atm.Decay = Color3.fromRGB(110, 120, 160)
	atm.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.7
	bloom.Size = 30
	bloom.Threshold = 1.3
	bloom.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.08
	rays.Spread = 0.6
	rays.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.22
	cc.Contrast = 0.08
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(255, 248, 240)
	cc.Parent = Lighting
end

local function lamp(parent: Instance, pos: Vector3)
	block(
		parent,
		"LampPost",
		Vector3.new(0.8, 14, 0.8),
		CFrame.new(pos + Vector3.new(0, 7, 0)),
		Color3.fromRGB(40, 40, 45),
		Enum.Material.Metal
	)
	local head = block(
		parent,
		"LampHead",
		Vector3.new(2.4, 1.6, 2.4),
		CFrame.new(pos + Vector3.new(0, 14.5, 0)),
		Color3.fromRGB(255, 240, 190),
		Enum.Material.Neon
	)
	head.CanCollide = false
	local light = Instance.new("PointLight")
	light.Range = 26
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 230, 170)
	light.Parent = head
end

local function tree(parent: Instance, pos: Vector3, scale: number)
	block(
		parent,
		"Trunk",
		Vector3.new(2, 8, 2) * scale,
		CFrame.new(pos + Vector3.new(0, 4 * scale, 0)),
		Color3.fromRGB(110, 75, 45),
		Enum.Material.Wood
	)
	local leaves = block(
		parent,
		"Leaves",
		Vector3.new(9, 7, 9) * scale,
		CFrame.new(pos + Vector3.new(0, 10 * scale, 0)),
		Color3.fromRGB(70, 190, 80),
		Enum.Material.Grass
	)
	leaves.Shape = Enum.PartType.Ball
end

-- ===== Player base =====
local function buildBase(parent: Instance, id: number, origin: CFrame): BaseRecord
	local model = Instance.new("Model")
	model.Name = "Base_" .. id
	model:SetAttribute("BaseId", id)
	model.Parent = parent
	local color = rgb(World.BaseColors[id])
	local W, D, H = World.BaseWidth, World.BaseDepth, World.WallHeight

	local function at(lx: number, ly: number, depth: number): CFrame
		return origin * CFrame.new(lx, ly, -depth)
	end

	-- pastel floor with a darker "shelf" band under each pedestal row
	block(
		model,
		"Floor",
		Vector3.new(W, FLOOR, D),
		at(0, FLOOR / 2, D / 2),
		color:Lerp(Color3.new(1, 1, 1), 0.72),
		Enum.Material.SmoothPlastic
	)
	for _, depth in World.PedestalRowDepth do
		local band = block(
			model,
			"RowBand",
			Vector3.new(W - 8, 0.06, 8),
			at(0, FLOOR + 0.03, depth),
			color:Lerp(Color3.new(1, 1, 1), 0.45),
			Enum.Material.SmoothPlastic
		)
		band.CanCollide = false
		band.CanQuery = false
	end

	-- low, bright walls so the plaza stays open and everyone can see your loot...
	local wallColor = color:Lerp(Color3.new(1, 1, 1), 0.15)
	local seg = (W - World.EntranceWidth) / 2
	local walls = {
		{ "WallL", Vector3.new(2, H, D), at(-W / 2, H / 2, D / 2) },
		{ "WallR", Vector3.new(2, H, D), at(W / 2, H / 2, D / 2) },
		{ "WallBack", Vector3.new(W, H, 2), at(0, H / 2, D) },
		{ "WallFL", Vector3.new(seg, H, 2), at(-W / 2 + seg / 2, H / 2, 0) },
		{ "WallFR", Vector3.new(seg, H, 2), at(W / 2 - seg / 2, H / 2, 0) },
	}
	for _, w in walls do
		local wall = block(model, w[1], w[2], w[3], wallColor, Enum.Material.SmoothPlastic)
		block(
			model,
			w[1] .. "Trim",
			Vector3.new(wall.Size.X + 0.4, 0.6, wall.Size.Z + 0.4),
			wall.CFrame * CFrame.new(0, H / 2 + 0.3, 0),
			Color3.new(1, 1, 1),
			Enum.Material.SmoothPlastic
		)
		-- ...plus an invisible barrier on top, so nobody jumps in: the entrance is the only way
		local barrier = block(
			model,
			"Barrier",
			Vector3.new(wall.Size.X, BARRIER_HEIGHT, wall.Size.Z),
			wall.CFrame * CFrame.new(0, BARRIER_HEIGHT / 2 - H / 2, 0),
			Color3.new(),
			Enum.Material.SmoothPlastic
		)
		barrier.Transparency = 1
		barrier.CanQuery = false
		barrier.CastShadow = false
	end

	-- laser door (server toggles it when locked): a visible laser + a tall invisible blocker
	local laser = block(
		model,
		"Laser",
		Vector3.new(World.EntranceWidth, 8, 0.6),
		at(0, 4, 0),
		Color3.fromRGB(255, 40, 60),
		Enum.Material.Neon
	)
	laser.Transparency = 1
	laser.CanCollide = false
	laser.CanQuery = false
	local laserBarrier = block(
		model,
		"LaserBarrier",
		Vector3.new(World.EntranceWidth, BARRIER_HEIGHT, 0.6),
		at(0, BARRIER_HEIGHT / 2, 0),
		Color3.new(),
		Enum.Material.SmoothPlastic
	)
	laserBarrier.Transparency = 1
	laserBarrier.CanCollide = false
	laserBarrier.CanQuery = false
	laserBarrier.CastShadow = false

	-- entrance arch with the owner's name (faces the plaza)
	local archX = World.EntranceWidth / 2 + 1.5
	for _, lx in { -archX, archX } do
		block(
			model,
			"ArchPost",
			Vector3.new(3, 13, 3),
			at(lx, 6.5, 0),
			wallColor,
			Enum.Material.SmoothPlastic
		)
		local cap =
			block(model, "ArchCap", Vector3.new(3.6, 1, 3.6), at(lx, 13.5, 0), color, Enum.Material.Neon)
		cap.CanCollide = false
	end
	local sign = block(
		model,
		"Sign",
		Vector3.new(World.EntranceWidth + 8, 4.6, 1.2),
		at(0, 12, -0.4),
		color:Lerp(Color3.new(0, 0, 0), 0.35),
		Enum.Material.SmoothPlastic
	)
	local signLabel = surfaceText(sign, Enum.NormalId.Back, "FREE BASE", Color3.fromRGB(200, 200, 210))
	surfaceText(sign, Enum.NormalId.Front, "🏠", Color3.new(1, 1, 1))

	-- pedestals
	local pedestals: { BasePart } = {}
	local cols = World.PedestalColumns
	for r = 1, World.PedestalRows do
		for c = 1, cols do
			local lx = (c - (cols + 1) / 2) * World.PedestalSpacingX
			-- round podium (cylinders run along X: stood up with a 90° turn about Z)
			local ped = block(
				model,
				"Pedestal",
				Vector3.new(1.2, 5.4, 5.4),
				at(lx, FLOOR + 0.6, World.PedestalRowDepth[r]) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(245, 245, 250),
				Enum.Material.SmoothPlastic
			)
			ped.Shape = Enum.PartType.Cylinder
			ped:SetAttribute("Slot", #pedestals + 1)
			table.insert(pedestals, ped)
		end
	end

	-- treadmill (belt pushes you toward the entrance: keep running!)
	local beltDepth = 59
	local beltX = -W / 2 + 14
	local belt = block(
		model,
		"Treadmill",
		Vector3.new(9, 0.6, 20),
		at(beltX, FLOOR + 0.3, beltDepth),
		Color3.fromRGB(35, 35, 40),
		Enum.Material.Rubber
	)
	-- moving stripes are animated on the client (Controllers/Ambient)
	belt:SetAttribute("BeltColor", color)
	block(
		model,
		"RailL",
		Vector3.new(1, 3, 20),
		at(beltX - 5, FLOOR + 1.5, beltDepth),
		color,
		Enum.Material.Metal
	)
	block(
		model,
		"RailR",
		Vector3.new(1, 3, 20),
		at(beltX + 5, FLOOR + 1.5, beltDepth),
		color,
		Enum.Material.Metal
	)
	local screen = block(
		model,
		"TreadScreen",
		Vector3.new(9, 4, 1),
		at(beltX, FLOOR + 5, beltDepth + 10.5),
		Color3.fromRGB(30, 30, 35),
		Enum.Material.SmoothPlastic
	)
	surfaceText(screen, Enum.NormalId.Back, "⚡ SPEED ZONE ⚡", Color3.fromRGB(255, 230, 60))

	local treadSign = block(
		model,
		"TreadSign",
		Vector3.new(7, 4, 0.6),
		at(beltX + 13, FLOOR + 4, beltDepth - 12),
		Color3.fromRGB(255, 210, 60),
		Enum.Material.SmoothPlastic
	)
	block(
		model,
		"TreadSignPost",
		Vector3.new(0.6, 2, 0.6),
		at(beltX + 13, FLOOR + 1, beltDepth - 12),
		Color3.fromRGB(90, 60, 40),
		Enum.Material.Wood
	)
	-- double sided: readable from the entrance and from the treadmill
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		surfaceText(treadSign, face, "UPGRADE TREADMILL", Color3.new(1, 1, 1))
	end

	-- collect pad + plot upgrade sign near the entrance
	local collectPad = block(
		model,
		"CollectPad",
		Vector3.new(8, 0.4, 8),
		at(W / 2 - 12, FLOOR + 0.2, 8),
		Color3.fromRGB(70, 230, 90),
		Enum.Material.Neon
	)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 60)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.MaxDistance = 90
	bb.Parent = collectPad
	local pendingLabel = Instance.new("TextLabel")
	pendingLabel.Size = UDim2.fromScale(1, 1)
	pendingLabel.BackgroundTransparency = 1
	pendingLabel.Font = Enum.Font.LuckiestGuy
	pendingLabel.TextScaled = true
	pendingLabel.TextColor3 = Color3.fromRGB(120, 255, 130)
	pendingLabel.Text = "COLLECT $0"
	local ps = Instance.new("UIStroke")
	ps.Thickness = 3
	ps.Parent = pendingLabel
	pendingLabel.Parent = bb

	local plotSign = block(
		model,
		"PlotSign",
		Vector3.new(8, 4.5, 0.6),
		at(-W / 2 + 13, FLOOR + 4.5, 7),
		Color3.fromRGB(90, 200, 255),
		Enum.Material.SmoothPlastic
	)
	block(
		model,
		"PlotSignPost",
		Vector3.new(0.6, 2.4, 0.6),
		at(-W / 2 + 13, FLOOR + 1.2, 7),
		Color3.fromRGB(90, 60, 40),
		Enum.Material.Wood
	)
	-- the sign stands just inside the front wall: the Front face looks into the base (toward the
	-- spawn), the Back face at the wall. Text on both so it reads from anywhere.
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		surfaceText(plotSign, face, "UPGRADE PLOT", Color3.new(1, 1, 1))
	end

	-- crown beam (visible when this base belongs to THE RICHEST)
	local beam = block(
		model,
		"CrownBeam",
		Vector3.new(220, 10, 10),
		at(0, 110, D / 2) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 210, 50),
		Enum.Material.Neon
	)
	beam.Shape = Enum.PartType.Cylinder
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Transparency = 1

	local rings = WorldDecor.base(model, origin, color, pedestals, FLOOR)
	WorldDecor.safeZone(model, origin, FLOOR)

	return {
		id = id,
		origin = origin,
		model = model,
		color = color,
		pedestals = pedestals,
		rings = rings,
		laser = laser,
		belt = belt,
		collectPad = collectPad,
		pendingLabel = pendingLabel,
		signLabel = signLabel,
		plotSign = plotSign,
		treadSign = treadSign,
		beam = beam,
		spawnCFrame = at(0, 4, 11) * CFrame.Angles(0, math.rad(180), 0),
	}
end

-- ===== NPC vault =====
local function buildVault(parent: Instance, index: number, origin: CFrame): VaultRecord
	local def = Vaults[index]
	local model = Instance.new("Model")
	model.Name = "Vault_" .. def.id
	model:SetAttribute("VaultIndex", index)
	model.Parent = parent
	local color, trim = rgb(def.color), rgb(def.trim)
	local W, D, H = World.VaultWidth, World.VaultDepth, 18

	local function at(lx: number, ly: number, depth: number): CFrame
		return origin * CFrame.new(lx, ly, -depth)
	end

	block(
		model,
		"Floor",
		Vector3.new(W, FLOOR, D),
		at(0, FLOOR / 2, D / 2),
		color:Lerp(Color3.new(1, 1, 1), 0.35),
		Enum.Material.Marble
	)
	block(model, "WallL", Vector3.new(2, H, D), at(-W / 2, H / 2, D / 2), color, Enum.Material.Brick)
	block(model, "WallR", Vector3.new(2, H, D), at(W / 2, H / 2, D / 2), color, Enum.Material.Brick)
	block(model, "WallBack", Vector3.new(W, H, 2), at(0, H / 2, D), color, Enum.Material.Brick)
	local door = 34
	local seg = (W - door) / 2
	block(model, "WallFL", Vector3.new(seg, H, 2), at(-W / 2 + seg / 2, H / 2, 0), color, Enum.Material.Brick)
	block(model, "WallFR", Vector3.new(seg, H, 2), at(W / 2 - seg / 2, H / 2, 0), color, Enum.Material.Brick)
	-- roof band + pillars in trim color
	block(model, "Band", Vector3.new(W + 2, 2, 3), at(0, H + 1, 0), trim, Enum.Material.SmoothPlastic)
	for _, lx in { -door / 2 - 1.5, door / 2 + 1.5, -W / 2, W / 2 } do
		block(model, "Pillar", Vector3.new(3, H + 2, 3), at(lx, (H + 2) / 2, 0), trim, Enum.Material.Marble)
	end
	-- big name sign facing the street
	local sign = block(
		model,
		"Sign",
		Vector3.new(door + 20, 8, 1),
		at(0, H + 6, -1),
		trim,
		Enum.Material.SmoothPlastic
	)
	surfaceText(sign, Enum.NormalId.Back, def.emoji .. " " .. string.upper(def.name), Color3.new(1, 1, 1))
	-- red carpet
	block(
		model,
		"Carpet",
		Vector3.new(12, 0.1, D - 6),
		at(0, FLOOR + 0.05, D / 2 - 2),
		Color3.fromRGB(190, 30, 40),
		Enum.Material.Fabric
	)

	local pedestals: { BasePart } = {}
	local cols = 3
	for r = 1, 2 do
		for c = 1, cols do
			local lx = (c - 2) * 22
			local depth = 26 + (r - 1) * 22
			local ped = block(
				model,
				"Pedestal",
				Vector3.new(6, 2, 6),
				at(lx, FLOOR + 1, depth),
				trim,
				Enum.Material.Marble
			)
			local glass = block(
				model,
				"Glass",
				Vector3.new(6.4, 0.4, 6.4),
				ped.CFrame * CFrame.new(0, 9, 0), -- above the loot label
				Color3.fromRGB(200, 240, 255),
				Enum.Material.Glass
			)
			glass.Transparency = 0.6
			glass.CanCollide = false
			table.insert(pedestals, ped)
		end
	end

	WorldDecor.vault(model, def.id, origin, trim)

	local guardSpawns: { CFrame } = {}
	for g = 1, def.guards do
		table.insert(guardSpawns, at((g - (def.guards + 1) / 2) * 14, 4, 12))
	end

	return {
		index = index,
		origin = origin,
		center = at(0, 0, D / 2).Position,
		model = model,
		pedestals = pedestals,
		guardSpawns = guardSpawns,
	}
end

function WorldBuilder.build(): WorldInfo
	setupLighting()
	local root = Instance.new("Folder")
	root.Name = "World"
	root.Parent = workspace

	local streetEnd = World.StreetStartX + #Vaults * World.VaultSpacing + 80
	local minX = -World.PlazaHalfWidth - 60
	local groundW = streetEnd - minX + 120
	local groundCenterX = (streetEnd + minX) / 2
	local ground = block(
		root,
		"Ground",
		Vector3.new(groundW, 4, 420),
		CFrame.new(groundCenterX, -2, 0),
		Color3.fromRGB(95, 200, 90),
		Enum.Material.Grass
	)
	ground.Name = "Ground"

	-- invisible map bounds
	for _, b in
		{
			{ Vector3.new(groundW, 80, 2), Vector3.new(groundCenterX, 40, 210) },
			{ Vector3.new(groundW, 80, 2), Vector3.new(groundCenterX, 40, -210) },
			{ Vector3.new(2, 80, 420), Vector3.new(groundCenterX - groundW / 2, 40, 0) },
			{ Vector3.new(2, 80, 420), Vector3.new(groundCenterX + groundW / 2, 40, 0) },
		}
	do
		local w = block(root, "Bound", b[1], CFrame.new(b[2]), Color3.new(), Enum.Material.SmoothPlastic)
		w.Transparency = 1
	end

	-- plaza
	block(
		root,
		"Plaza",
		Vector3.new(World.PlazaHalfWidth * 2, 0.3, World.BaseRowZ * 2 - 4),
		CFrame.new(0, 0.15, 0),
		Color3.fromRGB(235, 225, 205),
		Enum.Material.Pavement
	)
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.new(-60, 0.3, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = root

	-- bases: row A (z < 0) faces -Z into the base, row B (z > 0) faces +Z
	local bases: { BaseRecord } = {}
	local basesFolder = Instance.new("Folder")
	basesFolder.Name = "Bases"
	basesFolder.Parent = workspace
	for i = 1, World.BaseCount do
		local col = World.BaseColumns[((i - 1) % 4) + 1]
		local side = if i <= 4 then -1 else 1
		local front = Vector3.new(col, 0, side * World.BaseRowZ)
		local origin = CFrame.lookAt(front, front + Vector3.new(0, 0, side))
		table.insert(bases, buildBase(basesFolder, i, origin))
	end

	-- Rich Street
	local streetLen = streetEnd - World.StreetStartX
	block(
		root,
		"Street",
		Vector3.new(streetLen, 0.3, World.StreetHalfWidth * 2),
		CFrame.new(World.StreetStartX + streetLen / 2, 0.15, 0),
		Color3.fromRGB(60, 60, 68),
		Enum.Material.Asphalt
	)
	for x = World.StreetStartX, streetEnd, 12 do
		block(
			root,
			"Stripe",
			Vector3.new(6, 0.32, 0.8),
			CFrame.new(x, 0.17, 0),
			Color3.fromRGB(255, 220, 80),
			Enum.Material.SmoothPlastic
		)
	end
	-- gate
	local gx = World.StreetStartX + 4
	block(
		root,
		"GatePostL",
		Vector3.new(4, 26, 4),
		CFrame.new(gx, 13, -World.StreetHalfWidth - 2),
		Color3.fromRGB(255, 200, 40),
		Enum.Material.Foil
	)
	block(
		root,
		"GatePostR",
		Vector3.new(4, 26, 4),
		CFrame.new(gx, 13, World.StreetHalfWidth + 2),
		Color3.fromRGB(255, 200, 40),
		Enum.Material.Foil
	)
	local gateSign = block(
		root,
		"GateSign",
		Vector3.new(3, 9, World.StreetHalfWidth * 2 + 8),
		CFrame.new(gx, 26, 0),
		Color3.fromRGB(30, 25, 35),
		Enum.Material.SmoothPlastic
	)
	surfaceText(gateSign, Enum.NormalId.Left, "💰 RICH STREET 💰", Color3.fromRGB(255, 215, 60))
	surfaceText(gateSign, Enum.NormalId.Right, "🏠 HOME 🏠", Color3.fromRGB(120, 255, 130))

	local vaults: { VaultRecord } = {}
	local vaultFolder = Instance.new("Folder")
	vaultFolder.Name = "Vaults"
	vaultFolder.Parent = workspace
	for i = 1, #Vaults do
		local x = World.StreetStartX + 70 + (i - 1) * World.VaultSpacing
		local side = if i % 2 == 1 then -1 else 1
		local front = Vector3.new(x, 0, side * World.VaultOffsetZ)
		local origin = CFrame.lookAt(front, front + Vector3.new(0, 0, side))
		table.insert(vaults, buildVault(vaultFolder, i, origin))
	end
	-- lamps + trees along the street
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = root
	for x = World.StreetStartX + 20, streetEnd, 40 do
		lamp(decor, Vector3.new(x, 0, -World.StreetHalfWidth - 2))
		lamp(decor, Vector3.new(x + 20, 0, World.StreetHalfWidth + 2))
	end
	-- trees behind the home bases (the skyline owns the street side)
	for i = 1, 30 do
		local rng = Random.new(i)
		local x = rng:NextNumber(minX, World.StreetStartX - 20)
		local z = (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(118, 200)
		tree(decor, Vector3.new(x, 0, z), rng:NextNumber(0.9, 1.6))
	end
	WorldDecor.sidewalks(root, World.StreetStartX, streetEnd)
	WorldDecor.skyline(root, World.StreetStartX + 10, streetEnd - 30)
	WorldDecor.lanes(root, -175, streetEnd - 10)
	-- palms in the gaps between vaults
	for i = 1, #Vaults - 2 do
		local x = World.StreetStartX + 70 + (i - 1) * World.VaultSpacing + World.VaultSpacing
		local side = if i % 2 == 1 then -1 else 1
		WorldDecor.palm(decor, Vector3.new(x - 10, 0, side * 38), 1)
		WorldDecor.palm(decor, Vector3.new(x + 10, 0, side * 46), 1.15)
	end
	-- plaza: two fountains between the base entrances (benches removed: they were in the way)
	for _, x in { -110, 110 } do
		WorldDecor.fountain(root, Vector3.new(x, 0.3, 0))
	end

	-- WANTED board in the plaza center (double sided)
	local board = block(
		root,
		"WantedBoard",
		Vector3.new(30, 18, 1),
		CFrame.new(0, 14, 0),
		Color3.fromRGB(240, 220, 170),
		Enum.Material.Wood
	)
	block(
		root,
		"WantedPostA",
		Vector3.new(1.5, 6, 1.5),
		CFrame.new(-12, 3, 0),
		Color3.fromRGB(90, 60, 40),
		Enum.Material.Wood
	)
	block(
		root,
		"WantedPostB",
		Vector3.new(1.5, 6, 1.5),
		CFrame.new(12, 3, 0),
		Color3.fromRGB(90, 60, 40),
		Enum.Material.Wood
	)
	local wanted: { [string]: any } = { Image = {}, Title = {}, Name = {}, Bounty = {} }
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 25
		sg.LightInfluence = 0
		sg.Parent = board
		local function txt(y: number, h: number, size: number, color: Color3): TextLabel
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Position = UDim2.fromScale(0.36, y)
			l.Size = UDim2.fromScale(0.6, h)
			l.Font = Enum.Font.LuckiestGuy
			l.TextScaled = true
			l.TextColor3 = color
			l.Text = ""
			l.TextSize = size
			local s = Instance.new("UIStroke")
			s.Thickness = 3
			s.Color = Color3.fromRGB(60, 30, 10)
			s.Parent = l
			l.Parent = sg
			return l
		end
		local img = Instance.new("ImageLabel")
		img.BackgroundColor3 = Color3.fromRGB(255, 245, 220)
		img.Position = UDim2.fromScale(0.04, 0.15)
		img.Size = UDim2.fromScale(0.3, 0.7)
		img.Image = ""
		local ic = Instance.new("UIStroke")
		ic.Thickness = 6
		ic.Color = Color3.fromRGB(90, 50, 20)
		ic.Parent = img
		img.Parent = sg
		table.insert(wanted.Image, img)
		table.insert(wanted.Title, txt(0.06, 0.26, 0, Color3.fromRGB(220, 40, 40)))
		table.insert(wanted.Name, txt(0.36, 0.22, 0, Color3.fromRGB(255, 255, 255)))
		table.insert(wanted.Bounty, txt(0.62, 0.3, 0, Color3.fromRGB(255, 215, 60)))
	end

	-- Longest reign board
	local reign = block(
		root,
		"ReignBoard",
		Vector3.new(1, 22, 18),
		CFrame.new(-World.PlazaHalfWidth + 6, 12, 9), -- off to the side so the fuse machine never hides it
		Color3.fromRGB(30, 25, 35),
		Enum.Material.SmoothPlastic
	)
	local rsg = Instance.new("SurfaceGui")
	rsg.Face = Enum.NormalId.Right
	rsg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	rsg.PixelsPerStud = 25
	rsg.LightInfluence = 0
	rsg.Parent = reign
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rsg
	local reignLines: { TextLabel } = {}
	for i = 0, 10 do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, if i == 0 then 0.14 else 0.078)
		l.Font = if i == 0 then Enum.Font.LuckiestGuy else Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = if i == 0 then Color3.fromRGB(255, 215, 60) else Color3.new(1, 1, 1)
		l.Text = if i == 0 then "👑 LONGEST REIGN 👑" else ""
		l.LayoutOrder = i
		l.Parent = rsg
		if i > 0 then
			table.insert(reignLines, l)
		end
	end

	-- Fuse machine
	local fx = -World.PlazaHalfWidth + 40
	local FUSE_Z = -16
	local machine = block(
		root,
		"FuseMachine",
		Vector3.new(10, 10, 10),
		CFrame.new(fx, 5, FUSE_Z),
		Color3.fromRGB(150, 70, 255),
		Enum.Material.Neon
	)
	machine.Shape = Enum.PartType.Ball
	block(
		root,
		"FuseBase",
		Vector3.new(14, 2, 14),
		CFrame.new(fx, 1, FUSE_Z),
		Color3.fromRGB(60, 40, 90),
		Enum.Material.Metal
	)
	local fsign = block(
		root,
		"FuseSign",
		Vector3.new(1, 4, 16),
		CFrame.new(fx, 13.5, FUSE_Z),
		Color3.fromRGB(60, 40, 90),
		Enum.Material.SmoothPlastic
	)
	surfaceText(fsign, Enum.NormalId.Right, "🧪 FUSE MACHINE", Color3.fromRGB(230, 200, 255))
	surfaceText(fsign, Enum.NormalId.Left, "🧪 FUSE MACHINE", Color3.fromRGB(230, 200, 255))
	local fusePrompt = prompt(machine, "Fuse", "3 identical → 1 better", 0)
	fusePrompt.MaxActivationDistance = 16

	local trailsPrompt = WorldDecor.trailsShop(root, Vector3.new(196, 0.3, 0))

	-- seasonal dressing (Config/Cosmetics.Season decides the dates)
	local d = os.date("!*t") :: any
	local halloween = Cosmetics.seasonActive({ month = d.month, day = d.day })
	if halloween then
		WorldDecor.halloween(root, bases, vaults, streetEnd)
	end

	return {
		bases = bases,
		vaults = vaults,
		wanted = wanted,
		reignLines = reignLines,
		fusePrompt = fusePrompt,
		trailsPrompt = trailsPrompt,
		streetEnd = streetEnd,
		halloween = halloween,
	}
end

WorldBuilder.FLOOR = FLOOR
WorldBuilder.prompt = prompt

return WorldBuilder
