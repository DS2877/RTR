--!strict
-- Set dressing built from parts: a unique theme inside every vault, the city skyline behind
-- Rich Street, sidewalks, fountains, base towers and the express lanes. Pure decoration except the
-- lanes (moving walkways) and pedestal rings; nothing here touches the economy.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)

local WorldDecor = {}

local M = Enum.Material

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

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
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
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
	part(parent, "Lock", Vector3.new(0.6, 0.8, 0.2), cf * CFrame.new(0, 2.3, -1.4), rgb(255, 200, 40), M.Foil)
	local gold = deco(
		parent,
		"Gold",
		Vector3.new(3.4, 0.6, 2.2),
		cf * CFrame.new(0, 3.3, 0.2),
		rgb(255, 205, 40),
		M.Foil
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
			M.Foil
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
				M.Foil
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

local function ringLight(parent: Instance, cf: CFrame)
	cyl(parent, "Stand", 6, 0.3, cf * CFrame.new(0, 3, 0), rgb(40, 40, 45), M.Metal)
	local ring = part(
		parent,
		"Ring",
		Vector3.new(0.4, 3.2, 3.2),
		cf * CFrame.new(0, 7, 0) * CFrame.Angles(0, math.rad(90), 0),
		rgb(255, 250, 235),
		M.Neon,
		Enum.PartType.Cylinder
	)
	light(ring, rgb(255, 240, 230), 14, 1.5)
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
	part(parent, "Frame", Vector3.new(w + 0.6, h + 0.6, 0.3), cf, rgb(190, 140, 40), M.Foil)
	local canvas = part(parent, "Canvas", Vector3.new(w, h, 0.35), cf, bg, M.SmoothPlastic)
	label(canvas, Enum.NormalId.Front, art, rgb(255, 255, 255), Enum.Font.GothamBold)
end

local function rocket(parent: Instance, cf: CFrame)
	cyl(parent, "RocketBody", 14, 4, cf * CFrame.new(0, 8, 0), rgb(235, 235, 245), M.Metal)
	part(
		parent,
		"RocketNose",
		Vector3.new(4, 4, 4),
		cf * CFrame.new(0, 17, 0),
		rgb(230, 40, 50),
		M.SmoothPlastic,
		Enum.PartType.Ball
	)
	for i = 0, 2 do
		local a = math.rad(i * 120)
		part(
			parent,
			"Fin",
			Vector3.new(0.4, 4, 3),
			cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 2.5, 2.5),
			rgb(230, 40, 50),
			M.SmoothPlastic
		)
	end
	local flame = deco(
		parent,
		"Flame",
		Vector3.new(2.6, 2.6, 2.6),
		cf * CFrame.new(0, 0.6, 0),
		rgb(255, 140, 40),
		M.Neon,
		Enum.PartType.Ball
	)
	light(flame, rgb(255, 150, 60), 14, 2)
end

