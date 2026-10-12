--!strict
-- Builds the whole map at runtime, laid out like the genre: everything is LEGO bricks (studded
-- plastic). A big lime grass plaza inside giant checker walls; all 8 bases side by side in one row
-- on the west side (shack -> palace as they level up) with their treadmills out on the grass in
-- front; Rich Street leaves from the middle of the east wall, pointing straight at the bases, and
-- runs through the rich people's zones one after another (wide streets between tall checker
-- walls, a green line where each starts, crates piled up around the owner). The shops (SELL,
-- fuse machine, trails), the WANTED board and the reign board stand by the street's mouth.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Vaults = require(Shared.Config.Vaults)
local Cosmetics = require(Shared.Config.Cosmetics)
local Progression = require(Shared.Progression)
local Format = require(Shared.Format)
local WorldDecor = require(script.Parent.WorldDecor)
local Rig = require(script.Parent.Parent.Util.Rig)
local Palace = require(script.Parent.Parent.Util.Palace)

local WorldBuilder = {}

local FLOOR = 0.4 -- top of base/zone floors
local BARRIER_HEIGHT = 50 -- invisible wall above the low base fences (no jumping in)
local FACADE = 24 -- the invisible back wall behind the stage (the visible one grows per level)
-- the treadmill stands OUT on the plaza grass, in front of the base left of the entrance
local BELT_X = -26
local BELT_DEPTH = -18

-- palette (the genre's palace look)
local NAVY = Color3.fromRGB(38, 40, 92)
local NAVY_DARK = Color3.fromRGB(26, 28, 66)
local GOLD = Color3.fromRGB(255, 190, 30)
local PINK = Color3.fromRGB(255, 70, 220)
local LIME = Color3.fromRGB(88, 214, 38)
local WOOD = Color3.fromRGB(196, 140, 80)

-- each rich person's street (like the genre): floor + its checker patches, the two tones of the
-- tall checker walls, and what hangs on the walls
type ZoneStyle = {
	floor: { number },
	patch: { number },
	wall: { number },
	wall2: { number },
	walls: string, -- houses | awnings | glyphs | posters | banners | planks | paintings | gears
	rug: { number }, -- the carpet the owner's crates stand on
	border: { number }?, -- a colored strip along both walls (nil = none)
}
local ZONE_STYLE: { [string]: ZoneStyle } = {
	Grandpa = {
		floor = { 104, 196, 66 },
		patch = { 86, 176, 54 },
		wall = { 120, 186, 90 },
		wall2 = { 98, 164, 72 },
		walls = "houses",
		rug = { 176, 60, 56 },
		border = { 150, 110, 70 },
	},
	Jeweler = {
		floor = { 204, 206, 212 },
		patch = { 176, 178, 186 },
		wall = { 150, 152, 160 },
		wall2 = { 128, 130, 140 },
		walls = "awnings",
		rug = { 36, 36, 46 },
		border = { 120, 122, 132 },
	},
	Archeologist = {
		floor = { 238, 208, 132 },
		patch = { 214, 184, 110 },
		wall = { 206, 176, 104 },
		wall2 = { 176, 146, 84 },
		walls = "glyphs",
		rug = { 150, 92, 52 },
		border = { 120, 170, 80 },
	},
	Mafia = {
		floor = { 72, 82, 98 },
		patch = { 56, 64, 78 },
		wall = { 46, 54, 66 },
		wall2 = { 38, 44, 54 },
		walls = "posters",
		rug = { 130, 26, 36 },
		border = { 230, 190, 40 },
	},
	Celebrity = {
		floor = { 246, 242, 240 },
		patch = { 255, 186, 206 },
		wall = { 238, 204, 84 },
		wall2 = { 218, 180, 62 },
		walls = "banners",
		rug = { 255, 140, 186 },
		border = { 255, 160, 200 },
	},
	Pirate = {
		floor = { 238, 214, 150 },
		patch = { 214, 190, 126 },
		wall = { 150, 112, 72 },
		wall2 = { 126, 92, 56 },
		walls = "planks",
		rug = { 168, 120, 62 },
	},
	Museum = {
		floor = { 234, 230, 182 },
		patch = { 212, 206, 156 },
		wall = { 112, 122, 62 },
		wall2 = { 128, 98, 58 },
		walls = "paintings",
		rug = { 150, 28, 40 },
		border = { 196, 150, 70 },
	},
	GoldTycoon = {
		floor = { 62, 68, 82 },
		patch = { 255, 200, 40 },
		wall = { 30, 72, 82 },
		wall2 = { 24, 58, 66 },
		walls = "gears",
		rug = { 255, 200, 40 },
		border = { 40, 44, 56 },
	},
}

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
	crateSpots: { CFrame }, -- the appraiser's table: where your crates wait (floor level)
	spawnCFrame: CFrame,
}

export type VaultRecord = {
	index: number,
	origin: CFrame, -- zone start on the corridor center line; LookVector points down the corridor
	center: Vector3,
	model: Model,
	pedestals: { BasePart }, -- crate spots (floor plates)
	guardSpawns: { CFrame }, -- [1] = the owner, among their crates
}

