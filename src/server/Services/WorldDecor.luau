--!strict
-- Set dressing built from parts: a unique theme inside every vault, the city skyline behind
-- Rich Street, sidewalks, fountains, base towers and the express lanes. Pure decoration except the
-- lanes (moving walkways) and pedestal rings; nothing here touches the economy.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Economy = require(Shared.Config.Economy)

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

-- ===== vault themes =====
-- `at(lx, ly, depth)` places inside the vault (lx across, depth from the door). Free zones: the
-- side strips |lx| 31..43, depth 8..66, and the back strip depth 58..67.
type At = (lx: number, ly: number, depth: number) -> CFrame

local THEMES: { [string]: (folder: Instance, at: At, trim: Color3) -> () } = {
	Grandpa = function(f, at, _trim)
		car(f, at(-37, 0.4, 38), rgb(90, 140, 200))
		part(f, "Pegboard", Vector3.new(18, 8, 0.4), at(30, 6, 66.6), rgb(170, 130, 90), M.WoodPlanks)
		for i = 0, 4 do
			part(
				f,
				"Tool",
				Vector3.new(0.4, 3, 0.3),
				at(23 + i * 3.4, 6, 66.2) * CFrame.Angles(0, 0, math.rad(15 * (i - 2))),
				rgb(150, 150, 160),
				M.Metal
			)
		end
		for i = 0, 2 do
			barrel(f, at(38, 0.4, 14 + i * 3), rgb(200, 60, 40))
		end
		part(f, "Workbench", Vector3.new(6, 3, 14), at(38, 1.9, 48), rgb(120, 80, 50), M.Wood)
		part(
			f,
			"Tire",
			Vector3.new(1.2, 3, 3),
			at(-37, 1.9, 60),
			rgb(25, 25, 28),
			M.Rubber,
			Enum.PartType.Cylinder
		)
	end,
	Influencer = function(f, at, trim)
		part(f, "Couch", Vector3.new(6, 2, 16), at(-38, 1.4, 40), rgb(255, 120, 190), M.Fabric)
		part(f, "CouchBack", Vector3.new(1.5, 3, 16), at(-41.5, 3, 40), rgb(255, 100, 180), M.Fabric)
		ringLight(f, at(36, 0.4, 20))
		ringLight(f, at(36, 0.4, 56))
		local sign = part(f, "NeonSign", Vector3.new(22, 5, 0.4), at(0, 12, 66.6), trim, M.Neon)
		label(sign, Enum.NormalId.Back, "❤ LIKE & SUBSCRIBE ❤", rgb(255, 255, 255)) -- Back = toward the door
		for i = 0, 5 do
			local b = deco(
				f,
				"Balloon",
				Vector3.new(2, 2.4, 2),
				at(-36 + (i % 3) * 2.2, 10 + (i // 3) * 2, 14 + (i % 2)),
				if i % 2 == 0 then rgb(255, 120, 200) else rgb(140, 220, 255),
				M.SmoothPlastic,
				Enum.PartType.Ball
			)
			CollectionService:AddTag(b, "Bob")
		end
		part(f, "Tripod", Vector3.new(0.4, 5, 0.4), at(36, 2.9, 38), rgb(40, 40, 45), M.Metal)
		part(f, "Camera", Vector3.new(1.6, 1.2, 2.2), at(36, 5.8, 38), rgb(30, 30, 35), M.Metal)
	end,
	Pirate = function(f, at, _trim)
		cyl(f, "Mast", 26, 1.4, at(-37, 13.4, 60), rgb(110, 75, 45), M.Wood)
		part(
			f,
			"Yard",
			Vector3.new(1, 1, 16),
			at(-37, 22, 60) * CFrame.Angles(0, math.rad(90), 0),
			rgb(110, 75, 45),
			M.Wood
		)
		local sail = deco(
			f,
			"Sail",
			Vector3.new(0.3, 10, 14),
			at(-36.4, 16.5, 60) * CFrame.Angles(0, math.rad(90), 0),
			rgb(240, 235, 220),
			M.Fabric
		)
		label(sail, Enum.NormalId.Right, "☠", rgb(30, 30, 35))
		label(sail, Enum.NormalId.Left, "☠", rgb(30, 30, 35))
		deco(f, "Flag", Vector3.new(0.2, 2, 3.4), at(-37, 27.5, 61.7), rgb(20, 20, 25), M.Fabric)
		chest(f, at(37, 0.4, 20))
		chest(f, at(37, 0.4, 32))
		for i = 0, 1 do
			part(
				f,
				"Cannon",
				Vector3.new(5, 1.8, 1.8),
				at(-36, 2.2, 18 + i * 10) * CFrame.Angles(0, math.rad(90), math.rad(12)),
				rgb(35, 35, 40),
				M.Metal,
				Enum.PartType.Cylinder
			)
			part(f, "CannonCart", Vector3.new(2.4, 1.2, 3), at(-36, 1, 18 + i * 10), rgb(110, 70, 40), M.Wood)
		end
		for i = 0, 2 do
			barrel(f, at(38, 0.4, 50 + i * 3), rgb(130, 85, 50))
		end
	end,
	Museum = function(f, at, _trim)
		for _, lx in { -38, 38 } do
			for i = 0, 2 do
				column(f, at(lx, 0.4, 14 + i * 22), 16, rgb(235, 230, 215))
			end
		end
		-- dino skeleton on the back strip
		local bone = rgb(240, 232, 210)
		part(f, "Spine", Vector3.new(20, 1.2, 1.2), at(0, 9, 62), bone, M.Marble)
		part(
			f,
			"Skull",
			Vector3.new(4, 3, 2.4),
			at(-11, 11, 62) * CFrame.Angles(0, 0, math.rad(-15)),
			bone,
			M.Marble
		)
		part(
			f,
			"Tail",
			Vector3.new(8, 0.8, 0.8),
			at(13, 7.5, 62) * CFrame.Angles(0, 0, math.rad(-20)),
			bone,
			M.Marble
		)
		for i = 0, 5 do
			part(f, "Rib", Vector3.new(0.5, 4, 0.5), at(-6 + i * 2.4, 7, 62), bone, M.Marble)
		end
		for _, lx in { -4, 6 } do
			part(f, "Leg", Vector3.new(1, 8.6, 1), at(lx, 4.7, 62), bone, M.Marble)
		end
		frame(f, at(-30, 9, 66.7) * CFrame.Angles(0, math.pi, 0), 8, 6, "🦙", rgb(60, 110, 70))
		frame(f, at(30, 9, 66.7) * CFrame.Angles(0, math.pi, 0), 8, 6, "🌻", rgb(60, 70, 130))
		for i = 0, 3 do
			cyl(f, "Stanchion", 3, 0.5, at(-8 + i * 5.3, 1.9, 56), rgb(255, 200, 40), M.Foil)
		end
		deco(f, "Rope", Vector3.new(16, 0.3, 0.3), at(0, 3, 56), rgb(180, 20, 40), M.Fabric)
	end,
	GoldTycoon = function(f, at, _trim)
		coinPile(f, at(-37, 0.4, 16), 1.4)
		coinPile(f, at(-37, 0.4, 56), 1.6)
		coinPile(f, at(37, 0.4, 60), 1.2)
		goldBars(f, at(37, 0.4, 18))
		goldBars(f, at(37, 0.4, 38))
		goldBars(f, at(-37, 0.4, 36))
		statue(f, at(0, 0.4, 62), 1)
		for i = 0, 1 do
			local bag = part(
				f,
				"MoneyBag",
				Vector3.new(3, 3, 3),
				at(-30 + i * 60, 1.9, 64),
				rgb(90, 200, 90),
				M.Fabric,
				Enum.PartType.Ball
			)
			label(bag, Enum.NormalId.Back, "$", rgb(255, 255, 255))
		end
	end,
	Yacht = function(f, at, _trim)
		part(f, "PoolRim", Vector3.new(10, 1, 30), at(-37, 0.9, 38), rgb(240, 240, 250), M.Marble)
		local water =
			part(f, "Water", Vector3.new(8.4, 1.1, 28.4), at(-37, 1, 38), rgb(40, 170, 255), M.Glass)
		water.Transparency = 0.25
		water.CanCollide = false
		light(water, rgb(80, 200, 255), 16, 1)
		for i = 0, 2 do
			part(f, "DeckChair", Vector3.new(3, 1, 6), at(37, 1.4, 16 + i * 9), rgb(255, 255, 255), M.Fabric)
			part(
				f,
				"ChairBack",
				Vector3.new(3, 3, 1),
				at(37, 2.4, 13.2 + i * 9) * CFrame.Angles(math.rad(-25), 0, 0),
				rgb(30, 60, 140),
				M.Fabric
			)
		end
		part(f, "BoatHull", Vector3.new(6, 3, 14), at(37, 2, 54), rgb(250, 250, 255), M.SmoothPlastic)
		part(f, "BoatStripe", Vector3.new(6.1, 0.6, 14.1), at(37, 2.4, 54), rgb(30, 60, 140), M.SmoothPlastic)
		part(f, "BoatCabin", Vector3.new(4, 2, 5), at(37, 4.5, 55), rgb(150, 200, 230), M.Glass)
		for i = 0, 1 do
			part(
				f,
				"LifeRing",
				Vector3.new(0.6, 3, 3),
				at(-20 + i * 40, 7, 66.6) * CFrame.Angles(0, math.rad(90), 0),
				rgb(255, 80, 60),
				M.SmoothPlastic,
				Enum.PartType.Cylinder
			)
		end
	end,
	TechBillionaire = function(f, at, trim)
		for i = 0, 4 do
			serverRack(f, at(-38, 0.4, 14 + i * 4) * CFrame.Angles(0, math.rad(-90), 0))
			serverRack(f, at(-38, 0.4, 44 + i * 4) * CFrame.Angles(0, math.rad(-90), 0))
		end
		rocket(f, at(37, 0.4, 56))
		local holo = part(f, "Hologram", Vector3.new(24, 7, 0.3), at(0, 11, 66.6), trim, M.Neon)
		holo.Transparency = 0.35
		label(holo, Enum.NormalId.Back, "🚀 TO MARS 🚀", rgb(255, 255, 255))
		part(f, "Desk", Vector3.new(4, 3, 10), at(37, 1.9, 24), rgb(240, 240, 250), M.SmoothPlastic)
		local screen = part(f, "Screen", Vector3.new(0.3, 3, 6), at(35.8, 5, 24), rgb(0, 200, 255), M.Neon)
		CollectionService:AddTag(screen, "Blink")
	end,
	Billionaire = function(f, at, trim)
		statue(f, at(0, 0.4, 62), 1.25)
		coinPile(f, at(-37, 0.4, 16), 1.5)
		coinPile(f, at(37, 0.4, 16), 1.5)
		goldBars(f, at(-37, 0.4, 36))
		goldBars(f, at(37, 0.4, 36))
		car(f, at(-37, 0.4, 56), rgb(255, 200, 40))
		-- chandelier
		local chand =
			deco(f, "Chandelier", Vector3.new(6, 2, 6), at(0, 15, 37), trim, M.Neon, Enum.PartType.Ball)
		light(chand, rgb(255, 220, 140), 30, 2)
		local diamond = deco(
			f,
			"Diamond",
			Vector3.new(3, 3, 3),
			at(37, 6, 56) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			rgb(170, 240, 255),
			M.Glass
		)
		diamond.Reflectance = 0.4
		CollectionService:AddTag(diamond, "Spin")
		part(f, "DiamondStand", Vector3.new(3, 3, 3), at(37, 1.9, 56), rgb(30, 25, 35), M.Marble)
	end,
}

function WorldDecor.vault(model: Model, id: string, origin: CFrame, trim: Color3)
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
	-- facade: awning over the door + two spotlights pointing at the sign
	part(
		f,
		"Awning",
		Vector3.new(38, 0.6, 5),
		at(0, 12, -2.5) * CFrame.Angles(math.rad(-12), 0, 0),
		trim,
		M.Fabric
	)
	for _, lx in { -22, 22 } do
		local spot = deco(
			f,
			"Spot",
			Vector3.new(1.4, 1.4, 1.4),
			at(lx, 1.2, -3),
			rgb(255, 250, 230),
			M.Neon,
			Enum.PartType.Ball
		)
		local s = Instance.new("SpotLight")
		s.Face = Enum.NormalId.Top
		s.Angle = 50
		s.Range = 28
		s.Brightness = 3
		s.Color = rgb(255, 240, 210)
		s.Parent = spot
	end
end

-- ===== bases =====
-- Corner towers with glowing caps, an entrance carpet and a glowing ring under each pedestal.
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
				color:Lerp(rgb(0, 0, 0), 0.55),
				M.Brick
			)
			local cap =
				part(model, "TowerCap", Vector3.new(4.6, 1.4, 4.6), at(lx, H + 4.7, depth), color, M.Neon)
			light(cap, color, 18, 1.2)
		end
	end
	deco(
		model,
		"Carpet",
		Vector3.new(World.EntranceWidth - 4, 0.12, 12),
		at(0, floorTop + 0.06, 6),
		color,
		M.Fabric
	)
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

-- ===== express lanes =====
-- Two moving walkways (one out to Rich Street, one back home) with chevrons the client animates.
function WorldDecor.lanes(parent: Instance, fromX: number, toX: number)
	local folder = Instance.new("Folder")
	folder.Name = "Lanes"
	folder.Parent = parent
	local L = Economy.Lanes
	local len = toX - fromX
	for _, spec in
		{ { z = -20, dir = 1, color = rgb(70, 200, 255) }, { z = 20, dir = -1, color = rgb(255, 190, 60) } }
	do
		local lane = part(
			folder,
			"Lane",
			Vector3.new(len, 0.4, L.Width),
			CFrame.new(fromX + len / 2, 0.36, spec.z),
			rgb(40, 42, 52),
			M.Rubber
		)
		lane.AssemblyLinearVelocity = Vector3.new(spec.dir * L.Speed, 0, 0)
		lane:SetAttribute("Dir", spec.dir)
		for _, side in { -1, 1 } do
			part(
				folder,
				"LaneEdge",
				Vector3.new(len, 0.5, 0.5),
				CFrame.new(fromX + len / 2, 0.4, spec.z + side * (L.Width / 2 + 0.25)),
				spec.color,
				M.Neon
			).CanCollide =
				false
		end
		for x = fromX + 6, toX - 6, 10 do
			local c = deco(
				folder,
				"Chevron",
				Vector3.new(1.2, 0.1, 4),
				CFrame.new(x, 0.6, spec.z) * CFrame.Angles(0, if spec.dir > 0 then 0 else math.pi, 0),
				spec.color,
				M.Neon
			)
			CollectionService:AddTag(c, "Chevron")
		end
		-- big arrow signs at both ends
		for _, x in { fromX + 2, toX - 2 } do
			-- high enough to run under (bottom at 8 studs)
			local sign = part(
				folder,
				"LaneSign",
				Vector3.new(0.6, 3, L.Width),
				CFrame.new(x, 9.5, spec.z),
				rgb(25, 25, 32),
				M.SmoothPlastic
			)
			local text = if spec.dir > 0 then "💰 RICH STREET ▶" else "◀ HOME 🏠"
			label(sign, Enum.NormalId.Left, text, spec.color)
			label(sign, Enum.NormalId.Right, text, spec.color)
			part(
				folder,
				"LaneSignPost",
				Vector3.new(0.5, 11, 0.5),
				CFrame.new(x, 5.5, spec.z + L.Width / 2 + 0.6),
				rgb(40, 40, 45),
				M.Metal
			)
		end
	end
	return folder
end

-- ===== streets, plaza, city =====
function WorldDecor.sidewalks(parent: Instance, fromX: number, toX: number)
	local len = toX - fromX
	for _, side in { -1, 1 } do
		part(
			parent,
			"Sidewalk",
			Vector3.new(len, 0.5, 6),
			CFrame.new(fromX + len / 2, 0.25, side * (World.StreetHalfWidth + 3)),
			rgb(200, 195, 185),
			M.Concrete
		)
		part(
			parent,
			"Curb",
			Vector3.new(len, 0.55, 0.6),
			CFrame.new(fromX + len / 2, 0.28, side * (World.StreetHalfWidth + 0.3)),
			rgb(240, 200, 60),
			M.SmoothPlastic
		)
	end
	-- crosswalk at the gate
	for i = -4, 4 do
		deco(
			parent,
			"Crosswalk",
			Vector3.new(5, 0.05, 2.4),
			CFrame.new(fromX + 12, 0.33, i * 5),
			rgb(250, 250, 250),
			M.SmoothPlastic
		)
	end
end

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

function WorldDecor.bench(parent: Instance, cf: CFrame)
	part(parent, "BenchSeat", Vector3.new(6, 0.5, 2), cf * CFrame.new(0, 1.6, 0), rgb(150, 100, 60), M.Wood)
	part(
		parent,
		"BenchBack",
		Vector3.new(6, 1.6, 0.4),
		cf * CFrame.new(0, 2.6, 0.9),
		rgb(150, 100, 60),
		M.Wood
	)
	for _, x in { -2.5, 2.5 } do
		part(
			parent,
			"BenchLeg",
			Vector3.new(0.4, 1.4, 1.8),
			cf * CFrame.new(x, 0.7, 0),
			rgb(40, 40, 45),
			M.Metal
		)
	end
end

function WorldDecor.palm(parent: Instance, pos: Vector3, scale: number)
	local trunk = rgb(150, 110, 70)
	for i = 0, 4 do
		local h = 3 * scale
		part(
			parent,
			"PalmTrunk",
			Vector3.new(1.4, h, 1.4) * Vector3.new(scale, 1, scale),
			CFrame.new(pos + Vector3.new(i * 0.35 * scale, (i + 0.5) * h, 0)),
			trunk,
			M.Wood
		)
	end
	local top = pos + Vector3.new(1.6 * scale, 15.5 * scale, 0)
	for i = 0, 5 do
		local a = math.rad(i * 60)
		deco(
			parent,
			"PalmLeaf",
			Vector3.new(1.2, 0.3, 7) * scale,
			CFrame.new(top)
				* CFrame.Angles(0, a, 0)
				* CFrame.new(0, 0, -3 * scale)
				* CFrame.Angles(math.rad(-20), 0, 0),
			rgb(60, 170, 70),
			M.Grass
		)
	end
end

-- Tall glass towers behind the vaults: the rich part of town. `fromX`..`toX` along the street.
function WorldDecor.skyline(parent: Instance, fromX: number, toX: number)
	local folder = Instance.new("Folder")
	folder.Name = "Skyline"
	folder.Parent = parent
	local rng = Random.new(2877)
	local palette = {
		rgb(70, 90, 130),
		rgb(110, 125, 150),
		rgb(60, 70, 90),
		rgb(150, 160, 175),
		rgb(90, 70, 110),
	}
	for _, side in { -1, 1 } do
		local x = fromX
		while x < toX do
			local w = rng:NextNumber(26, 46)
			local d = rng:NextNumber(26, 40)
			local h = rng:NextNumber(40, 120)
			local z = side * rng:NextNumber(128, 150)
			local cx = x + w / 2
			local color = palette[rng:NextInteger(1, #palette)]
			part(folder, "Tower", Vector3.new(w, h, d), CFrame.new(cx, h / 2, z), color, M.Glass).Reflectance =
				0.15
			-- glowing window bands facing the street
			local face = z - side * (d / 2 + 0.05)
			for y = 8, h - 6, 10 do
				deco(
					folder,
					"Windows",
					Vector3.new(w - 4, 2.2, 0.2),
					CFrame.new(cx, y, face),
					rgb(255, 230, 150),
					M.Neon
				).Transparency =
					rng:NextNumber(0.1, 0.5)
			end
			part(
				folder,
				"Roof",
				Vector3.new(w + 1, 1.2, d + 1),
				CFrame.new(cx, h + 0.6, z),
				color:Lerp(rgb(0, 0, 0), 0.3),
				M.Concrete
			)
			if rng:NextNumber() < 0.35 then
				local ant = deco(
					folder,
					"Antenna",
					Vector3.new(0.6, 10, 0.6),
					CFrame.new(cx, h + 6, z),
					rgb(200, 200, 210),
					M.Metal
				)
				local tip = deco(
					folder,
					"AntennaTip",
					Vector3.new(1, 1, 1),
					ant.CFrame * CFrame.new(0, 5.4, 0),
					rgb(255, 60, 60),
					M.Neon,
					Enum.PartType.Ball
				)
				CollectionService:AddTag(tip, "Blink")
			end
			x += w + rng:NextNumber(4, 12)
		end
	end
end

-- "SAFE ZONE" painted on the floor just inside a base entrance (reads walking in).
function WorldDecor.safeZone(model: Model, origin: CFrame, floorTop: number)
	local p = deco(
		model,
		"SafeZone",
		Vector3.new(World.EntranceWidth - 2, 0.05, 5),
		origin * CFrame.new(0, floorTop + 0.15, -3.5),
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
	local body = part(
		parent,
		"Pumpkin",
		Vector3.new(3.2, 2.6, 3.2) * scale,
		cf * CFrame.new(0, 1.3 * scale, 0),
		rgb(255, 120, 20),
		M.SmoothPlastic,
		Enum.PartType.Ball
	)
	part(
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
		for _, lx in { -21, 21 } do
			pumpkin(f, o * CFrame.new(lx, 0.4, 6), 1.3)
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
