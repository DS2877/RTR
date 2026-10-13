--!strict
-- Set dressing built from LEGO-style parts: a unique theme along the walls of every rich person's
-- street, the island around the map, fountains, the trails shop, Halloween. Pure decoration
-- (plus the pedestal rings); nothing here touches the economy.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)

local WorldDecor = {}

local M = Enum.Material

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Materials that stay as they are; everything else becomes a studded LEGO brick (the genre look).
local KEEP: { [Enum.Material]: boolean } = {
	[M.Neon] = true,
	[M.Glass] = true,
	[M.ForceField] = true,
	[M.Grass] = true,
	[M.Sand] = true,
	[M.Rock] = true,
}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	if material and KEEP[material] then
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
	else
		p.Material = M.Plastic
		p.TopSurface = Enum.SurfaceType.Studs
	end
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- Decoration that players walk through (no collision, no queries): keeps paths clear.
local function deco(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = part(parent, name, size, cf, color, material, shape)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = shape ~= Enum.PartType.Ball
	return p
end

-- Upright cylinder (Roblox cylinders run along X).
local function cyl(
	parent: Instance,
	name: string,
	height: number,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	return part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		cf * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		Enum.PartType.Cylinder
	)
end

local function light(p: BasePart, color: Color3, range: number, brightness: number?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1.5
	l.Shadows = false
	l.Parent = p
end

local function label(p: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 25
	sg.LightInfluence = 0
	sg.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = rgb(20, 20, 25)
	s.Parent = l
	l.Parent = sg
end

-- ===== small props =====
local function barrel(parent: Instance, cf: CFrame, color: Color3)
	cyl(parent, "Barrel", 3.2, 2.4, cf * CFrame.new(0, 1.6, 0), color, M.Wood)
	cyl(parent, "Hoop", 0.25, 2.5, cf * CFrame.new(0, 2.4, 0), rgb(60, 60, 65), M.Metal)
	cyl(parent, "Hoop", 0.25, 2.5, cf * CFrame.new(0, 0.8, 0), rgb(60, 60, 65), M.Metal)
end

local function chest(parent: Instance, cf: CFrame)
	part(parent, "Chest", Vector3.new(4, 2.4, 2.6), cf * CFrame.new(0, 1.2, 0), rgb(120, 75, 40), M.Wood)
	part(parent, "Lid", Vector3.new(4.1, 0.8, 2.7), cf * CFrame.new(0, 2.8, 0), rgb(100, 60, 30), M.Wood)
	part(
		parent,
		"Lock",
		Vector3.new(0.6, 0.8, 0.2),
		cf * CFrame.new(0, 2.3, -1.4),
		rgb(255, 200, 40),
		M.SmoothPlastic
	)
	local gold = deco(
		parent,
		"Gold",
		Vector3.new(3.4, 0.6, 2.2),
		cf * CFrame.new(0, 3.3, 0.2),
		rgb(255, 205, 40),
		M.SmoothPlastic
	)
	light(gold, rgb(255, 200, 80), 8, 1)
end

local function coinPile(parent: Instance, cf: CFrame, scale: number)
	for i = 0, 3 do
		local d = (4 - i) * 1.6 * scale
		cyl(
			parent,
			"Coins",
			0.8 * scale,
			d,
			cf * CFrame.new(0, (i + 0.5) * 0.8 * scale, 0),
			rgb(255, 205, 40),
			M.SmoothPlastic
		)
	end
end

local function goldBars(parent: Instance, cf: CFrame)
	for row = 0, 2 do
		for i = 0, 2 - row do
			part(
				parent,
				"GoldBar",
				Vector3.new(2.2, 0.8, 1.1),
				cf * CFrame.new((i - (2 - row) / 2) * 2.3, 0.4 + row * 0.8, 0),
				rgb(255, 205, 50),
				M.SmoothPlastic
			)
		end
	end
end

local function car(parent: Instance, cf: CFrame, color: Color3)
	part(parent, "CarBody", Vector3.new(6, 2, 13), cf * CFrame.new(0, 1.8, 0), color, M.Metal)
	part(
		parent,
		"CarCabin",
		Vector3.new(5.4, 2, 6),
		cf * CFrame.new(0, 3.6, 1),
		color:Lerp(rgb(0, 0, 0), 0.15),
		M.Metal
	)
	part(
		parent,
		"Windshield",
		Vector3.new(5, 1.6, 0.2),
		cf * CFrame.new(0, 3.6, -2.05),
		rgb(150, 200, 230),
		M.Glass
	).Transparency =
		0.3
	for _, x in { -3, 3 } do
		for _, z in { -4.2, 4.2 } do
			part(
				parent,
				"Wheel",
				Vector3.new(1, 2.4, 2.4),
				cf * CFrame.new(x, 1.2, z),
				rgb(25, 25, 28),
				M.Rubber,
				Enum.PartType.Cylinder
			)
		end
	end
	for _, x in { -2, 2 } do
		local h = part(
			parent,
			"Headlight",
			Vector3.new(1.2, 0.6, 0.2),
			cf * CFrame.new(x, 2, -6.55),
			rgb(255, 250, 220),
			M.Neon
		)
		light(h, rgb(255, 245, 210), 10, 1)
	end
end

local function column(parent: Instance, cf: CFrame, height: number, color: Color3)
	part(parent, "ColumnBase", Vector3.new(3.4, 0.8, 3.4), cf * CFrame.new(0, 0.4, 0), color, M.Marble)
	cyl(parent, "Column", height - 1.6, 2.6, cf * CFrame.new(0, height / 2, 0), color, M.Marble)
	part(
		parent,
		"ColumnTop",
		Vector3.new(3.4, 0.8, 3.4),
		cf * CFrame.new(0, height - 0.4, 0),
		color,
		M.Marble
	)
end

local function frame(parent: Instance, cf: CFrame, w: number, h: number, art: string, bg: Color3)
	part(parent, "Frame", Vector3.new(w + 0.6, h + 0.6, 0.3), cf, rgb(190, 140, 40), M.SmoothPlastic)
	local canvas = part(parent, "Canvas", Vector3.new(w, h, 0.35), cf, bg, M.SmoothPlastic)
	label(canvas, Enum.NormalId.Front, art, rgb(255, 255, 255), Enum.Font.GothamBold)
end

local function statue(parent: Instance, cf: CFrame, scale: number)
	local gold = rgb(255, 200, 40)
	part(
		parent,
		"Plinth",
		Vector3.new(5, 3, 5) * scale,
		cf * CFrame.new(0, 1.5 * scale, 0),
		rgb(40, 35, 45),
		M.Marble
	)
	part(
		parent,
		"Legs",
		Vector3.new(2, 3, 1) * scale,
		cf * CFrame.new(0, 4.5 * scale, 0),
		gold,
		M.SmoothPlastic
	)
	part(
		parent,
		"Body",
		Vector3.new(2.6, 3, 1.4) * scale,
		cf * CFrame.new(0, 7.5 * scale, 0),
		gold,
		M.SmoothPlastic
	)
	part(
		parent,
		"Head",
		Vector3.new(1.6, 1.6, 1.6) * scale,
		cf * CFrame.new(0, 9.8 * scale, 0),
		gold,
		M.SmoothPlastic
	)
	part(
		parent,
		"TopHat",
		Vector3.new(1.4, 1.6, 1.4) * scale,
		cf * CFrame.new(0, 11.4 * scale, 0),
		rgb(20, 20, 25),
		M.SmoothPlastic
	)
	part(
		parent,
		"ArmUp",
		Vector3.new(0.8, 3, 0.8) * scale,
		cf * CFrame.new(1.8 * scale, 9 * scale, 0) * CFrame.Angles(0, 0, math.rad(-25)),
		gold,
		M.SmoothPlastic
	)
	local bag = part(
		parent,
		"MoneyBag",
		Vector3.new(1.6, 1.6, 1.6) * scale,
		cf * CFrame.new(2.6 * scale, 11 * scale, 0),
		rgb(90, 200, 90),
		M.Fabric,
		Enum.PartType.Ball
	)
	label(bag, Enum.NormalId.Back, "$", rgb(255, 255, 255))
end

-- ===== zone themes =====
-- `at(lx, ly, depth)` places inside a zone: depth runs down the corridor (0 = the arch), lx across
-- (+ = right when walking in). The path is |lx| < 7, display stands at lx +-20 (depth 35/65/95),
-- the rich person at (36, 65). Props go on the side strips |lx| 30..46.
type At = (lx: number, ly: number, depth: number) -> CFrame

local F = 0.4 -- zone floor top
local FACE_RIGHT = CFrame.Angles(0, math.rad(-90), 0) -- a part's Front faces +lx (left wall)
local FACE_LEFT = CFrame.Angles(0, math.rad(90), 0) -- a part's Front faces -lx (right wall)

local THEMES: { [string]: (f: Instance, at: At, trim: Color3) -> () } = {
	Suburbs = function(f, at, _trim)
		-- villas: picket fences, mailboxes, a parked car, lawn trees, a doghouse by the crates
		for _, d in { 12, 34, 92, 114 } do
			for i = 0, 4 do
				part(
					f,
					"Picket",
					Vector3.new(0.4, 2.6, 0.8),
					at(-40, F + 1.3, d + i * 1.6),
					rgb(250, 250, 250)
				)
			end
			part(f, "PicketRail", Vector3.new(0.3, 0.4, 7.4), at(-40, F + 1.8, d + 3.2), rgb(250, 250, 250))
		end
		for _, d in { 24, 104 } do
			part(f, "MailPost", Vector3.new(0.4, 3, 0.4), at(-36, F + 1.5, d), rgb(110, 80, 50))
			part(f, "Mailbox", Vector3.new(1.2, 1, 1.8), at(-36, F + 3.3, d), rgb(40, 90, 200))
		end
		car(f, at(-38, F, 66), rgb(220, 60, 50))
		for _, spot in { { 42, 18 }, { 42, 104 }, { -44, 46 } } do
			part(f, "TreeTrunk", Vector3.new(1.4, 6, 1.4), at(spot[1], F + 3, spot[2]), rgb(120, 80, 45))
			part(f, "TreeTop", Vector3.new(6, 5, 6), at(spot[1], F + 8, spot[2]), rgb(60, 180, 70))
		end
		part(f, "Doghouse", Vector3.new(5, 4, 5), at(42, F + 2, 80), rgb(200, 60, 50))
		part(f, "DoghouseRoof", Vector3.new(5.6, 1, 5.6), at(42, F + 4.5, 80), rgb(120, 50, 40))
	end,
	PoolVillas = function(f, at, trim)
		-- a long pool on the left, loungers + parasols, palms, a diving board
		part(f, "PoolRim", Vector3.new(12, 0.8, 70), at(-38, F + 0.4, 62), rgb(245, 245, 250))
		local water = part(
			f,
			"PoolWater",
			Vector3.new(10.4, 0.9, 68),
			at(-38, F + 0.45, 62),
			rgb(60, 210, 230),
			M.Glass
		)
		water.Transparency = 0.2
		water.CanCollide = false
		light(water, rgb(80, 220, 255), 18, 0.8)
		part(f, "DivingBoard", Vector3.new(2, 0.4, 6), at(-38, F + 2, 24), rgb(250, 250, 250))
		for i = 0, 3 do
			local d = 14 + i * 9
			part(f, "Lounger", Vector3.new(3, 0.8, 6), at(40, F + 0.4, d), rgb(255, 255, 255))
			part(
				f,
				"LoungerBack",
				Vector3.new(3, 2.4, 0.8),
				at(40, F + 1.6, d - 2.8) * CFrame.Angles(math.rad(25), 0, 0),
				trim
			)
		end
		for _, d in { 96, 112 } do
			part(f, "ParasolPole", Vector3.new(0.3, 7, 0.3), at(40, F + 3.5, d), rgb(250, 250, 250))
			part(f, "Parasol", Vector3.new(7, 0.6, 7), at(40, F + 7, d), trim)
		end
		for _, d in { 104, 120 } do
			part(
				f,
				"PalmTrunk",
				Vector3.new(1.2, 10, 1.2),
				at(-44, F + 5, d) * CFrame.Angles(0, 0, 0.12),
				rgb(160, 120, 70)
			)
			part(f, "PalmLeaves", Vector3.new(8, 1.4, 8), at(-43, F + 10.5, d), rgb(60, 190, 80))
		end
	end,
	Mansion = function(f, at, _trim)
		-- grand hall: columns, gold chandeliers, statues, a red carpet runner, a piano
		for _, spot in { { -42, 15 }, { 42, 15 }, { -42, 115 }, { 42, 115 }, { -42, 65 }, { 42, 100 } } do
			column(f, at(spot[1], F, spot[2]), 16, rgb(235, 220, 190))
		end
		for _, d in { 35, 95 } do
			local chand = deco(
				f,
				"Chandelier",
				Vector3.new(5, 2, 5),
				at(0, 20, d),
				rgb(255, 210, 90),
				M.Neon,
				Enum.PartType.Ball
			)
			light(chand, rgb(255, 220, 150), 28, 1.6)
		end
		statue(f, at(-38, F, 40), 0.9)
		statue(f, at(-38, F, 90), 0.9)
		part(f, "Piano", Vector3.new(6, 3, 8), at(38, F + 1.5, 26), rgb(20, 20, 24))
		part(
			f,
			"PianoLid",
			Vector3.new(6, 0.3, 8),
			at(38, F + 4, 25) * CFrame.Angles(math.rad(-20), 0, 0),
			rgb(20, 20, 24)
		)
		frame(f, at(-46.6, 10, 25) * FACE_RIGHT, 8, 6, "🦁", rgb(60, 40, 30))
		frame(f, at(46.6, 10, 110) * FACE_LEFT, 8, 6, "👑", rgb(80, 20, 30))
	end,
	BankVault = function(f, at, trim)
		-- money carts, cash stacks, gold bar pallets, deposit-box walls, laser posts
		for i = 0, 5 do
			part(f, "DepositBoxes", Vector3.new(1.4, 10, 6), at(-45, F + 5, 14 + i * 7), rgb(170, 176, 186))
		end
		goldBars(f, at(-40, F, 70))
		goldBars(f, at(-40, F, 84))
		goldBars(f, at(40, F, 104))
		coinPile(f, at(-40, F, 110), 1.2)
		for _, d in { 18, 30 } do
			part(f, "MoneyCart", Vector3.new(4, 3, 6), at(40, F + 1.8, d), rgb(80, 86, 96))
			part(f, "CartCash", Vector3.new(3.4, 1, 5.4), at(40, F + 3.6, d), rgb(90, 200, 90))
		end
		for _, lx in { -30, 30 } do
			part(f, "LaserPost", Vector3.new(0.8, 6, 0.8), at(lx, F + 3, 120), rgb(40, 44, 52))
			local beam = deco(f, "LaserBeam", Vector3.new(0.15, 0.15, 10), at(lx, F + 4, 115), trim, M.Neon)
			beam.CastShadow = false
		end
	end,
	YachtHarbor = function(f, at, _trim)
		-- docks with a yacht and a speedboat on the water, life rings, rope posts, crates
		part(f, "YachtHull", Vector3.new(8, 4, 22), at(-38, F + 2, 30), rgb(250, 250, 255))
		part(f, "YachtStripe", Vector3.new(8.1, 0.7, 22.1), at(-38, F + 2.6, 30), rgb(30, 60, 140))
		part(f, "YachtCabin", Vector3.new(6, 3, 10), at(-38, F + 5.5, 32), rgb(150, 200, 230), M.Glass)
		part(f, "Boat", Vector3.new(5, 2, 10), at(-39, F + 1, 100), rgb(220, 60, 50))
		for _, d in { 16, 46, 96, 116 } do
			cyl(f, "DockPost", 4, 1, at(44, F + 2, d), rgb(120, 80, 50), M.Wood)
			part(
				f,
				"LifeRing",
				Vector3.new(0.6, 3, 3),
				at(46.4, 8, d),
				rgb(255, 80, 60),
				M.SmoothPlastic,
				Enum.PartType.Cylinder
			)
		end
		for i = 0, 2 do
			barrel(f, at(40, F, 104 + i * 3), rgb(130, 85, 50))
		end
	end,
	Casino = function(f, at, trim)
		-- slot machines along the left, card tables, a roulette table, velvet ropes
		for i = 0, 6 do
			local d = 12 + i * 6
			part(f, "SlotMachine", Vector3.new(3, 6, 3), at(-43, F + 3, d), rgb(200, 30, 40))
			local screen = part(
				f,
				"SlotScreen",
				Vector3.new(0.2, 2, 2.4),
				at(-41.4, F + 4, d),
				rgb(255, 230, 120),
				M.Neon
			)
			CollectionService:AddTag(screen, "Blink")
		end
		for i = 0, 2 do
			part(f, "SlotMachine", Vector3.new(3, 6, 3), at(-43, F + 3, 96 + i * 6), rgb(200, 30, 40))
		end
		part(f, "CardTable", Vector3.new(6, 2.6, 10), at(40, F + 1.3, 22), rgb(30, 120, 60))
		local roulette = part(
			f,
			"Roulette",
			Vector3.new(1, 6, 6),
			at(40, F + 3, 104) * CFrame.Angles(0, 0, math.rad(90)),
			rgb(30, 120, 60),
			M.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		CollectionService:AddTag(roulette, "Spin")
		for _, d in { 40, 88 } do
			local sign = part(f, "NeonSign", Vector3.new(0.4, 4, 12), at(-46.6, 18, d), trim, M.Neon)
			label(sign, Enum.NormalId.Right, "JACKPOT", rgb(255, 255, 255))
		end
	end,
	PrivateIsland = function(f, at, _trim)
		-- palms, a tiki bar, hammocks, gold statues, a helipad
		for _, spot in { { -42, 14 }, { -44, 40 }, { 42, 20 }, { -42, 92 }, { 44, 110 }, { -44, 118 } } do
			part(
				f,
				"PalmTrunk",
				Vector3.new(1.4, 12, 1.4),
				at(spot[1], F + 6, spot[2]) * CFrame.Angles(0, 0, 0.12),
				rgb(160, 120, 70)
			)
			part(
				f,
				"PalmLeaves",
				Vector3.new(9, 1.6, 9),
				at(spot[1] + 1, F + 12.5, spot[2]),
				rgb(60, 190, 80)
			)
		end
		part(f, "TikiBar", Vector3.new(5, 3.4, 10), at(-38, F + 1.7, 66), rgb(150, 100, 50))
		part(f, "TikiRoof", Vector3.new(7, 1, 12), at(-38, F + 7, 66), rgb(200, 180, 100))
		statue(f, at(40, F, 100), 1)
		chest(f, at(-40, F, 50))
		chest(f, at(-40, F, 56))
		local pad = part(f, "Helipad", Vector3.new(14, 0.2, 14), at(-34, F + 0.1, 104), rgb(60, 60, 66))
		label(pad, Enum.NormalId.Top, "H", rgb(255, 255, 255))
	end,
	SpaceVault = function(f, at, trim)
		-- a rocket on a launch pad, floating gold bars, moon rocks, glowing pillars
		part(f, "LaunchPad", Vector3.new(12, 1, 12), at(-38, F + 0.5, 30), rgb(70, 70, 80))
		cyl(f, "RocketBody", 18, 5, at(-38, F + 10, 30), rgb(235, 235, 245), M.SmoothPlastic)
		part(f, "RocketNose", Vector3.new(4, 4, 4), at(-38, F + 20.5, 30), rgb(220, 40, 50))
		for i = 0, 4 do
			local bar = deco(
				f,
				"FloatingGold",
				Vector3.new(3, 1, 1.4),
				at(-36 + (i % 2) * 4, 8 + i * 2.2, 96 + i * 3),
				rgb(255, 205, 50),
				M.SmoothPlastic
			)
			CollectionService:AddTag(bar, "Bob")
		end
		for _, spot in { { 42, 20 }, { 40, 110 }, { -42, 64 } } do
			part(
				f,
				"MoonRock",
				Vector3.new(4, 3, 4),
				at(spot[1], F + 1.5, spot[2]),
				rgb(150, 150, 160),
				M.SmoothPlastic,
				Enum.PartType.Ball
			)
		end
		for _, d in { 46, 82 } do
			local glow = part(f, "GlowPillar", Vector3.new(2, 20, 2), at(-45, 10, d), trim, M.Neon)
			light(glow, trim, 20, 1)
		end
	end,
}

function WorldDecor.zone(model: Model, id: string, origin: CFrame, trim: Color3)
	local f = Instance.new("Model")
	f.Name = "Decor"
	f.Parent = model
	local function at(lx: number, ly: number, depth: number): CFrame
		return origin * CFrame.new(lx, ly, -depth)
	end
	local theme = THEMES[id]
	if theme then
		theme(f, at, trim)
	end
end

-- ===== where the rich person sits (behind their crates, like the genre) =====
-- `cf`: on the floor, Front (-Z) facing the street. Decoration only (nothing to bump into).
function WorldDecor.station(model: Model, id: string, cf: CFrame)
	local f = Instance.new("Model")
	f.Name = "Station"
	f.Parent = model
	local function d(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?
	): Part
		return deco(f, name, size, cf * offset, color, material)
	end
	if id == "Suburbs" then
		-- a dog bed, a food bowl and a bone (the guard dog sleeps right here)
		d("DogBed", Vector3.new(6, 0.8, 5), CFrame.new(0, 0.4, 1.5), rgb(200, 60, 50))
		d("Bowl", Vector3.new(1.6, 0.6, 1.6), CFrame.new(3.5, 0.3, -1), rgb(60, 120, 220))
		d("Bone", Vector3.new(2, 0.5, 0.6), CFrame.new(-3, 0.3, -1), rgb(245, 240, 225))
	elseif id == "PoolVillas" then
		-- the butler's drinks trolley and a towel stack
		d("Trolley", Vector3.new(5, 3, 2.4), CFrame.new(0, 1.5, 1.5), rgb(220, 220, 230))
		for i = 0, 2 do
			d(
				"Glass",
				Vector3.new(0.5, 1, 0.5),
				CFrame.new(-1.5 + i * 1.5, 3.5, 1.5),
				rgb(200, 240, 255),
				M.Glass
			)
		end
		d("Towels", Vector3.new(2, 1.6, 2), CFrame.new(3.6, 0.8, 2), rgb(40, 200, 210))
	elseif id == "Mansion" then
		-- the security desk with monitors
		d("Desk", Vector3.new(8, 3, 3), CFrame.new(0, 1.5, 1.5), rgb(110, 75, 45))
		for _, x in { -2, 2 } do
			d("Monitor", Vector3.new(2.6, 1.8, 0.3), CFrame.new(x, 4, 2.6), rgb(120, 220, 255), M.Neon)
		end
		d("Chair", Vector3.new(2.6, 4, 2.6), CFrame.new(0, 2, 4.8), rgb(30, 30, 36))
	elseif id == "BankVault" then
		-- the robot's charging dock
		d("Dock", Vector3.new(6, 1, 6), CFrame.new(0, 0.5, 1.5), rgb(80, 86, 96))
		d("Charger", Vector3.new(1.4, 6, 1.4), CFrame.new(0, 3.5, 4), rgb(70, 255, 120), M.Neon)
	elseif id == "YachtHarbor" then
		-- the captain's ship wheel on a stand and a lantern
		local wheel = d("Wheel", Vector3.new(0.6, 4, 4), CFrame.new(0, 4, 2), rgb(150, 100, 50))
		wheel.Shape = Enum.PartType.Cylinder
		d("WheelStand", Vector3.new(1, 3, 1), CFrame.new(0, 1.5, 2), rgb(110, 75, 45))
		d("Lantern", Vector3.new(0.9, 1.2, 0.9), CFrame.new(3, 1, 1), rgb(255, 210, 90), M.Neon)
	elseif id == "Casino" then
		-- the croupier's card table
		d("Table", Vector3.new(8, 3, 4), CFrame.new(0, 1.5, 1.5), rgb(30, 120, 60))
		d("TableRim", Vector3.new(8.4, 0.3, 4.4), CFrame.new(0, 3.1, 1.5), rgb(110, 60, 30))
		for i = 0, 3 do
			d(
				"Chips",
				Vector3.new(0.7, 0.4 + i * 0.3, 0.7),
				CFrame.new(-2.4 + i * 1.6, 3.4 + i * 0.15, 1.2),
				rgb(220, 40, 50)
			)
		end
	elseif id == "PrivateIsland" then
		-- the billionaire's golden throne on a stack of gold bars
		goldBars(f, cf * CFrame.new(0, 0, 2))
		d("Throne", Vector3.new(4, 7, 2), CFrame.new(0, 3.5, 4), rgb(255, 200, 40))
		d("Seat", Vector3.new(4, 1, 3), CFrame.new(0, 2, 2.5), rgb(200, 30, 40))
	else
		-- the A.I.'s server core
		d("Core", Vector3.new(4, 8, 4), CFrame.new(0, 4, 3), rgb(40, 30, 70))
		d("CoreGlow", Vector3.new(3, 0.6, 0.2), CFrame.new(0, 6, 0.9), rgb(255, 80, 230), M.Neon)
	end
	for _, p in f:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
		end
	end
end

-- ===== little things lying around the street (bones, cash, coins, gifts...) =====
local SCATTER: { [string]: { { size: Vector3, color: Color3, material: Enum.Material? } } } = {
	Suburbs = {
		{ size = Vector3.new(1, 1.4, 1), color = rgb(255, 120, 180) },
		{ size = Vector3.new(1, 1.4, 1), color = rgb(255, 230, 80) },
		{ size = Vector3.new(2, 0.5, 0.6), color = rgb(245, 240, 225) },
	},
	PoolVillas = {
		{ size = Vector3.new(1.6, 1.6, 1.6), color = rgb(255, 120, 120) },
		{ size = Vector3.new(2.4, 0.3, 1.4), color = rgb(40, 200, 210) },
	},
	Mansion = {
		{ size = Vector3.new(1.2, 1.8, 1.2), color = rgb(60, 160, 70) },
		{ size = Vector3.new(0.6, 1.6, 0.6), color = rgb(255, 210, 90) },
	},
	BankVault = {
		{ size = Vector3.new(1.4, 0.5, 0.8), color = rgb(90, 200, 90) },
		{ size = Vector3.new(1.6, 0.6, 0.8), color = rgb(255, 200, 40) },
		{ size = Vector3.new(1.2, 1.2, 1.2), color = rgb(200, 160, 80) },
	},
	YachtHarbor = {
		{ size = Vector3.new(1.4, 0.4, 1.4), color = rgb(255, 140, 60) },
		{ size = Vector3.new(2, 1.4, 2), color = rgb(150, 100, 60) },
	},
	Casino = {
		{ size = Vector3.new(0.8, 0.3, 0.8), color = rgb(220, 40, 50) },
		{ size = Vector3.new(0.8, 0.3, 0.8), color = rgb(30, 30, 36) },
		{ size = Vector3.new(1, 1, 1), color = rgb(255, 255, 255) },
	},
	PrivateIsland = {
		{ size = Vector3.new(1.2, 1.2, 1.2), color = rgb(160, 110, 60) },
		{ size = Vector3.new(1.4, 0.3, 1.4), color = rgb(255, 140, 60) },
		{ size = Vector3.new(1.2, 0.3, 1.2), color = rgb(255, 200, 40) },
	},
	SpaceVault = {
		{ size = Vector3.new(1.6, 1.2, 1.6), color = rgb(150, 150, 160) },
		{ size = Vector3.new(0.8, 0.8, 0.8), color = rgb(190, 110, 255), material = M.Neon },
	},
}

-- Scatters small props over the street, off the running path and away from the crate pile.
function WorldDecor.scatter(model: Model, id: string, origin: CFrame, seed: number)
	local kinds = SCATTER[id]
	if not kinds then
		return
	end
	local f = Instance.new("Model")
	f.Name = "Scatter"
	f.Parent = model
	local rng = Random.new(seed * 131)
	local L, HW = World.VaultSpacing, World.ZoneHalfWidth
	local placed = 0
	for _ = 1, 60 do
		if placed >= 16 then
			break
		end
		local lx = (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(11, HW - 6)
		local depth = rng:NextNumber(6, L - 6)
		local inPile = lx > 10 and lx < 44 and depth > 36 and depth < 80
		if not inPile then
			local k = kinds[rng:NextInteger(1, #kinds)]
			deco(
				f,
				"Bit",
				k.size,
				origin
					* CFrame.new(lx, F + k.size.Y / 2, -depth)
					* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				k.color,
				k.material
			)
			placed += 1
		end
	end
end

-- ===== bases =====
-- A doormat and a glowing ring under each pedestal (the palace itself is built in WorldBuilder).
-- `floorTop`: the top of the stage the pedestals stand on.
function WorldDecor.base(
	model: Model,
	origin: CFrame,
	color: Color3,
	pedestals: { BasePart },
	floorTop: number
): { BasePart }
	local function at(lx: number, ly: number, depth: number): CFrame
		return origin * CFrame.new(lx, ly, -depth)
	end
	deco(
		model,
		"Doormat",
		Vector3.new(World.EntranceWidth - 2, 0.1, 4),
		at(0, 0.35, -3),
		color:Lerp(rgb(255, 255, 255), 0.3),
		M.Fabric
	)
	local rings: { BasePart } = {}
	for _, ped in pedestals do
		local ring = deco(
			model,
			"PedRing",
			Vector3.new(0.12, 6.6, 6.6),
			CFrame.new(ped.Position.X, floorTop + 0.07, ped.Position.Z) * CFrame.Angles(0, 0, math.rad(90)),
			color,
			M.Neon,
			Enum.PartType.Cylinder
		)
		ring.Transparency = 1
		table.insert(rings, ring)
	end
	return rings
end

-- ===== plaza =====
function WorldDecor.fountain(parent: Instance, pos: Vector3)
	local f = Instance.new("Model")
	f.Name = "Fountain"
	f.Parent = parent
	local base = CFrame.new(pos)
	cyl(f, "Basin", 1.6, 16, base * CFrame.new(0, 0.8, 0), rgb(235, 230, 220), M.Marble)
	local water = cyl(f, "Water", 0.4, 14.6, base * CFrame.new(0, 1.5, 0), rgb(60, 180, 255), M.Glass)
	water.Transparency = 0.2
	water.CanCollide = false
	cyl(f, "Pillar", 5, 2, base * CFrame.new(0, 3.5, 0), rgb(235, 230, 220), M.Marble)
	cyl(f, "Bowl", 0.8, 6, base * CFrame.new(0, 6, 0), rgb(235, 230, 220), M.Marble)
	local spout = deco(
		f,
		"Spout",
		Vector3.new(1, 1, 1),
		base * CFrame.new(0, 6.8, 0),
		rgb(150, 220, 255),
		M.Glass,
		Enum.PartType.Ball
	)
	local p = Instance.new("ParticleEmitter")
	p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	p.Color = ColorSequence.new(rgb(170, 225, 255))
	p.Size = NumberSequence.new(0.6, 0.2)
	p.Lifetime = NumberRange.new(1, 1.4)
	p.Speed = NumberRange.new(10, 13)
	p.SpreadAngle = Vector2.new(18, 18)
	p.Acceleration = Vector3.new(0, -22, 0)
	p.Rate = 40
	p.EmissionDirection = Enum.NormalId.Top
	p.Parent = spout
	light(water, rgb(80, 190, 255), 18, 1)
end

-- ===== the island around the map =====
-- A sand beach around the grass, a terrain ocean with waves, and a ring of green mountains out in
-- the water so the horizon never just ends. `cx`/`w`/`d`: the grass rectangle (center x, size).
function WorldDecor.surroundings(parent: Instance, cx: number, w: number, d: number, beach: number)
	local f = Instance.new("Folder")
	f.Name = "Surroundings"
	f.Parent = parent

	-- beach: peeks out between the grass (top 0) and the water surface (-1)
	local sand = part(
		f,
		"Beach",
		Vector3.new(w + beach * 2, 3, d + beach * 2),
		CFrame.new(cx, -1.9, 0),
		rgb(240, 222, 165),
		M.Sand
	)
	sand.TopSurface = Enum.SurfaceType.Smooth

	-- ocean (terrain water: waves, reflections, cheap for its size)
	local terrain = workspace.Terrain
	terrain.WaterColor = rgb(40, 165, 215)
	terrain.WaterTransparency = 0.35
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
	local SEA = 700 -- water reaches past the mountain ring
	pcall(function()
		terrain:FillBlock(
			CFrame.new(cx, -5, 0),
			Vector3.new(w + SEA * 2, 8, d + SEA * 2),
			Enum.Material.Water
		)
	end)

	-- mountain ring out in the sea (big soft hills, partly under water)
	local rng = Random.new(2877)
	local rx, rz = w / 2 + 330, d / 2 + 330 -- ring "radius" around the island
	local perimeter = 2 * math.pi * math.sqrt((rx * rx + rz * rz) / 2)
	local count = math.floor(perimeter / 170)
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + rng:NextNumber(-0.04, 0.04)
		local wobble = rng:NextNumber(-60, 60)
		local pos = Vector3.new(cx + math.cos(a) * (rx + wobble), 0, math.sin(a) * (rz + wobble))
		local width = rng:NextNumber(240, 380)
		local height = rng:NextNumber(110, 230)
		local hill = deco(
			f,
			"Mountain",
			Vector3.new(width, height, width * rng:NextNumber(0.8, 1.2)),
			CFrame.new(pos + Vector3.new(0, -height * 0.18, 0))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			rgb(80 + rng:NextInteger(-10, 10), 170 + rng:NextInteger(-15, 15), 70),
			M.Grass,
			Enum.PartType.Ball
		)
		hill.CastShadow = false
		-- a rocky top on the tallest ones
		if height > 190 then
			deco(
				f,
				"Peak",
				Vector3.new(width * 0.35, height * 0.3, width * 0.35),
				CFrame.new(pos + Vector3.new(0, height * 0.28, 0)),
				rgb(150, 150, 160),
				M.Rock,
				Enum.PartType.Ball
			).CastShadow =
				false
		end
	end
	-- a few palm islets closer in, for life on the water
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2 + 0.3
		local pos = Vector3.new(cx + math.cos(a) * (w / 2 + 120), 0, math.sin(a) * (d / 2 + 110))
		deco(
			f,
			"Islet",
			Vector3.new(40, 10, 34),
			CFrame.new(pos + Vector3.new(0, -3.5, 0)),
			rgb(240, 222, 165),
			M.Sand,
			Enum.PartType.Ball
		)
		deco(
			f,
			"IsletTrunk",
			Vector3.new(1.4, 12, 1.4),
			CFrame.new(pos + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, 0.15),
			rgb(150, 110, 70),
			M.Wood
		)
		deco(
			f,
			"IsletLeaves",
			Vector3.new(12, 3, 12),
			CFrame.new(pos + Vector3.new(1, 13.5, 0)),
			rgb(60, 170, 70),
			M.Grass,
			Enum.PartType.Ball
		)
	end
	return f
end

-- "SAFE ZONE" painted on the floor just inside a base entrance (reads walking in).
function WorldDecor.safeZone(model: Model, origin: CFrame, floorTop: number)
	local p = deco(
		model,
		"SafeZone",
		Vector3.new(World.EntranceWidth - 2, 0.05, 5),
		origin * CFrame.new(0, floorTop + 0.35, -3.5), -- just above the path tiles
		rgb(255, 255, 255),
		M.SmoothPlastic
	)
	p.Transparency = 1
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Top
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = "SAFE ZONE"
	l.TextColor3 = rgb(120, 255, 140)
	l.TextTransparency = 0.1
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Color = rgb(10, 60, 20)
	st.Parent = l
	l.Parent = sg
end

-- A neon booth on the plaza; its prompt opens the trails menu.
-- `base`: ground center, front (-Z) facing the customers.
function WorldDecor.trailsShop(parent: Instance, base: CFrame): ProximityPrompt
	local f = Instance.new("Model")
	f.Name = "TrailsShop"
	f.Parent = parent
	part(
		f,
		"Counter",
		Vector3.new(12, 3.5, 4),
		base * CFrame.new(0, 1.75, 0),
		rgb(60, 30, 90),
		M.SmoothPlastic
	)
	part(
		f,
		"CounterTop",
		Vector3.new(12.6, 0.5, 4.6),
		base * CFrame.new(0, 3.75, 0),
		rgb(255, 120, 255),
		M.Neon
	)
	for _, x in { -5.5, 5.5 } do
		part(f, "Post", Vector3.new(0.8, 10, 0.8), base * CFrame.new(x, 5, 1.6), rgb(40, 20, 60), M.Metal)
	end
	local sign = part(
		f,
		"Sign",
		Vector3.new(13, 3.4, 0.6),
		base * CFrame.new(0, 10.5, 1.6),
		rgb(30, 15, 45),
		M.SmoothPlastic
	)
	label(sign, Enum.NormalId.Front, "🌈 TRAILS SHOP", rgb(255, 150, 255))
	label(sign, Enum.NormalId.Back, "🌈 TRAILS SHOP", rgb(255, 150, 255))
	local awning = part(
		f,
		"Awning",
		Vector3.new(13, 0.5, 6),
		base * CFrame.new(0, 8.6, -0.6) * CFrame.Angles(math.rad(-10), 0, 0),
		rgb(255, 90, 200),
		M.Fabric
	)
	light(awning, rgb(255, 140, 255), 18, 1.5)
	for i = 0, 2 do
		local orb = deco(
			f,
			"Orb",
			Vector3.new(1.2, 1.2, 1.2),
			base * CFrame.new(-3 + i * 3, 4.8, 0),
			Color3.fromHSV(i / 3, 0.7, 1),
			M.Neon,
			Enum.PartType.Ball
		)
		CollectionService:AddTag(orb, "Bob")
	end
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Trails"
	pp.ObjectText = "Glow while you run"
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 14
	pp.RequiresLineOfSight = false
	pp.Parent = f:FindFirstChild("Counter") :: BasePart
	return pp
end

-- ===== Halloween =====
local function pumpkin(parent: Instance, cf: CFrame, scale: number)
	-- decoration only: you run straight through pumpkins
	local body = deco(
		parent,
		"Pumpkin",
		Vector3.new(3.2, 2.6, 3.2) * scale,
		cf * CFrame.new(0, 1.3 * scale, 0),
		rgb(255, 120, 20),
		M.SmoothPlastic,
		Enum.PartType.Ball
	)
	deco(
		parent,
		"Stem",
		Vector3.new(0.4, 0.8, 0.4) * scale,
		cf * CFrame.new(0, 2.8 * scale, 0),
		rgb(70, 120, 40),
		M.Wood
	)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Parent = body
	local face = Instance.new("TextLabel")
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundTransparency = 1
	face.Font = Enum.Font.GothamBlack
	face.TextScaled = true
	face.Text = "▲ ▲\n◡◡◡"
	face.TextColor3 = rgb(255, 230, 90)
	face.Parent = sg
	light(body, rgb(255, 150, 40), 9, 1)
end

local function floatingEmoji(parent: Instance, pos: Vector3, emoji: string, size: number)
	local anchor =
		deco(parent, "Spooky", Vector3.new(1, 1, 1), CFrame.new(pos), rgb(0, 0, 0), M.SmoothPlastic)
	anchor.Transparency = 1
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(size, size)
	bb.MaxDistance = 260
	bb.LightInfluence = 0
	bb.Parent = anchor
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.Font = Enum.Font.GothamBold
	l.Text = emoji
	l.Parent = bb
	CollectionService:AddTag(anchor, "Bob")
end

-- Pumpkins at every entrance, cobwebs on the base towers, bats over the skyline and ghosts on
-- Rich Street. `bases`/`vaults` are the WorldBuilder records.
function WorldDecor.halloween(parent: Instance, bases: { any }, vaults: { any }, streetEnd: number)
	local f = Instance.new("Folder")
	f.Name = "Halloween"
	f.Parent = parent
	for _, b in bases do
		local o: CFrame = b.origin
		for _, lx in { -12, 12 } do
			-- facing out of the base (Back face = toward the plaza)
			pumpkin(f, o * CFrame.new(lx, 0.3, 3), 1)
		end
		for _, lx in { -World.BaseWidth / 2, World.BaseWidth / 2 } do
			floatingEmoji(f, (o * CFrame.new(lx, World.WallHeight + 7, 0)).Position, "🕸️", 5)
		end
	end
	for _, v in vaults do
		local o: CFrame = v.origin
		for _, lx in { -30, 30 } do
			-- just inside each zone's arch, beside the path
			pumpkin(f, o * CFrame.new(lx, 0.4, -6), 1.3)
		end
	end
	local rng = Random.new(31)
	for x = World.StreetStartX + 40, streetEnd, 70 do
		floatingEmoji(
			f,
			Vector3.new(
				x,
				rng:NextNumber(60, 110),
				(if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(110, 150)
			),
			"🦇",
			9
		)
		floatingEmoji(
			f,
			Vector3.new(
				x + 35,
				rng:NextNumber(14, 22),
				(if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(26, 30)
			),
			"👻",
			6
		)
	end
	for z = -300, 300, 75 do
		pumpkin(f, CFrame.new(-90, 0.3, z), 0.9) -- across the plaza, between the treadmills and the shops
	end
end

return WorldDecor