export type WorldInfo = {
	bases: { BaseRecord },
	vaults: { VaultRecord },
	wanted: { [string]: any }, -- Image (ImageLabel list), Title/Name/Bounty (TextLabel lists)
	reignLines: { TextLabel },
	fusePrompt: ProximityPrompt,
	trailsPrompt: ProximityPrompt,
	sellPrompt: ProximityPrompt,
	streetEnd: number,
	halloween: boolean,
}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- A LEGO brick: studded plastic on top (and on the sides when `allSides`, for walls).
local function brick(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	allSides: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Inlet
	if allSides then
		p.FrontSurface = Enum.SurfaceType.Studs
		p.BackSurface = Enum.SurfaceType.Studs
		p.LeftSurface = Enum.SurfaceType.Studs
		p.RightSurface = Enum.SurfaceType.Studs
	end
	p.Parent = parent
	return p
end

local function smooth(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = brick(parent, name, size, cf, color)
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function deco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function invisible(p: BasePart): BasePart
	p.Transparency = 1
	p.CanQuery = false
	p.CastShadow = false
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

-- A wooden notice board on a post (the genre's "Upgrade Plot" sign): title, a green level line and
-- a green price button. Bases fills in the texts (labels Title / Level / Price on both faces).
local function woodSign(parent: Instance, name: string, cf: CFrame, title: string): Part
	local board = brick(parent, name, Vector3.new(9, 5.6, 0.8), cf, WOOD)
	board.FrontSurface = Enum.SurfaceType.Smooth
	board.BackSurface = Enum.SurfaceType.Smooth
	local below = cf * CFrame.new(0, -2.8 - 1.4, 0)
	brick(parent, name .. "Post", Vector3.new(0.8, 2.8, 0.8), below, Color3.fromRGB(130, 90, 50))
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 40
		sg.LightInfluence = 0
		sg.Parent = board
		local function line(lname: string, y: number, h: number, color: Color3, text: string): TextLabel
			local l = Instance.new("TextLabel")
			l.Name = lname
			l.BackgroundTransparency = 1
			l.Position = UDim2.fromScale(0.05, y)
			l.Size = UDim2.fromScale(0.9, h)
			l.Font = Enum.Font.FredokaOne
			l.TextScaled = true
			l.Text = text
			l.TextColor3 = color
			local st = Instance.new("UIStroke")
			st.Thickness = 3
			st.Color = Color3.fromRGB(40, 30, 20)
			st.Parent = l
			l.Parent = sg
			return l
		end
		line("Title", 0.06, 0.32, Color3.new(1, 1, 1), title)
		line("Level", 0.38, 0.2, Color3.fromRGB(110, 255, 90), "")
		local button = Instance.new("Frame")
		button.Name = "Button"
		button.Position = UDim2.fromScale(0.12, 0.62)
		button.Size = UDim2.fromScale(0.76, 0.3)
		button.BackgroundColor3 = Color3.fromRGB(60, 210, 70)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = button
		local bst = Instance.new("UIStroke")
		bst.Thickness = 3
		bst.Color = Color3.fromRGB(20, 90, 30)
		bst.Parent = button
		button.Parent = sg
		local price = Instance.new("TextLabel")
		price.Name = "Price"
		price.BackgroundTransparency = 1
		price.Size = UDim2.fromScale(1, 1)
		price.Font = Enum.Font.FredokaOne
		price.TextScaled = true
		price.Text = ""
		price.TextColor3 = Color3.new(1, 1, 1)
		local pst = Instance.new("UIStroke")
		pst.Thickness = 2
		pst.Color = Color3.fromRGB(20, 70, 25)
		pst.Parent = price
		price.Parent = button
	end
	return board
end

local function setupLighting()
	-- Bright, saturated, crisp daylight like the genre (no blown-out whites: normal exposure,
	-- bloom only on neon). DayNight swaps between this and a purple moonlit night.
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 25
	Lighting.Brightness = 2.4
	Lighting.ExposureCompensation = 0
	Lighting.Ambient = Color3.fromRGB(95, 95, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 16
	sky.StarCount = 3000
	sky.Parent = Lighting
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.26 -- soft distance haze: the mountain ring fades into the sky
	atm.Offset = 0.25
	atm.Haze = 0.6
	atm.Glare = 0
	atm.Color = Color3.fromRGB(200, 222, 248)
	atm.Decay = Color3.fromRGB(110, 128, 160)
	atm.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.5 -- neon tiles and auras glow; grass and walls stay crisp
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.25
	cc.Contrast = 0.1
	cc.Brightness = 0.02
	cc.Parent = Lighting
end

-- The appraiser: an old expert in a white coat beside the crate table (anchored, idle animation).
local function appraiser(parent: Instance, cf: CFrame)
	local rig = Rig.build("appraiser", {
		head = Color3.fromRGB(255, 205, 160),
		torso = Color3.fromRGB(245, 245, 245),
		arms = Color3.fromRGB(245, 245, 245),
		legs = Color3.fromRGB(60, 60, 70),
	})
	if not rig then
		return
	end
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = rig:FindFirstChild("Head") :: BasePart?
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if not root or not head or not humanoid then
		rig:Destroy()
		return
	end
	rig.Name = "Appraiser"
	local hair = smooth(rig, "Hair", Vector3.new(1.3, 0.5, 1.3), CFrame.new(), Color3.fromRGB(240, 240, 240))
	Rig.attach(head, hair, CFrame.new(0, head.Size.Y / 2, 0.05))
	local glasses =
		smooth(rig, "Glasses", Vector3.new(1.1, 0.25, 0.1), CFrame.new(), Color3.fromRGB(30, 30, 35))
	Rig.attach(head, glasses, CFrame.new(0, 0.1, -head.Size.Z / 2 - 0.05))
	rig:PivotTo(cf * CFrame.new(0, 3, 0))
	root.Anchored = true
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(6, 0, 1.1, 0)
	bb.StudsOffset = Vector3.new(0, 2.2, 0)
	bb.MaxDistance = 60
	bb.LightInfluence = 0
	bb.Parent = head
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = "APPRAISER"
	l.TextColor3 = Color3.fromRGB(255, 220, 120)
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Parent = l
	l.Parent = bb
	rig.Parent = parent
	Rig.setPose(humanoid, "Idle")
end

-- ===== Player base: a voxel palace =====
-- Lime yard inside a gold fence, a navy path with glowing pink tiles up to a raised stage in front
-- of the palace (your loot stands on podiums there), the winged treadmill front-left, the
-- appraiser's crate table on the right, and the collect pad by the entrance.
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

	brick(model, "Floor", Vector3.new(W, FLOOR, D), at(0, FLOOR / 2, D / 2), LIME)

	-- the path from the entrance to the stage: navy with gold-framed glowing pink tiles
	brick(model, "Path", Vector3.new(10, 0.2, SD), at(0, FLOOR + 0.1, SD / 2), NAVY)
	for depth = 5, SD - 4, 6 do
		deco(brick(model, "TileFrame", Vector3.new(7.2, 0.24, 4.4), at(0, FLOOR + 0.12, depth), GOLD))
		local tile = deco(brick(model, "Tile", Vector3.new(6, 0.26, 3.3), at(0, FLOOR + 0.13, depth), PINK))
		tile.Material = Enum.Material.Neon
	end

	-- collision: invisible walls (+ invisible barriers above them)
	local seg = (W - World.EntranceWidth) / 2
	local walls = {
		{ "WallL", Vector3.new(2, H, D), at(-W / 2, H / 2, D / 2) },
		{ "WallR", Vector3.new(2, H, D), at(W / 2, H / 2, D / 2) },
		{ "WallBack", Vector3.new(W, FACADE, 2), at(0, FACADE / 2, D) },
		{ "WallFL", Vector3.new(seg, H, 2), at(-W / 2 + seg / 2, H / 2, 0) },
		{ "WallFR", Vector3.new(seg, H, 2), at(W / 2 - seg / 2, H / 2, 0) },
	}
	for _, w in walls do
		-- what you see (fence, palace wall) is decoration rebuilt per level by Util/Palace
		local wall = brick(model, w[1], w[2], w[3], NAVY, true)
		wall.Transparency = 1
		wall.CastShadow = false
		local barrier = invisible(
			brick(
				model,
				"Barrier",
				Vector3.new(wall.Size.X, BARRIER_HEIGHT, wall.Size.Z),
				wall.CFrame * CFrame.new(0, BARRIER_HEIGHT / 2 - wall.Size.Y / 2, 0),
				Color3.new()
			)
		)
		barrier.CanCollide = true
	end
	-- the raised stage with a gold lip and steps at the path
	brick(
		model,
		"Stage",
		Vector3.new(W - 4, SH, D - SD - 1),
		at(0, FLOOR + SH / 2, SD + (D - SD - 1) / 2),
		NAVY_DARK
	)
	brick(model, "StageLip", Vector3.new(W - 4, 0.5, 0.8), at(0, stageTop + 0.05, SD + 0.4), GOLD)
	brick(model, "Step1", Vector3.new(14, SH / 2, 2.4), at(0, FLOOR + SH / 4, SD - 2.4), NAVY)
	brick(model, "Step2", Vector3.new(14, SH, 1.2), at(0, FLOOR + SH / 2, SD - 0.6), NAVY)

	-- laser door (server toggles it when locked): a visible laser + a tall invisible blocker
	local laser = smooth(
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
	local laserBarrier = invisible(
		brick(
			model,
			"LaserBarrier",
			Vector3.new(World.EntranceWidth, BARRIER_HEIGHT, 0.6),
			at(0, BARRIER_HEIGHT / 2, 0),
			Color3.new()
		)
	)
	laserBarrier.CanCollide = false

	-- entrance sign with the owner's name (faces the plaza; the arch posts are palace decor)
	local sign = smooth(model, "Sign", Vector3.new(World.EntranceWidth + 8, 4.6, 1.2), at(0, 12, -0.4), NAVY)
	-- thinner than the sign, so it shows as a gold border without covering either face
	brick(model, "SignTrim", Vector3.new(World.EntranceWidth + 9, 5.4, 0.8), at(0, 12, -0.4), GOLD)
	local signLabel = surfaceText(sign, Enum.NormalId.Back, "FREE BASE", Color3.fromRGB(200, 200, 210))
	surfaceText(sign, Enum.NormalId.Front, "🏠", Color3.new(1, 1, 1))

	-- pedestals: navy podiums with a gold rim on the stage
	local pedestals: { BasePart } = {}
	local cols = World.PedestalColumns
	for r = 1, World.PedestalRows do
		for c = 1, cols do
			local lx = (c - (cols + 1) / 2) * World.PedestalSpacingX
			-- cylinders run along X: stood up with a 90° turn about Z
			local ped = smooth(
				model,
				"Pedestal",
				Vector3.new(1.2, 5.4, 5.4),
				at(lx, stageTop + 0.6, World.PedestalRowDepth[r]) * CFrame.Angles(0, 0, math.rad(90)),
				NAVY
			)
			ped.Shape = Enum.PartType.Cylinder
			ped:SetAttribute("Slot", #pedestals + 1)
			table.insert(pedestals, ped)
		end
	end

	-- the treadmill out on the plaza in front of the base (standing on it = training; its frame
	-- is Palace decor that grows with the treadmill level)
	local belt = smooth(
		model,
		"Treadmill",
		Vector3.new(9, 0.6, 20),
		at(BELT_X, FLOOR + 0.3, BELT_DEPTH),
		Color3.fromRGB(60, 30, 120),
		Enum.Material.SmoothPlastic
	)
	belt:SetAttribute("BeltColor", Color3.fromRGB(170, 90, 255)) -- stripes scroll on the client (Ambient)
	local screen = smooth(
		model,
		"TreadScreen",
		Vector3.new(9, 3.2, 1),
		at(BELT_X, FLOOR + 8.6, BELT_DEPTH + 9.5),
		Color3.fromRGB(30, 20, 60)
	)
	surfaceText(screen, Enum.NormalId.Back, "⚡ SPEED ⚡", Color3.fromRGB(120, 230, 255))

	-- upgrade signs (wooden boards): far enough from the belt that the prompt never pops up there
	local treadSign =
		woodSign(model, "TreadSign", at(BELT_X - 13, FLOOR + 4.2, BELT_DEPTH + 2), "Upgrade Treadmill")
	local plotSign = woodSign(model, "PlotSign", at(-20, FLOOR + 4.6, 6), "Upgrade Plot")

	-- collect pad by the entrance (front right): gold rim, green glow
	brick(model, "PadRim", Vector3.new(9.4, 0.3, 9.4), at(W / 2 - 12, FLOOR + 0.1, 8), GOLD)
	local collectPad = smooth(
		model,
		"CollectPad",
		Vector3.new(8, 0.4, 8),
		at(W / 2 - 12, FLOOR + 0.2, 8),
		Color3.fromRGB(70, 230, 90),
		Enum.Material.Neon
	)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(10, 0, 2.2, 0) -- studs: shrinks with distance instead of filling the screen
	bb.StudsOffset = Vector3.new(0, 3, 0)
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

	-- crates wait on the front edge of the stage (in front of the podiums, both sides of the
	-- steps) with the appraiser standing beside them, like the genre
	local crateSpots: { CFrame } = {}
	for _, lx in { -10.5, 10.5, -17.5, 17.5, -24.5, 24.5, -31.5, 31.5 } do
		-- the lock faces the entrance
		table.insert(crateSpots, at(lx, stageTop, SD + 2.6) * CFrame.Angles(0, math.rad(180), 0))
	end
	appraiser(model, at(38.5, stageTop, SD + 2.6) * CFrame.Angles(0, math.rad(180), 0))

	-- crown beam (visible when this base belongs to THE RICHEST)
	local beam = smooth(
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

	local record: BaseRecord = {
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
		crateSpots = crateSpots,
		spawnCFrame = at(0, 4, 11) * CFrame.Angles(0, math.rad(180), 0),
	}
	-- a free base starts as the plain wooden shack with the wooden treadmill
	Palace.dressBase(record, 1)
	Palace.dressTreadmill(record, 1)
	return record
end

-- A giant studded wall in two-tone checker squares with bunting along the top.
-- `cf`: bottom center; the wall runs along local X, its inner face looks along local -Z.
local function checkerWall(
	parent: Instance,
	name: string,
	cf: CFrame,
	length: number,
	height: number,
	a: Color3,
	b: Color3,
	square: number
)
	brick(parent, name, Vector3.new(length, height, 4), cf * CFrame.new(0, height / 2, 0), a, true)
	local cols = math.floor(length / square)
	local rows = math.floor(height / square)
	local x0 = -cols * square / 2 + square / 2
	for c = 0, cols - 1 do
		for r = 0, rows - 1 do
			if (c + r) % 2 == 0 then
				deco(
					brick(
						parent,
						"Checker",
						Vector3.new(square, square, 0.4),
						cf * CFrame.new(x0 + c * square, r * square + square / 2, -2.2),
						b,
						true
					)
				)
			end
		end
	end
	brick(
		parent,
		name .. "Top",
		Vector3.new(length + 2, 2, 6),
		cf * CFrame.new(0, height + 1, 0),
		b:Lerp(Color3.new(0, 0, 0), 0.2)
	)
	-- bunting: little colored flags along the top of the inner face
	local flags = {
		Color3.fromRGB(255, 140, 30),
		Color3.fromRGB(150, 60, 220),
		Color3.fromRGB(255, 220, 60),
		Color3.fromRGB(80, 200, 255),
	}
	local i = 0
	for x = -length / 2 + 4, length / 2 - 4, 8 do
		i += 1
		local flag = deco(
			brick(
				parent,
				"Bunting",
				Vector3.new(2.4, 2.4, 0.3),
				cf * CFrame.new(x, height - 2.2, -2.6) * CFrame.Angles(0, 0, math.rad(45)),
				flags[i % #flags + 1]
			)
		)
		flag.CastShadow = false
	end
end

-- What hangs on a zone's walls (inner faces), by style. `at` is the zone's local frame.
local function wallDressing(
	model: Instance,
	at: (number, number, number) -> CFrame,
	style: ZoneStyle,
	trim: Color3
)
	local L, HW = World.VaultSpacing, World.ZoneHalfWidth
	local kind = style.walls
	for _, side in { -1, 1 } do
		local x = side * (HW - 1.3) -- just in front of the wall's inner face
		local faceIn = CFrame.Angles(0, math.rad(side * 90), 0) -- a part's Front looks toward the street
		if kind == "houses" or kind == "awnings" then
			-- building fronts: framed windows, flower boxes; awnings + diamond banners on the shop street
			for depth = 10, L - 8, 16 do
				for _, y in { 8, 19 } do
					brick(
						model,
						"WindowFrame",
						Vector3.new(5, 6, 0.5),
						at(x, y, depth) * faceIn,
						Color3.fromRGB(245, 245, 240)
					)
					deco(
						smooth(
							model,
							"Window",
							Vector3.new(4, 5, 0.4),
							at(x - side * 0.2, y, depth) * faceIn,
							Color3.fromRGB(110, 180, 230),
							Enum.Material.Glass
						)
					)
				end
				if kind == "awnings" then
					deco(
						brick(
							model,
							"Awning",
							Vector3.new(8, 0.6, 3),
							at(x - side * 1.5, 12.5, depth) * faceIn * CFrame.Angles(math.rad(-15), 0, 0),
							Color3.fromRGB(30, 30, 35)
						)
					)
					deco(
						brick(
							model,
							"DiamondBanner",
							Vector3.new(3, 5, 0.3),
							at(x - side * 0.3, 24, depth + 8) * faceIn,
							Color3.fromRGB(25, 25, 30)
						)
					)
					deco(
						brick(
							model,
							"BannerGem",
							Vector3.new(1.4, 1.4, 0.3),
							at(x - side * 0.5, 24, depth + 8) * faceIn * CFrame.Angles(0, 0, math.rad(45)),
							Color3.fromRGB(120, 220, 255)
						)
					)
				else
					deco(
						brick(
							model,
							"FlowerBox",
							Vector3.new(5, 1, 1.2),
							at(x - side * 0.6, 4.6, depth) * faceIn,
							Color3.fromRGB(150, 100, 60)
						)
					)
				end
			end
		elseif kind == "posters" then
			for depth = 12, L - 8, 22 do
				deco(
					brick(
						model,
						"Poster",
						Vector3.new(7, 9, 0.3),
						at(x, 11, depth) * faceIn,
						Color3.fromRGB(235, 230, 220)
					)
				)
				deco(
					brick(
						model,
						"PosterInk",
						Vector3.new(5, 0.8, 0.2),
						at(x - side * 0.2, 13, depth) * faceIn,
						Color3.fromRGB(200, 40, 50)
					)
				)
				brick(
					model,
					"Camera",
					Vector3.new(1.2, 1.2, 2.4),
					at(x - side * 1.2, 22, depth + 11) * faceIn,
					Color3.fromRGB(220, 220, 225)
				)
			end
		elseif kind == "banners" then
			for depth = 9, L - 4, 18 do
				deco(
					brick(
						model,
						"Banner",
						Vector3.new(4, 12, 0.3),
						at(x, 19, depth) * faceIn,
						Color3.fromRGB(255, 120, 190)
					)
				)
				deco(
					brick(
						model,
						"BannerStar",
						Vector3.new(2, 2, 0.3),
						at(x - side * 0.2, 21, depth) * faceIn * CFrame.Angles(0, 0, math.rad(45)),
						Color3.fromRGB(255, 240, 120)
					)
				)
			end
		elseif kind == "glyphs" then
			local rng = Random.new(77)
			for depth = 6, L - 4, 7 do
				for _, y in { 9, 15, 21 } do
					if rng:NextNumber() < 0.6 then
						deco(
							brick(
								model,
								"Glyph",
								Vector3.new(2, 2.4, 0.3),
								at(x, y + rng:NextNumber(-1, 1), depth) * faceIn,
								Color3.fromRGB(120, 90, 50)
							)
						)
					end
				end
			end
		elseif kind == "planks" then
			for y = 5, 26, 6 do
				deco(
					brick(
						model,
						"Plank",
						Vector3.new(0.3, 1, L - 2),
						at(x, y, L / 2),
						Color3.fromRGB(100, 72, 44)
					)
				)
			end
			-- the sea laps at the sides of the beach street
			for depth = 6, L - 6, 14 do
				deco(
					smooth(
						model,
						"Water",
						Vector3.new(10, 0.15, 12),
						at(side * (HW - 6), FLOOR + 0.08, depth),
						Color3.fromRGB(70, 170, 245)
					)
				)
			end
		elseif kind == "paintings" then
			for depth = 12, L - 8, 20 do
				brick(
					model,
					"PaintingFrame",
					Vector3.new(9, 7, 0.5),
					at(x, 12, depth) * faceIn,
					Color3.fromRGB(190, 140, 50)
				)
				deco(
					brick(
						model,
						"Canvas",
						Vector3.new(7.4, 5.4, 0.3),
						at(x - side * 0.3, 12, depth) * faceIn,
						Color3.fromHSV((depth % 37) / 37, 0.55, 0.75)
					)
				)
				local lamp = deco(
					brick(
						model,
						"GalleryLamp",
						Vector3.new(2, 0.6, 1.2),
						at(x - side * 0.8, 16.5, depth) * faceIn,
						Color3.fromRGB(255, 230, 150)
					)
				)
				lamp.Material = Enum.Material.Neon
			end
		elseif kind == "gears" then
			for depth = 12, L - 8, 24 do
				local gear = deco(smooth(model, "Gear", Vector3.new(0.6, 9, 9), at(x, 15, depth), trim))
				gear.Shape = Enum.PartType.Cylinder
				deco(
					brick(
						model,
						"GearHub",
						Vector3.new(0.8, 3, 3),
						at(x - side * 0.2, 15, depth),
						Color3.fromRGB(40, 40, 45)
					)
				)
			end
			-- gold lane stripes down the floor
			for _, lx in { -9, 9 } do
				deco(brick(model, "GoldStripe", Vector3.new(1, 0.12, L), at(lx, FLOOR + 0.06, L / 2), trim))
			end
		end
	end
end

-- ===== A rich person's street on the corridor =====
-- A wide studded street between tall two-tone checker walls dressed in the zone's style, a
-- glowing green line where it starts (black iron fences at the sides), themed props along the
-- walls, and the owner's crates piled up on the right (they stand among them and chase thieves).
local function buildZone(parent: Instance, index: number, origin: CFrame): VaultRecord
	local def = Vaults[index]
	local model = Instance.new("Model")
	model.Name = "Vault_" .. def.id
	model:SetAttribute("VaultIndex", index)
	model.Parent = parent
	local trim = rgb(def.trim)
	local style: ZoneStyle = ZONE_STYLE[def.id]
		or {
			floor = { 230, 225, 210 },
			patch = { 205, 200, 185 },
			wall = def.color,
			wall2 = def.trim,
			walls = "houses",
			rug = def.trim,
		}
	local L, HW, WH = World.VaultSpacing, World.ZoneHalfWidth, World.ZoneWallHeight

	local function at(lx: number, ly: number, depth: number): CFrame
		return origin * CFrame.new(lx, ly, -depth)
	end

	brick(model, "Floor", Vector3.new(HW * 2, FLOOR, L), at(0, FLOOR / 2, L / 2), rgb(style.floor))
	-- checker patches (2x2 tiles of 6 studs) scattered over the floor
	local rng = Random.new(index * 97)
	for _ = 1, 18 do
		local px = rng:NextInteger(-6, 5) * 6 + 3
		local pd = rng:NextInteger(1, math.floor(L / 6) - 2) * 6
		for _, o in { Vector2.new(0, 0), Vector2.new(6, 6) } do
			deco(
				brick(
					model,
					"Patch",
					Vector3.new(6, 0.1, 6),
					at(px + o.X, FLOOR + 0.05, pd + o.Y),
					rgb(style.patch)
				)
			)
		end
	end

	-- the tall two-tone checker walls (inner faces toward the street)
	for _, side in { -1, 1 } do
		local cf = at(side * (HW + 1), 0, L / 2) * CFrame.Angles(0, math.rad(side * 90), 0)
		checkerWall(model, "Wall", cf, L, WH, rgb(style.wall), rgb(style.wall2), 12)
	end
	wallDressing(model, at, style, trim)
	-- a colored strip along both walls (the genre's floor edging)
	if style.border then
		for _, side in { -1, 1 } do
			deco(
				brick(
					model,
					"Border",
					Vector3.new(4, 0.14, L),
					at(side * (HW - 2), FLOOR + 0.07, L / 2),
					rgb(style.border :: { number })
				)
			)
		end
	end

	-- where the zone starts: a glowing green line across the street + black iron fences at the sides
	local line = deco(
		brick(
			model,
			"ZoneLine",
			Vector3.new(HW * 2, 0.12, 1.2),
			at(0, FLOOR + 0.06, 0.6),
			Color3.fromRGB(80, 255, 90)
		)
	)
	line.Material = Enum.Material.Neon
	for _, side in { -1, 1 } do
		for k = 0, 4 do
			brick(
				model,
				"FencePost",
				Vector3.new(0.6, 7, 0.6),
				at(side * (HW - 1 - k * 4), FLOOR + 3.5, 0),
				Color3.fromRGB(25, 25, 30)
			)
		end
		for _, y in { 2.5, 6 } do
			deco(
				brick(
					model,
					"FenceBar",
					Vector3.new(16, 0.4, 0.4),
					at(side * (HW - 9), FLOOR + y, 0),
					Color3.fromRGB(25, 25, 30)
				)
			)
		end
	end

	-- the owner's crate pile: 6 spots (3 x 2) on the right side of the street
	local cs = 1
	local pedestals: { BasePart } = {}
	for _, depth in { 56, 63, 70 } do
		for _, lx in { 20, 27 } do
			local spot = brick(
				model,
				"Pedestal",
				Vector3.new(6, 0.3, 6),
				at(cs * lx, FLOOR + 0.15, depth),
				rgb(style.patch):Lerp(Color3.new(0, 0, 0), 0.15)
			)
			table.insert(pedestals, spot)
		end
	end
	-- the crates stand on the owner's carpet, with a wooden "recommended speed" sign in front
	deco(brick(model, "CrateRug", Vector3.new(18, 0.12, 25), at(cs * 23.5, FLOOR + 0.06, 63), rgb(style.rug)))
	local need = math.max(0, Progression.pointsFor(Progression.speedToOutrun(index)))
	local speedSign = brick(
		model,
		"SpeedSign",
		Vector3.new(0.6, 3, 6.5),
		at(cs * 13.5, FLOOR + 3.2, 63),
		Color3.fromRGB(196, 140, 80)
	)
	brick(
		model,
		"SpeedSignPost",
		Vector3.new(0.5, 1.8, 0.5),
		at(cs * 13.5, FLOOR + 0.9, 63),
		Color3.fromRGB(130, 90, 50)
	)
	surfaceText(
		speedSign,
		if cs > 0 then Enum.NormalId.Left else Enum.NormalId.Right,
		if need < 1 then "⚡ ANY SPEED" else "⚡ " .. Format.number(math.ceil(need)) .. "\nrecommended",
		Color3.fromRGB(120, 255, 120)
	)
	WorldDecor.station(model, def.id, at(cs * 40, FLOOR, 63) * CFrame.Angles(0, math.rad(cs * 90), 0))
	WorldDecor.zone(model, def.id, origin, trim)
	WorldDecor.scatter(model, def.id, origin, index)

	-- [1] the owner, right by their crates; [2] the zone's guardian creature (if any) lying beside
	-- them; bodyguards around them in the richer zones
	local guardSpawns: { CFrame } = { at(cs * 34, 4, 63) * CFrame.Angles(0, math.rad(cs * 90), 0) }
	for g = 2, def.guards do
		if g == 2 and def.guardian then
			table.insert(guardSpawns, at(cs * 34, 4, 40))
		else
			table.insert(guardSpawns, at(cs * 12, 4, 44 + (g - 2) * 26))
		end
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

-- A market stall with a striped awning (SELL), front facing `cf`'s -Z.
local function stall(parent: Instance, cf: CFrame, title: string, awning: Color3): BasePart
	local counter = brick(
		parent,
		"Counter",
		Vector3.new(12, 3.5, 4),
		cf * CFrame.new(0, 1.75, 0),
		Color3.fromRGB(150, 100, 60)
	)
	for _, x in { -5.6, 5.6 } do
		brick(
			parent,
			"StallPost",
			Vector3.new(0.8, 9, 0.8),
			cf * CFrame.new(x, 4.5, 1.6),
			Color3.fromRGB(110, 70, 40)
		)
	end
	for i = 0, 5 do
		brick(
			parent,
			"Awning",
			Vector3.new(2.2, 0.5, 6),
			cf * CFrame.new(-5.5 + i * 2.2, 9, -0.4) * CFrame.Angles(math.rad(-12), 0, 0),
			if i % 2 == 0 then awning else Color3.new(1, 1, 1)
		)
	end
	local sign = smooth(
		parent,
		"StallSign",
		Vector3.new(12, 3.6, 0.6),
		cf * CFrame.new(0, 12, 1.6),
		Color3.new(1, 1, 1)
	)
	sign.Transparency = 1
	surfaceText(sign, Enum.NormalId.Front, title, awning, nil, Enum.Font.LuckiestGuy)
	surfaceText(sign, Enum.NormalId.Back, title, awning, nil, Enum.Font.LuckiestGuy)
	return counter
end

function WorldBuilder.build(): WorldInfo
	setupLighting()
	local root = Instance.new("Folder")
	root.Name = "World"
	root.Parent = workspace

	local HW = World.ZoneHalfWidth
	local n = World.BaseCount
	local pitch = World.BaseWidth + World.BaseGap
	local halfZ = n * pitch / 2 + 12 -- the plaza runs along z, as long as the row of bases
	local westX = World.BaseFrontX - World.BaseDepth - 10 -- the wall behind the bases
	local eastX = World.StreetStartX -- the wall with the street's mouth
	local zonesStart = eastX + World.ZoneGap
	local streetEnd = zonesStart + #Vaults * World.VaultSpacing
	local groundDepth = halfZ * 2 + 40
	local minX = westX - 20
	local groundW = streetEnd + 60 - minX
	local groundCenterX = (streetEnd + 60 + minX) / 2
	brick(root, "Ground", Vector3.new(groundW, 4, groundDepth), CFrame.new(groundCenterX, -2, 0), LIME)

	-- the island: beach, ocean and a ring of mountains (seen over the walls: the world never ends)
	local BEACH = 18
	WorldDecor.surroundings(root, groundCenterX, groundW, groundDepth, BEACH)
	local bw, bd = groundW + BEACH * 2 - 6, groundDepth + BEACH * 2 - 6
	for _, b in
		{
			{ Vector3.new(bw, 80, 2), Vector3.new(groundCenterX, 40, bd / 2) },
			{ Vector3.new(bw, 80, 2), Vector3.new(groundCenterX, 40, -bd / 2) },
			{ Vector3.new(2, 80, bd), Vector3.new(groundCenterX - bw / 2, 40, 0) },
			{ Vector3.new(2, 80, bd), Vector3.new(groundCenterX + bw / 2, 40, 0) },
		}
	do
		local w = brick(root, "Bound", b[1], CFrame.new(b[2]), Color3.new())
		w.Transparency = 1
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.new(World.BaseFrontX + 50, 0.3, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = root

	-- the bases: one row along the west side, all facing east across the plaza at the street
	local bases: { BaseRecord } = {}
	local basesFolder = Instance.new("Folder")
	basesFolder.Name = "Bases"
	basesFolder.Parent = workspace
	for i = 1, n do
		local front = Vector3.new(World.BaseFrontX, 0, (i - (n + 1) / 2) * pitch)
		local origin = CFrame.lookAt(front, front - Vector3.xAxis) -- LookVector points into the base
		table.insert(bases, buildBase(basesFolder, i, origin))
	end

	-- the giant checker walls around the plaza (the east one has the street's mouth in the middle)
	local H = World.PlazaWallHeight
	local walls = Instance.new("Folder")
	walls.Name = "PlazaWalls"
	walls.Parent = root
	local greenA, greenB = Color3.fromRGB(110, 196, 70), Color3.fromRGB(88, 170, 52)
	local brownA, brownB = Color3.fromRGB(196, 116, 64), Color3.fromRGB(224, 146, 76)
	local function face(pos: Vector3, inward: Vector3): CFrame
		return CFrame.lookAt(pos, pos + inward)
	end
	checkerWall(
		walls,
		"WestWall",
		face(Vector3.new(westX - 2, 0, 0), Vector3.xAxis),
		halfZ * 2,
		H,
		greenA,
		greenB,
		16
	)
	for _, side in { -1, 1 } do
		checkerWall(
			walls,
			if side > 0 then "NorthWall" else "SouthWall",
			face(Vector3.new((westX + eastX) / 2, 0, side * (halfZ + 2)), Vector3.zAxis * -side),
			eastX - westX + 8,
			H,
			greenA,
			greenB,
			16
		)
		local len = halfZ - HW
		checkerWall(
			walls,
			"EastWall",
			face(Vector3.new(eastX + 2, 0, side * (HW + len / 2)), -Vector3.xAxis),
			len,
			H,
			brownA,
			brownB,
			16
		)
	end

	-- Rich Street's mouth: gate posts, the sign, a short hall into the first zone
	local gx = eastX
	brick(
		root,
		"EntryHall",
		Vector3.new(World.ZoneGap, 0.4, HW * 2),
		CFrame.new(gx + World.ZoneGap / 2, 0.2, 0),
		Color3.fromRGB(205, 205, 210)
	)
	for _, side in { -1, 1 } do
		brick(
			root,
			"GatePost",
			Vector3.new(6, H + 4, 6),
			CFrame.new(gx, (H + 4) / 2, side * (HW + 3)),
			NAVY,
			true
		)
		for y = 6, H, 8 do
			brick(root, "GateBand", Vector3.new(6.8, 1, 6.8), CFrame.new(gx, y, side * (HW + 3)), GOLD)
		end
		brick(
			root,
			"HallWall",
			Vector3.new(World.ZoneGap, World.ZoneWallHeight, 2),
			CFrame.new(gx + World.ZoneGap / 2, World.ZoneWallHeight / 2, side * (HW + 1)),
			Color3.fromRGB(150, 150, 160),
			true
		)
	end
	local gateSign =
		smooth(root, "GateSign", Vector3.new(3, 10, HW * 2 + 12), CFrame.new(gx, 40, 0), NAVY_DARK)
	surfaceText(gateSign, Enum.NormalId.Left, "💰 RICH STREET 💰", GOLD)
	surfaceText(gateSign, Enum.NormalId.Right, "🏠 HOME 🏠", Color3.fromRGB(120, 255, 130))
	-- SAFE ZONE painted on the grass with a red line, in front of the street's mouth
	local line = deco(
		brick(
			root,
			"SafeLine",
			Vector3.new(1, 0.1, HW * 2),
			CFrame.new(gx - 6, 0.05, 0),
			Color3.fromRGB(230, 30, 40)
		)
	)
	line.Material = Enum.Material.SmoothPlastic
	local paint = deco(smooth(
		root,
		"SafeZonePaint",
		Vector3.new(40, 0.05, 10),
		CFrame.new(gx - 14, 0.08, 0) * CFrame.Angles(0, math.rad(-90), 0), -- reads walking out to the street
		Color3.new(1, 1, 1)
	))
	paint.Transparency = 1
	surfaceText(paint, Enum.NormalId.Top, "SAFE ZONE", Color3.new(1, 1, 1), nil, Enum.Font.LuckiestGuy)

	local vaults: { VaultRecord } = {}
	local vaultFolder = Instance.new("Folder")
	vaultFolder.Name = "Vaults"
	vaultFolder.Parent = workspace
	for i = 1, #Vaults do
		local x0 = zonesStart + (i - 1) * World.VaultSpacing
		local origin = CFrame.lookAt(Vector3.new(x0, 0, 0), Vector3.new(x0 + 1, 0, 0))
		table.insert(vaults, buildZone(vaultFolder, i, origin))
	end
	local endWall =
		brick(root, "EndWall", Vector3.new(2, 32, HW * 2), CFrame.new(streetEnd + 1, 16, 0), NAVY_DARK, true)
	surfaceText(endWall, Enum.NormalId.Left, "🚧 MORE RICH PEOPLE COMING SOON 🚧", GOLD)

	-- the shops stand along the east wall beside the street's mouth, facing the bases (-X)
	local function facingBases(z: number): CFrame
		local pos = Vector3.new(eastX - 14, 0.3, z)
		return CFrame.lookAt(pos, pos - Vector3.xAxis)
	end

	-- WANTED board (the richest player) on the east wall, south of the street
	local wantedZ = -(HW + 70)
	local board = smooth(
		root,
		"WantedBoard",
		Vector3.new(30, 18, 1),
		CFrame.lookAt(Vector3.new(eastX - 0.6, 22, wantedZ), Vector3.new(eastX - 1.6, 22, wantedZ)),
		Color3.fromRGB(240, 220, 170)
	)
	local wanted: { [string]: any } = { Image = {}, Title = {}, Name = {}, Bounty = {} }
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front -- faces the plaza
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
		local st = Instance.new("UIStroke")
		st.Thickness = 3
		st.Color = Color3.fromRGB(60, 30, 10)
		st.Parent = l
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

	-- Longest Reign board on the east wall, north of the street
	local reign = smooth(
		root,
		"ReignBoard",
		Vector3.new(1, 22, 26),
		CFrame.new(eastX - 0.6, 24, HW + 110),
		Color3.fromRGB(30, 25, 35)
	)
	local rsg = Instance.new("SurfaceGui")
	rsg.Face = Enum.NormalId.Left -- faces the plaza (-X)
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

	-- Fuse machine (grey workshop with a mystery block) and the SELL stall, north of the street
	local fcf = facingBases(HW + 62)
	local machine = brick(
		root,
		"FuseMachine",
		Vector3.new(14, 9, 10),
		fcf * CFrame.new(0, 4.5, 0),
		Color3.fromRGB(165, 170, 180),
		true
	)
	brick(
		root,
		"FuseRoof",
		Vector3.new(15, 1.2, 11),
		fcf * CFrame.new(0, 9.6, 0),
		Color3.fromRGB(110, 115, 125)
	)
	local mystery = brick(
		root,
		"FuseBox",
		Vector3.new(5, 5, 5),
		fcf * CFrame.new(0, 12.7, 0),
		Color3.fromRGB(90, 140, 255)
	)
	surfaceText(mystery, Enum.NormalId.Front, "?", Color3.new(1, 1, 1), nil, Enum.Font.LuckiestGuy)
	surfaceText(mystery, Enum.NormalId.Back, "?", Color3.new(1, 1, 1), nil, Enum.Font.LuckiestGuy)
	local hatch = smooth(
		root,
		"FuseHatch",
		Vector3.new(6, 4, 0.4),
		fcf * CFrame.new(0, 3, -5.1),
		Color3.fromRGB(150, 70, 255),
		Enum.Material.Neon
	)
	hatch.CanCollide = false
	local fsign = smooth(
		root,
		"FuseSign",
		Vector3.new(14, 3, 1),
		fcf * CFrame.new(0, 17.5, 0),
		Color3.fromRGB(60, 40, 90)
	)
	surfaceText(fsign, Enum.NormalId.Front, "🧪 FUSE MACHINE", Color3.fromRGB(230, 200, 255))
	surfaceText(fsign, Enum.NormalId.Back, "🧪 FUSE MACHINE", Color3.fromRGB(230, 200, 255))
	local fusePrompt = prompt(machine, "Fuse", "3 identical → 1 better", 0)
	fusePrompt.MaxActivationDistance = 16

	local sellCounter = stall(root, facingBases(HW + 30), "SELL", Color3.fromRGB(230, 40, 50))
	local sellPrompt = prompt(sellCounter, "Sell", "Sell your items", 0)
	sellPrompt.MaxActivationDistance = 14

	-- the trails shop, south of the street
	local trailsPrompt = WorldDecor.trailsShop(root, facingBases(-(HW + 30)))

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
		sellPrompt = sellPrompt,
		streetEnd = streetEnd,
		halloween = halloween,
	}
end

WorldBuilder.FLOOR = FLOOR
WorldBuilder.prompt = prompt

return WorldBuilder
