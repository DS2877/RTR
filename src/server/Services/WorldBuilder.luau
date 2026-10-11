--!strict
-- Builds the whole map at runtime, in the genre's look: bright, saturated, studded (LEGO-style)
-- surfaces. Home plaza with 8 palace bases (two rows), and Rich Street: one long corridor where
-- the rich people's zones follow each other and you run straight through them (farther = richer).
-- Also the WANTED board (the richest player), the reign leaderboard, the fuse machine and the
-- trails shop.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Vaults = require(Shared.Config.Vaults)
local Cosmetics = require(Shared.Config.Cosmetics)
local WorldDecor = require(script.Parent.WorldDecor)

local WorldBuilder = {}

local FLOOR = 0.4 -- top of base/zone floors
local BARRIER_HEIGHT = 50 -- invisible wall above the low base walls (no jumping in)

-- palette (the genre's palace look: navy + gold + lime grass + one accent per base)
local NAVY = Color3.fromRGB(40, 42, 92)
local NAVY_DARK = Color3.fromRGB(28, 30, 66)
local GOLD = Color3.fromRGB(255, 196, 40)
local LIME = Color3.fromRGB(118, 226, 52)

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
	origin: CFrame, -- zone start on the corridor center line; LookVector points down the corridor
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

-- Studded top (the classic LEGO look of the genre).
local function studs(p: BasePart): BasePart
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs
	return p
end

local function deco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
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
	l.Font = font or Enum.Font.FredokaOne
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
	-- bright, saturated daylight like the genre (Future lighting; Roblox scales it down on
	-- low-end phones). Light haze only, so colors stay punchy.
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(120, 120, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(165, 165, 185)
	Lighting.EnvironmentDiffuseScale = 0.8
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.2
	local sky = Instance.new("Sky")
	sky.SunAngularSize = 12
	sky.StarCount = 0
	sky.Parent = Lighting
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.22
	atm.Offset = 0.1
	atm.Haze = 0.2
	atm.Glare = 0
	atm.Color = Color3.fromRGB(200, 225, 255)
	atm.Decay = Color3.fromRGB(120, 150, 220)
	atm.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.8
	bloom.Size = 28
	bloom.Threshold = 1.15
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.32
	cc.Contrast = 0.1
	cc.Brightness = 0.03
	cc.Parent = Lighting
end

local function tree(parent: Instance, pos: Vector3, scale: number)
	block(
		parent,
		"Trunk",
		Vector3.new(2, 8, 2) * scale,
		CFrame.new(pos + Vector3.new(0, 4 * scale, 0)),
		Color3.fromRGB(120, 80, 45),
		Enum.Material.Wood
	)
	-- blocky voxel crown
	for _, o in { Vector3.new(0, 10, 0), Vector3.new(2.5, 8.5, 1), Vector3.new(-2, 9, -2) } do
		local leaves = block(
			parent,
			"Leaves",
			Vector3.new(7, 6, 7) * scale,
			CFrame.new(pos + o * scale),
			Color3.fromRGB(60, 190, 70),
			Enum.Material.Plastic
		)
		leaves.TopSurface = Enum.SurfaceType.Studs
	end
end

-- ===== Player base: a palace =====
-- Lime studded yard, a navy path with glowing tiles, the treadmill + collect pad in the yard, and
-- a raised stage at the back (palace facade) where your loot is packed on round podiums.
local function buildBase(parent: Instance, id: number, origin: CFrame): BaseRecord
	local model = Instance.new("Model")
	model.Name = "Base_" .. id
	model:SetAttribute("BaseId", id)
	model.Parent = parent
	local color = rgb(World.BaseColors[id])
	local W, D, H = World.BaseWidth, World.BaseDepth, World.WallHeight
	local SD, SH = World.StageDepth, World.StageHeight
	local stageTop = FLOOR + SH

	local function at(lx: number, ly: number, depth: number): CFrame
		return origin * CFrame.new(lx, ly, -depth)
	end

	studs(block(model, "Floor", Vector3.new(W, FLOOR, D), at(0, FLOOR / 2, D / 2), LIME))

	-- the path from the entrance to the stage, with glowing tiles
	studs(block(model, "Path", Vector3.new(10, 0.2, SD), at(0, FLOOR + 0.1, SD / 2), NAVY))
	for depth = 5, SD - 4, 6 do
		deco(block(model, "TileFrame", Vector3.new(7.2, 0.24, 4.4), at(0, FLOOR + 0.12, depth), GOLD))
		deco(
			block(
				model,
				"Tile",
				Vector3.new(6, 0.26, 3.3),
				at(0, FLOOR + 0.13, depth),
				color,
				Enum.Material.Neon
			)
		)
	end

	-- low navy walls with gold trim (the back wall is the tall palace facade)...
	local seg = (W - World.EntranceWidth) / 2
	local FACADE = 18
	local walls = {
		{ "WallL", Vector3.new(2, H, D), at(-W / 2, H / 2, D / 2) },
		{ "WallR", Vector3.new(2, H, D), at(W / 2, H / 2, D / 2) },
		{ "WallBack", Vector3.new(W, FACADE, 2), at(0, FACADE / 2, D) },
		{ "WallFL", Vector3.new(seg, H, 2), at(-W / 2 + seg / 2, H / 2, 0) },
		{ "WallFR", Vector3.new(seg, H, 2), at(W / 2 - seg / 2, H / 2, 0) },
	}
	for _, w in walls do
		local wall = block(model, w[1], w[2], w[3], NAVY)
		block(
			model,
			w[1] .. "Trim",
			Vector3.new(wall.Size.X + 0.4, 0.8, wall.Size.Z + 0.4),
			wall.CFrame * CFrame.new(0, wall.Size.Y / 2 + 0.4, 0),
			GOLD
		)
		-- ...plus an invisible barrier on top, so nobody jumps in: the entrance is the only way
		local barrier = block(
			model,
			"Barrier",
			Vector3.new(wall.Size.X, BARRIER_HEIGHT, wall.Size.Z),
			wall.CFrame * CFrame.new(0, BARRIER_HEIGHT / 2 - wall.Size.Y / 2, 0),
			Color3.new()
		)
		barrier.Transparency = 1
		barrier.CanQuery = false
		barrier.CastShadow = false
	end

	-- the raised stage with a gold lip and two steps at the path
	studs(
		block(
			model,
			"Stage",
			Vector3.new(W - 4, SH, D - SD - 1),
			at(0, FLOOR + SH / 2, SD + (D - SD - 1) / 2),
			NAVY_DARK
		)
	)
	block(model, "StageLip", Vector3.new(W - 4, 0.5, 0.8), at(0, stageTop + 0.05, SD + 0.4), GOLD)
	studs(block(model, "Step1", Vector3.new(14, SH / 2, 2.4), at(0, FLOOR + SH / 4, SD - 2.4), NAVY))
	studs(block(model, "Step2", Vector3.new(14, SH, 1.2), at(0, FLOOR + SH / 2, SD - 0.6), NAVY))

	-- palace facade: pillars with accent banners and a golden gable
	for _, lx in { -45, -27, -9, 9, 27, 45 } do
		block(model, "Pillar", Vector3.new(3, FACADE + 2, 3), at(lx, (FACADE + 2) / 2, D - 1.5), NAVY_DARK)
		block(model, "PillarCap", Vector3.new(3.8, 1, 3.8), at(lx, FACADE + 2.5, D - 1.5), GOLD)
		deco(
			block(
				model,
				"Banner",
				Vector3.new(2, 9, 0.3),
				at(lx, FACADE - 6, D - 3.1),
				color,
				Enum.Material.Neon
			)
		)
	end
	-- golden gable: two beams from the facade corners up to a peak in the middle
	local peak = at(0, FACADE + 11, D - 1).Position
	for _, side in { -1, 1 } do
		local corner = at(side * (W / 2 + 1), FACADE + 1, D - 1).Position
		block(
			model,
			"Gable",
			Vector3.new(2.4, 2.4, (peak - corner).Magnitude + 2),
			CFrame.lookAt((peak + corner) / 2, peak),
			GOLD
		)
	end
	local emblem = deco(
		block(
			model,
			"Emblem",
			Vector3.new(0.6, 6, 6),
			at(0, FACADE + 4, D - 2.6) * CFrame.Angles(0, math.rad(90), 0),
			color,
			Enum.Material.Neon
		)
	)
	emblem.Shape = Enum.PartType.Cylinder

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
		Color3.new()
	)
	laserBarrier.Transparency = 1
	laserBarrier.CanCollide = false
	laserBarrier.CanQuery = false
	laserBarrier.CastShadow = false

	-- entrance arch with the owner's name (faces the plaza)
	local archX = World.EntranceWidth / 2 + 1.5
	for _, lx in { -archX, archX } do
		block(model, "ArchPost", Vector3.new(3, 13, 3), at(lx, 6.5, 0), NAVY)
		deco(block(model, "ArchCap", Vector3.new(3.6, 1, 3.6), at(lx, 13.5, 0), color, Enum.Material.Neon))
	end
	local sign = block(model, "Sign", Vector3.new(World.EntranceWidth + 8, 4.6, 1.2), at(0, 12, -0.4), NAVY)
	-- thinner than the sign, so it shows as a gold border without covering either face
	block(model, "SignTrim", Vector3.new(World.EntranceWidth + 9, 5.4, 0.8), at(0, 12, -0.4), GOLD)
	local signLabel = surfaceText(sign, Enum.NormalId.Back, "FREE BASE", Color3.fromRGB(200, 200, 210))
	surfaceText(sign, Enum.NormalId.Front, "🏠", Color3.new(1, 1, 1))

	-- pedestals: round podiums on the stage
	local pedestals: { BasePart } = {}
	local cols = World.PedestalColumns
	for r = 1, World.PedestalRows do
		for c = 1, cols do
			local lx = (c - (cols + 1) / 2) * World.PedestalSpacingX
			-- cylinders run along X: stood up with a 90° turn about Z
			local ped = block(
				model,
				"Pedestal",
				Vector3.new(1.2, 5.4, 5.4),
				at(lx, stageTop + 0.6, World.PedestalRowDepth[r]) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(245, 245, 250)
			)
			ped.Shape = Enum.PartType.Cylinder
			ped:SetAttribute("Slot", #pedestals + 1)
			table.insert(pedestals, ped)
		end
	end

	-- treadmill in the front-left yard (standing on it = training)
	local beltDepth = 24
	local beltX = -W / 2 + 16
	local belt = block(
		model,
		"Treadmill",
		Vector3.new(9, 0.6, 20),
		at(beltX, FLOOR + 0.3, beltDepth),
		Color3.fromRGB(35, 35, 40),
		Enum.Material.Rubber
	)
	belt:SetAttribute("BeltColor", color) -- moving stripes are animated on the client (Ambient)
	for _, side in { -5, 5 } do
		block(
			model,
			"Rail",
			Vector3.new(1, 3, 20),
			at(beltX + side, FLOOR + 1.5, beltDepth),
			GOLD,
			Enum.Material.Metal
		)
	end
	local screen = block(
		model,
		"TreadScreen",
		Vector3.new(9, 4, 1),
		at(beltX, FLOOR + 5, beltDepth + 10.5),
		Color3.fromRGB(30, 30, 35)
	)
	surfaceText(screen, Enum.NormalId.Back, "⚡ SPEED ZONE ⚡", Color3.fromRGB(255, 230, 60))

	-- upgrade sign: far enough from the belt that its prompt never pops up while training
	local treadSign = block(
		model,
		"TreadSign",
		Vector3.new(7, 4, 0.6),
		at(beltX + 15, FLOOR + 4, beltDepth - 4),
		Color3.fromRGB(255, 210, 60)
	)
	block(
		model,
		"TreadSignPost",
		Vector3.new(0.6, 2, 0.6),
		at(beltX + 15, FLOOR + 1, beltDepth - 4),
		Color3.fromRGB(90, 60, 40),
		Enum.Material.Wood
	)
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		surfaceText(treadSign, face, "UPGRADE TREADMILL", Color3.new(1, 1, 1))
	end

	-- collect pad (front right) + plot upgrade sign (front, left of the path)
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
	pendingLabel.Font = Enum.Font.FredokaOne
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
		at(-20, FLOOR + 4.5, 6),
		Color3.fromRGB(90, 200, 255)
	)
	block(
		model,
		"PlotSignPost",
		Vector3.new(0.6, 2.4, 0.6),
		at(-20, FLOOR + 1.2, 6),
		Color3.fromRGB(90, 60, 40),
		Enum.Material.Wood
	)
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

	local rings = WorldDecor.base(model, origin, color, pedestals, stageTop)
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

-- ===== A rich person's zone on the corridor =====
-- You enter through a big arch with their name, run down the path in the middle, the loot stands
-- on display stands on both sides, the rich person stands at the side and guards patrol.
local function buildZone(parent: Instance, index: number, origin: CFrame): VaultRecord
	local def = Vaults[index]
	local model = Instance.new("Model")
	model.Name = "Vault_" .. def.id
	model:SetAttribute("VaultIndex", index)
	model.Parent = parent
	local color, trim = rgb(def.color), rgb(def.trim)
	local L, HW, WH = World.VaultSpacing, World.ZoneHalfWidth, World.ZoneWallHeight

	local function at(lx: number, ly: number, depth: number): CFrame
		return origin * CFrame.new(lx, ly, -depth)
	end

	studs(
		block(
			model,
			"Floor",
			Vector3.new(HW * 2, FLOOR, L),
			at(0, FLOOR / 2, L / 2),
			color:Lerp(Color3.new(1, 1, 1), 0.3)
		)
	)
	studs(
		deco(
			block(
				model,
				"Path",
				Vector3.new(World.PathHalfWidth * 2, 0.1, L),
				at(0, FLOOR + 0.05, L / 2),
				color:Lerp(Color3.new(0, 0, 0), 0.25)
			)
		)
	)
	-- side walls in the zone's colors
	for _, side in { -1, 1 } do
		block(model, "Wall", Vector3.new(2, WH, L), at(side * HW, WH / 2, L / 2), color)
		block(model, "WallTrim", Vector3.new(2.6, 1.2, L + 0.4), at(side * HW, WH + 0.6, L / 2), trim)
	end
	-- the arch at the zone's entrance with the rich person's name (both sides)
	for _, side in { -1, 1 } do
		block(model, "ArchPillar", Vector3.new(5, WH + 12, 5), at(side * (HW - 2.5), (WH + 12) / 2, 0), trim)
	end
	local sign = block(model, "Sign", Vector3.new(HW * 2, 7, 1.5), at(0, WH + 8, 0), trim)
	local title = def.emoji .. " " .. string.upper(def.name)
	surfaceText(sign, Enum.NormalId.Back, title, Color3.new(1, 1, 1)) -- seen arriving from home
	surfaceText(sign, Enum.NormalId.Front, title, Color3.new(1, 1, 1)) -- seen running back

	-- display stands: three on each side of the path
	local pedestals: { BasePart } = {}
	for _, depth in { 35, 65, 95 } do
		for _, side in { -1, 1 } do
			local ped = block(
				model,
				"Pedestal",
				Vector3.new(6, 2, 6),
				at(side * 20, FLOOR + 1, depth),
				trim,
				Enum.Material.Marble
			)
			local glass = deco(
				block(
					model,
					"Glass",
					Vector3.new(6.4, 0.4, 6.4),
					ped.CFrame * CFrame.new(0, 10, 0),
					Color3.fromRGB(200, 240, 255),
					Enum.Material.Glass
				)
			)
			glass.Transparency = 0.6
			table.insert(pedestals, ped)
		end
	end

	-- the rich person, big, at the side of the path (facing it)
	WorldDecor.richNPC(model, def, at(36, FLOOR, 65) * CFrame.Angles(0, math.rad(90), 0))
	WorldDecor.zone(model, def.id, origin, trim)

	local guardSpawns: { CFrame } = {}
	for g = 1, def.guards do
		local side = if g % 2 == 0 then 1 else -1
		table.insert(guardSpawns, at(side * 10, 4, 40 + (g - 1) * 18))
	end

	return {
		index = index,
		origin = origin,
		center = at(0, 0, L / 2).Position,
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

	local zonesStart = World.StreetStartX + World.ZoneGap
	local streetEnd = zonesStart + #Vaults * World.VaultSpacing
	local minX = -World.PlazaHalfWidth - 60
	local groundW = streetEnd - minX + 140
	local groundCenterX = (streetEnd + minX) / 2
	studs(block(root, "Ground", Vector3.new(groundW, 4, 420), CFrame.new(groundCenterX, -2, 0), LIME))

	-- invisible map bounds
	for _, b in
		{
			{ Vector3.new(groundW, 80, 2), Vector3.new(groundCenterX, 40, 210) },
			{ Vector3.new(groundW, 80, 2), Vector3.new(groundCenterX, 40, -210) },
			{ Vector3.new(2, 80, 420), Vector3.new(groundCenterX - groundW / 2, 40, 0) },
			{ Vector3.new(2, 80, 420), Vector3.new(groundCenterX + groundW / 2, 40, 0) },
		}
	do
		local w = block(root, "Bound", b[1], CFrame.new(b[2]), Color3.new())
		w.Transparency = 1
	end

	-- plaza between the two rows of bases
	studs(
		block(
			root,
			"Plaza",
			Vector3.new(World.PlazaHalfWidth * 2, 0.3, World.BaseRowZ * 2 - 4),
			CFrame.new(0, 0.15, 0),
			Color3.fromRGB(225, 225, 235)
		)
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

	-- Rich Street: gate, entry hall, then the zones one after another
	local HW = World.ZoneHalfWidth
	local gx = World.StreetStartX
	studs(
		block(
			root,
			"EntryHall",
			Vector3.new(World.ZoneGap, 0.4, HW * 2),
			CFrame.new(gx + World.ZoneGap / 2, 0.2, 0),
			Color3.fromRGB(235, 235, 245)
		)
	)
	for _, side in { -1, 1 } do
		block(
			root,
			"GatePost",
			Vector3.new(5, 30, 5),
			CFrame.new(gx, 15, side * (HW + 2.5)),
			GOLD,
			Enum.Material.Foil
		)
		block(
			root,
			"HallWall",
			Vector3.new(World.ZoneGap, World.ZoneWallHeight, 2),
			CFrame.new(gx + World.ZoneGap / 2, World.ZoneWallHeight / 2, side * HW),
			NAVY
		)
	end
	local gateSign =
		block(root, "GateSign", Vector3.new(3, 10, HW * 2 + 10), CFrame.new(gx, 30, 0), NAVY_DARK)
	surfaceText(gateSign, Enum.NormalId.Left, "💰 RICH STREET 💰", GOLD)
	surfaceText(gateSign, Enum.NormalId.Right, "🏠 HOME 🏠", Color3.fromRGB(120, 255, 130))

	local vaults: { VaultRecord } = {}
	local vaultFolder = Instance.new("Folder")
	vaultFolder.Name = "Vaults"
	vaultFolder.Parent = workspace
	for i = 1, #Vaults do
		local x0 = zonesStart + (i - 1) * World.VaultSpacing
		local origin = CFrame.lookAt(Vector3.new(x0, 0, 0), Vector3.new(x0 + 1, 0, 0))
		table.insert(vaults, buildZone(vaultFolder, i, origin))
	end
	-- end of the corridor
	local endWall =
		block(root, "EndWall", Vector3.new(2, 24, HW * 2), CFrame.new(streetEnd + 1, 12, 0), NAVY_DARK)
	surfaceText(endWall, Enum.NormalId.Left, "🚧 MORE RICH PEOPLE COMING SOON 🚧", GOLD)

	-- trees around the plaza and along the outside of the corridor
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = root
	for i = 1, 60 do
		local rng = Random.new(i)
		local x = rng:NextNumber(minX, streetEnd)
		local nearHome = x < World.StreetStartX - 10
		local zMin = if nearHome then 118 else HW + 14
		local z = (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(zMin, 200)
		tree(decor, Vector3.new(x, 0, z), rng:NextNumber(0.9, 1.5))
	end
	-- plaza: two fountains between the base entrances
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
	for _, x in { -12, 12 } do
		block(
			root,
			"WantedPost",
			Vector3.new(1.5, 6, 1.5),
			CFrame.new(x, 3, 0),
			Color3.fromRGB(90, 60, 40),
			Enum.Material.Wood
		)
	end
	local wanted: { [string]: any } = { Image = {}, Title = {}, Name = {}, Bounty = {} }
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 25
		sg.LightInfluence = 0
		sg.Parent = board
		local function txt(y: number, h: number, color: Color3): TextLabel
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Position = UDim2.fromScale(0.36, y)
			l.Size = UDim2.fromScale(0.6, h)
			l.Font = Enum.Font.LuckiestGuy
			l.TextScaled = true
			l.TextColor3 = color
			l.Text = ""
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
		table.insert(wanted.Title, txt(0.06, 0.26, Color3.fromRGB(220, 40, 40)))
		table.insert(wanted.Name, txt(0.36, 0.22, Color3.fromRGB(255, 255, 255)))
		table.insert(wanted.Bounty, txt(0.62, 0.3, Color3.fromRGB(255, 215, 60)))
	end

	-- Longest reign board
	local reign = block(
		root,
		"ReignBoard",
		Vector3.new(1, 22, 18),
		CFrame.new(-World.PlazaHalfWidth + 6, 12, 9), -- off to the side so the fuse machine never hides it
		Color3.fromRGB(30, 25, 35)
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
		Color3.fromRGB(60, 40, 90)
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