local function serverRack(parent: Instance, cf: CFrame)
	part(parent, "Rack", Vector3.new(3, 8, 3), cf * CFrame.new(0, 4, 0), rgb(30, 32, 40), M.Metal)
	for i = 0, 5 do
		local led = part(
			parent,
			"Led",
			Vector3.new(2.4, 0.2, 0.1),
			cf * CFrame.new(0, 1.2 + i * 1.1, -1.55),
			if i % 2 == 0 then rgb(0, 220, 255) else rgb(80, 255, 140),
			M.Neon
		)
		CollectionService:AddTag(led, "Blink")
	end
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
	part(parent, "Legs", Vector3.new(2, 3, 1) * scale, cf * CFrame.new(0, 4.5 * scale, 0), gold, M.Foil)
	part(parent, "Body", Vector3.new(2.6, 3, 1.4) * scale, cf * CFrame.new(0, 7.5 * scale, 0), gold, M.Foil)
	part(parent, "Head", Vector3.new(1.6, 1.6, 1.6) * scale, cf * CFrame.new(0, 9.8 * scale, 0), gold, M.Foil)
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
		M.Foil
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
	Grandpa = function(f, at, _trim)
		car(f, at(-38, F, 50), rgb(90, 140, 200))
		car(f, at(38, F, 108), rgb(200, 60, 50))
		part(f, "Pegboard", Vector3.new(0.4, 8, 18), at(-46.6, 7, 100), rgb(170, 130, 90), M.WoodPlanks)
		for i = 0, 4 do
			part(f, "Tool", Vector3.new(0.3, 3, 0.4), at(-46.2, 7, 93 + i * 3.4), rgb(150, 150, 160), M.Metal)
		end
		for i = 0, 2 do
			barrel(f, at(-40, F, 14 + i * 3), rgb(200, 60, 40))
		end
		part(f, "Workbench", Vector3.new(6, 3, 14), at(40, F + 1.5, 30), rgb(120, 80, 50), M.Wood)
		part(
			f,
			"Tire",
			Vector3.new(1.2, 3, 3),
			at(-40, F + 1.5, 122),
			rgb(25, 25, 28),
			M.Rubber,
			Enum.PartType.Cylinder
		)
	end,
	Influencer = function(f, at, trim)
		part(f, "Couch", Vector3.new(6, 2, 16), at(-40, F + 1, 45), rgb(255, 120, 190), M.Fabric)
		part(f, "CouchBack", Vector3.new(1.5, 3, 16), at(-43.5, F + 2.6, 45), rgb(255, 100, 180), M.Fabric)
		ringLight(f, at(-38, F, 20))
		ringLight(f, at(40, F, 30))
		ringLight(f, at(-38, F, 112))
		local sign = part(f, "NeonSign", Vector3.new(0.4, 5, 24), at(-46.6, 9, 80), trim, M.Neon)
		label(sign, Enum.NormalId.Right, "❤ LIKE & SUBSCRIBE ❤", rgb(255, 255, 255))
		for i = 0, 5 do
			local b = deco(
				f,
				"Balloon",
				Vector3.new(2, 2.4, 2),
				at(38 + (i % 3) * 2.2, 10 + (i // 3) * 2, 100 + (i % 2)),
				if i % 2 == 0 then rgb(255, 120, 200) else rgb(140, 220, 255),
				M.SmoothPlastic,
				Enum.PartType.Ball
			)
			CollectionService:AddTag(b, "Bob")
		end
		part(f, "Tripod", Vector3.new(0.4, 5, 0.4), at(38, F + 2.5, 116), rgb(40, 40, 45), M.Metal)
		part(f, "Camera", Vector3.new(1.6, 1.2, 2.2), at(38, F + 5.4, 116), rgb(30, 30, 35), M.Metal)
	end,
	Pirate = function(f, at, _trim)
		cyl(f, "Mast", 26, 1.4, at(-38, 13.4, 100), rgb(110, 75, 45), M.Wood)
		part(f, "Yard", Vector3.new(1, 1, 16), at(-38, 22, 100), rgb(110, 75, 45), M.Wood)
		local sail =
			deco(f, "Sail", Vector3.new(0.3, 10, 14), at(-37.4, 16.5, 100), rgb(240, 235, 220), M.Fabric)
		label(sail, Enum.NormalId.Right, "☠", rgb(30, 30, 35))
		label(sail, Enum.NormalId.Left, "☠", rgb(30, 30, 35))
		deco(f, "Flag", Vector3.new(0.2, 2, 3.4), at(-38, 27.5, 101.7), rgb(20, 20, 25), M.Fabric)
		chest(f, at(40, F, 20))
		chest(f, at(40, F, 40))
		chest(f, at(-40, F, 50))
		for _, spot in { { -40, 22 }, { 40, 112 } } do
			local dir = if spot[1] < 0 then 1 else -1
			part(
				f,
				"Cannon",
				Vector3.new(5, 1.8, 1.8),
				at(spot[1], F + 1.9, spot[2]) * CFrame.Angles(0, 0, math.rad(dir * 12)),
				rgb(35, 35, 40),
				M.Metal,
				Enum.PartType.Cylinder
			)
			part(
				f,
				"CannonCart",
				Vector3.new(3, 1.2, 2.4),
				at(spot[1], F + 0.6, spot[2]),
				rgb(110, 70, 40),
				M.Wood
			)
		end
		for i = 0, 2 do
			barrel(f, at(-40, F, 116 + i * 3), rgb(130, 85, 50))
		end
	end,
	Museum = function(f, at, _trim)
		for _, spot in { { -42, 15 }, { 42, 15 }, { -42, 115 }, { 42, 115 }, { 42, 45 }, { 42, 85 } } do
			column(f, at(spot[1], F, spot[2]), 16, rgb(235, 230, 215))
		end
		-- dino skeleton on the left, roped off
		local bone = rgb(240, 232, 210)
		part(f, "Spine", Vector3.new(1.2, 1.2, 20), at(-38, 9, 65), bone, M.Marble)
		part(
			f,
			"Skull",
			Vector3.new(2.4, 3, 4),
			at(-38, 11, 53) * CFrame.Angles(math.rad(15), 0, 0),
			bone,
			M.Marble
		)
		part(
			f,
			"Tail",
			Vector3.new(0.8, 0.8, 8),
			at(-38, 7.5, 78) * CFrame.Angles(math.rad(20), 0, 0),
			bone,
			M.Marble
		)
		for i = 0, 5 do
			part(f, "Rib", Vector3.new(0.5, 4, 0.5), at(-38, 7, 59 + i * 2.4), bone, M.Marble)
		end
		for _, d in { 59, 70 } do
			part(f, "Leg", Vector3.new(1, 8.6, 1), at(-38, 4.7, d), bone, M.Marble)
		end
		for i = 0, 3 do
			cyl(f, "Stanchion", 3, 0.5, at(-31, F + 1.5, 56 + i * 6), rgb(255, 200, 40), M.Foil)
		end
		deco(f, "Rope", Vector3.new(0.3, 0.3, 18), at(-31, 3, 65), rgb(180, 20, 40), M.Fabric)
		frame(f, at(-46.6, 9, 30) * FACE_RIGHT, 8, 6, "🦙", rgb(60, 110, 70))
		frame(f, at(-46.6, 9, 100) * FACE_RIGHT, 8, 6, "🌻", rgb(60, 70, 130))
		frame(f, at(46.6, 9, 105) * FACE_LEFT, 8, 6, "🏛️", rgb(120, 60, 60))
	end,
	GoldTycoon = function(f, at, _trim)
		coinPile(f, at(-40, F, 15), 1.4)
		coinPile(f, at(40, F, 20), 1.3)
		coinPile(f, at(-40, F, 115), 1.6)
		coinPile(f, at(40, F, 118), 1.2)
		goldBars(f, at(-40, F, 45))
		goldBars(f, at(40, F, 40))
		goldBars(f, at(-40, F, 85))
		statue(f, at(40, F, 95), 1)
		for _, d in { 62, 70 } do
			local bag = part(
				f,
				"MoneyBag",
				Vector3.new(3, 3, 3),
				at(-42, F + 1.5, d),
				rgb(90, 200, 90),
				M.Fabric,
				Enum.PartType.Ball
			)
			label(bag, Enum.NormalId.Right, "$", rgb(255, 255, 255))
		end
	end,
	Yacht = function(f, at, _trim)
		part(f, "PoolRim", Vector3.new(10, 1, 30), at(-39, F + 0.5, 50), rgb(240, 240, 250), M.Marble)
		local water =
			part(f, "Water", Vector3.new(8.4, 1.1, 28.4), at(-39, F + 0.55, 50), rgb(40, 170, 255), M.Glass)
		water.Transparency = 0.25
		water.CanCollide = false
		light(water, rgb(80, 200, 255), 16, 1)
		for i = 0, 2 do
			part(
				f,
				"DeckChair",
				Vector3.new(3, 1, 6),
				at(40, F + 0.5, 20 + i * 9),
				rgb(255, 255, 255),
				M.Fabric
			)
			part(
				f,
				"ChairBack",
				Vector3.new(3, 3, 1),
				at(40, F + 1.8, 17.2 + i * 9) * CFrame.Angles(math.rad(25), 0, 0),
				rgb(30, 60, 140),
				M.Fabric
			)
		end
		part(f, "BoatHull", Vector3.new(6, 3, 14), at(-39, F + 1.5, 105), rgb(250, 250, 255), M.SmoothPlastic)
		part(
			f,
			"BoatStripe",
			Vector3.new(6.1, 0.6, 14.1),
			at(-39, F + 1.9, 105),
			rgb(30, 60, 140),
			M.SmoothPlastic
		)
		part(f, "BoatCabin", Vector3.new(4, 2, 5), at(-39, F + 4, 106), rgb(150, 200, 230), M.Glass)
		for _, spot in { { -46.6, 22 }, { 46.6, 112 } } do
			part(
				f,
				"LifeRing",
				Vector3.new(0.6, 3, 3),
				at(spot[1], 7, spot[2]),
				rgb(255, 80, 60),
				M.SmoothPlastic,
				Enum.PartType.Cylinder
			)
		end
	end,
	TechBillionaire = function(f, at, trim)
		for i = 0, 4 do
			serverRack(f, at(-42, F, 14 + i * 4) * FACE_RIGHT)
			serverRack(f, at(-42, F, 96 + i * 4) * FACE_RIGHT)
		end
		rocket(f, at(40, F, 105))
		local holo = part(f, "Hologram", Vector3.new(0.3, 7, 24), at(-46.6, 11, 65), trim, M.Neon)
		holo.Transparency = 0.35
		label(holo, Enum.NormalId.Right, "🚀 TO MARS 🚀", rgb(255, 255, 255))
		part(f, "Desk", Vector3.new(4, 3, 10), at(40, F + 1.5, 30), rgb(240, 240, 250), M.SmoothPlastic)
		local screen = part(f, "Screen", Vector3.new(0.3, 3, 6), at(38.2, 5, 30), rgb(0, 200, 255), M.Neon)
		CollectionService:AddTag(screen, "Blink")
	end,
	Billionaire = function(f, at, trim)
		statue(f, at(-38, F, 65), 1.25)
		coinPile(f, at(-40, F, 15), 1.5)
		coinPile(f, at(40, F, 15), 1.5)
		goldBars(f, at(-40, F, 40))
		goldBars(f, at(40, F, 40))
		car(f, at(-38, F, 105), rgb(255, 200, 40))
		local chand =
			deco(f, "Chandelier", Vector3.new(6, 2, 6), at(0, 18, 65), trim, M.Neon, Enum.PartType.Ball)
		light(chand, rgb(255, 220, 140), 30, 2)
		local diamond = deco(
			f,
			"Diamond",
			Vector3.new(3, 3, 3),
			at(40, 6, 108) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			rgb(170, 240, 255),
			M.Glass
		)
		diamond.Reflectance = 0.4
		CollectionService:AddTag(diamond, "Spin")
		part(f, "DiamondStand", Vector3.new(3, 3, 3), at(40, F + 1.5, 108), rgb(30, 25, 35), M.Marble)
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

-- ===== the rich person =====
-- A big blocky character on a plinth, in the zone's style, with their name over the head.
-- `cf`: feet on the floor, Front (-Z) facing the path.
local NPC_STYLE: { [string]: { suit: Color3, hat: string, face: string } } = {
	Grandpa = { suit = rgb(130, 95, 70), hat = "cap", face = "👴" },
	Influencer = { suit = rgb(255, 120, 190), hat = "none", face = "😎" },
	Pirate = { suit = rgb(140, 30, 35), hat = "tricorn", face = "🏴‍☠️" },
	Museum = { suit = rgb(70, 55, 40), hat = "top", face = "🧐" },
	GoldTycoon = { suit = rgb(255, 200, 40), hat = "top", face = "🤑" },
	Yacht = { suit = rgb(250, 250, 255), hat = "captain", face = "😏" },
	TechBillionaire = { suit = rgb(40, 40, 50), hat = "none", face = "🤓" },
	Billionaire = { suit = rgb(20, 20, 25), hat = "top", face = "🧐" },
}

function WorldDecor.richNPC(model: Model, def: any, cf: CFrame)
	local style = NPC_STYLE[def.id] or { suit = rgb(40, 40, 50), hat = "top", face = "🤑" }
	local f = Instance.new("Model")
	f.Name = "RichPerson"
	f.Parent = model
	local S = 2.2
	local skin = rgb(255, 205, 160)
	local trim = rgb(def.trim[1], def.trim[2], def.trim[3])
	part(f, "Plinth", Vector3.new(8, 1, 8), cf * CFrame.new(0, 0.5, 0), trim, M.Marble)
	local y0 = 1
	for _, x in { -0.5, 0.5 } do
		part(f, "Leg", Vector3.new(1, 2, 1) * S, cf * CFrame.new(x * S, y0 + 1 * S, 0), rgb(30, 30, 40))
	end
	local torso = part(f, "Torso", Vector3.new(2, 2, 1) * S, cf * CFrame.new(0, y0 + 3 * S, 0), style.suit)
	for _, x in { -1.5, 1.5 } do
		part(f, "Arm", Vector3.new(1, 2, 1) * S, cf * CFrame.new(x * S, y0 + 3 * S, 0), style.suit)
	end
	part(f, "Tie", Vector3.new(0.35, 1.5, 0.1) * S, cf * CFrame.new(0, y0 + 3.2 * S, -0.52 * S), trim)
	if def.id == "GoldTycoon" or def.id == "Billionaire" then
		deco(
			f,
			"Chain",
			Vector3.new(1.4, 0.2, 0.1) * S,
			cf * CFrame.new(0, y0 + 3.6 * S, -0.56 * S),
			rgb(255, 210, 60),
			M.Neon
		)
	end
	local head = part(f, "Head", Vector3.new(1.2, 1.2, 1.2) * S, cf * CFrame.new(0, y0 + 4.6 * S, 0), skin)
	label(head, Enum.NormalId.Front, style.face, rgb(255, 255, 255), Enum.Font.GothamBold)
	local top = y0 + 5.2 * S
	if style.hat == "cap" then
		part(
			f,
			"Cap",
			Vector3.new(1.3, 0.4, 1.3) * S,
			cf * CFrame.new(0, top + 0.2 * S, 0),
			rgb(110, 90, 70),
			M.Fabric
		)
		part(
			f,
			"Brim",
			Vector3.new(1.3, 0.12, 0.6) * S,
			cf * CFrame.new(0, top + 0.06 * S, -0.8 * S),
			rgb(110, 90, 70),
			M.Fabric
		)
	elseif style.hat == "top" then
		part(
			f,
			"HatBrim",
			Vector3.new(1.7, 0.15, 1.7) * S,
			cf * CFrame.new(0, top + 0.08 * S, 0),
			rgb(20, 20, 25)
		)
		part(
			f,
			"TopHat",
			Vector3.new(1.1, 1.3, 1.1) * S,
			cf * CFrame.new(0, top + 0.8 * S, 0),
			rgb(20, 20, 25)
		)
		part(f, "HatBand", Vector3.new(1.15, 0.2, 1.15) * S, cf * CFrame.new(0, top + 0.3 * S, 0), trim)
	elseif style.hat == "tricorn" then
		part(
			f,
			"Tricorn",
			Vector3.new(1.9, 0.5, 1.4) * S,
			cf * CFrame.new(0, top + 0.25 * S, 0),
			rgb(25, 25, 30)
		)
		part(
			f,
			"TricornTrim",
			Vector3.new(1.95, 0.12, 1.45) * S,
			cf * CFrame.new(0, top + 0.05 * S, 0),
			rgb(255, 200, 40)
		)
	elseif style.hat == "captain" then
		part(
			f,
			"CaptainHat",
			Vector3.new(1.4, 0.5, 1.4) * S,
			cf * CFrame.new(0, top + 0.25 * S, 0),
			rgb(255, 255, 255)
		)
		part(
			f,
			"CaptainBrim",
			Vector3.new(1.4, 0.12, 0.6) * S,
			cf * CFrame.new(0, top + 0.05 * S, -0.8 * S),
			rgb(20, 30, 80)
		)
	end
	-- name over the head
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(280, 54)
	bb.StudsOffset = Vector3.new(0, 4.5 * S, 0)
	bb.MaxDistance = 160
	bb.LightInfluence = 0
	bb.Parent = torso
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = def.emoji .. " " .. string.upper(def.name)
	l.TextColor3 = rgb(255, 230, 120)
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = rgb(30, 20, 10)
	st.Parent = l
	l.Parent = bb
end

-- ===== bases =====
-- Corner towers with glowing caps, a doormat and a glowing ring under each pedestal.
-- `floorTop`: the top of the stage the pedestals stand on.
function WorldDecor.base(
	model: Model,
	origin: CFrame,
	color: Color3,
	pedestals: { BasePart },
	floorTop: number
): { BasePart }
	local W, D, H = World.BaseWidth, World.BaseDepth, World.WallHeight
	local function at(lx: number, ly: number, depth: number): CFrame
		return origin * CFrame.new(lx, ly, -depth)
	end
	for _, lx in { -W / 2, W / 2 } do
		for _, depth in { 0, D } do
			part(
				model,
				"Tower",
				Vector3.new(4, H + 4, 4),
				at(lx, (H + 4) / 2, depth),
				rgb(40, 42, 92),
				M.SmoothPlastic
			)
			local cap =
				part(model, "TowerCap", Vector3.new(4.6, 1.4, 4.6), at(lx, H + 4.7, depth), color, M.Neon)
			light(cap, color, 18, 1.2)
		end
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
	cyl(f, "Bowl", 0.8, 6, base * CFrame.new(0, 6, 0), rgb(255, 205, 40), M.Foil)
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
function WorldDecor.trailsShop(parent: Instance, pos: Vector3): ProximityPrompt
	local f = Instance.new("Model")
	f.Name = "TrailsShop"
	f.Parent = parent
	local base = CFrame.new(pos)
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
	for x = -200, 200, 50 do
		pumpkin(f, CFrame.new(x, 0.3, if (x // 50) % 2 == 0 then 7 else -7), 0.9)
	end
end

return WorldDecor
