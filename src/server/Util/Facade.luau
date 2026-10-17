--!strict
-- The prison as seen from the Yard (WorldBuilder calls Facade.build after the Yard): the low Common
-- Room + Mess Hall get clad into a tall, grim cell block. Concrete with belt courses, pilasters and
-- corner piers, rows of narrow barred slit windows set in deep reveals, a central gate tower with a
-- "STATE PENITENTIARY" sign and a glazed guard post, a steel sally port with a parked sliding gate,
-- a guard catwalk, floodlights, cameras, drain pipes, rooftop razor wire, HVAC units and a water
-- tank; behind the fence a second wing (CELL BLOCK B) and warning signs.
-- Purely visual and outside the playable floor: nothing reaches more than ~2 studs into the Yard,
-- the Yard door stays clear. Decorative layers sit at distinct depths (no coplanar faces, see the
-- z-fighting scan in tools/smoke.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Config.World)
local Build = require(script.Parent.Build)

local Facade = {}

local CONCRETE = Color3.fromRGB(122, 120, 114)
local CONCRETE_HI = Color3.fromRGB(146, 144, 137) -- bands, reveals, sills: lighter precast
local CONCRETE_DK = Color3.fromRGB(98, 97, 93) -- pilasters, piers
local PLINTH = Color3.fromRGB(64, 64, 66)
local STEEL = Color3.fromRGB(58, 62, 68)
local DARK_STEEL = Color3.fromRGB(38, 40, 44)
local SLIT = Color3.fromRGB(22, 24, 28)
local LIT = Color3.fromRGB(150, 124, 70)
local YELLOW = Color3.fromRGB(214, 172, 30)
local RUST = Color3.fromRGB(104, 76, 58)

local CR = World.CommonRoom
local F = CR.x - CR.sx / 2 - 4 - 0.1 -- -246.1: the facade plane (the Common Room wall face is at -246)
local ZN = CR.z - CR.sz / 2 - 4 -- -52: outer face of the Common Room's north wall
local ZS = CR.z + CR.sz / 2 + 4 -- 52: south (the Mess Hall starts here)
local MESS_END = ZS + 56 + 4 -- 112: outer face of the Mess Hall's south wall
local BACK = -140 -- the upper floors reach back over the roofs to here
local TOP = 57 -- roof of the main block
local MESS_TOP = 42
local TF = F - 1.2 -- face of the central tower

type Props = { [string]: any }

local function props(mat: Enum.Material, extra: Props?): Props
	local t: Props = { Material = mat }
	if extra then
		for k, v in extra do
			t[k] = v
		end
	end
	return t
end

-- a box on a facade facing -X: `fx` = the facade plane, `front` = how far its face stands out of
-- the plane (toward the Yard), `back` = where its rear face is (negative = buried behind the plane)
local function slab(
	parent: Instance,
	name: string,
	fx: number,
	front: number,
	back: number,
	zA: number,
	zB: number,
	yA: number,
	yB: number,
	color: Color3,
	mat: Enum.Material,
	extra: Props?
): Part
	return Build.box(
		parent,
		name,
		Vector3.new(fx - front, yA, zA),
		Vector3.new(fx - back, yB, zB),
		color,
		props(mat, extra)
	)
end

local DECOR: Props = { CanCollide = false, CanQuery = false, CanTouch = false }

-- a cylinder from a to b (Roblox cylinders run along their X axis)
local function rod(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	d: number,
	color: Color3,
	extra: Props?
): Part
	local t = props(Enum.Material.Metal, DECOR)
	t.Shape = Enum.PartType.Cylinder
	if extra then
		for k, v in extra do
			t[k] = v
		end
	end
	return Build.part(
		parent,
		name,
		Vector3.new((b - a).Magnitude, d, d),
		CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0),
		color,
		t
	)
end

-- deterministic "random" (the same world on every server)
local function hash(a: number, b: number): number
	local v = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
	return v - math.floor(v)
end

-- ===== windows =====

-- a narrow cell window: a dark slit set back in a precast reveal (two jambs + a head), a deep sill
-- and two bars. `lit`: a warm light behind it.
local function window(
	parent: Instance,
	fx: number,
	zc: number,
	ys: number,
	w: number,
	h: number,
	lit: boolean
)
	local z0, z1 = zc - w / 2, zc + w / 2
	slab(parent, "Jamb", fx, 0.5, -0.3, z0 - 0.5, z0, ys, ys + h, CONCRETE_HI, Enum.Material.Concrete, DECOR)
	slab(parent, "Jamb", fx, 0.5, -0.3, z1, z1 + 0.5, ys, ys + h, CONCRETE_HI, Enum.Material.Concrete, DECOR)
	slab(
		parent,
		"Head",
		fx,
		0.55,
		-0.42,
		z0 - 0.6,
		z1 + 0.6,
		ys + h,
		ys + h + 0.6,
		CONCRETE_HI,
		Enum.Material.Concrete,
		DECOR
	)
	slab(
		parent,
		"Slit",
		fx,
		0.06,
		-0.18,
		z0,
		z1,
		ys,
		ys + h,
		if lit then LIT else SLIT,
		if lit then Enum.Material.Neon else Enum.Material.Glass,
		DECOR
	)
	slab(
		parent,
		"Sill",
		fx,
		0.75,
		-0.54,
		z0 - 0.75,
		z1 + 0.75,
		ys - 0.45,
		ys,
		CONCRETE_HI,
		Enum.Material.Concrete,
		DECOR
	)
	for _, dz in { -w / 6, w / 6 } do
		slab(
			parent,
			"Bar",
			fx,
			0.34,
			0.2,
			zc + dz - 0.07,
			zc + dz + 0.07,
			ys,
			ys + h,
			DARK_STEEL,
			Enum.Material.Metal,
			DECOR
		)
	end
end

-- a cheaper window for the far wing: slit, sill and two bars
local function slitWindow(
	parent: Instance,
	fx: number,
	zc: number,
	ys: number,
	w: number,
	h: number,
	lit: boolean
)
	local z0, z1 = zc - w / 2, zc + w / 2
	slab(
		parent,
		"Slit",
		fx,
		0.06,
		-0.18,
		z0,
		z1,
		ys,
		ys + h,
		if lit then LIT else SLIT,
		if lit then Enum.Material.Neon else Enum.Material.Glass,
		DECOR
	)
	slab(
		parent,
		"Sill",
		fx,
		0.75,
		-0.54,
		z0 - 0.45,
		z1 + 0.45,
		ys - 0.45,
		ys,
		CONCRETE_HI,
		Enum.Material.Concrete,
		DECOR
	)
	for _, dz in { -w / 6, w / 6 } do
		slab(
			parent,
			"Bar",
			fx,
			0.34,
			0.2,
			zc + dz - 0.07,
			zc + dz + 0.07,
			ys,
			ys + h,
			DARK_STEEL,
			Enum.Material.Metal,
			DECOR
		)
	end
end

-- a row of bays: each bay {z0, z1} gets `n` windows on every tier in `tiers`
local function windowRows(
	parent: Instance,
	fx: number,
	bays: { { number } },
	tiers: { number },
	h: number,
	simple: boolean
)
	for t, ys in tiers do
		for b, bay in bays do
			local width = bay[2] - bay[1]
			local n = if width >= 9 then 3 else 2
			local pitch = if n == 3 then 3 else 3.4
			local zc = (bay[1] + bay[2]) / 2
			for k = 1, n do
				local z = zc + (k - (n + 1) / 2) * pitch
				local lit = hash(z + b, ys + t) < 0.14
				if simple then
					slitWindow(parent, fx, z, ys, 1.3, h, lit)
				else
					window(parent, fx, z, ys, 1.3, h, lit)
				end
			end
		end
	end
end

-- ===== weathering: soft dark rain streaks and a grime line (SurfaceGui frames, no parts) =====
local function weather(part: BasePart, face: Enum.NormalId, seed: number, count: number)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Weathering"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 4
	gui.LightInfluence = 1
	gui.Parent = part
	for i = 1, count do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.fromRGB(30, 30, 28)
		local w = 0.012 + hash(seed, i) * 0.03
		local len = 0.25 + hash(i, seed) * 0.6
		f.Position = UDim2.fromScale(hash(seed + i, 3.1) * (1 - w), hash(seed, i + 7) * 0.2)
		f.Size = UDim2.fromScale(w, len)
		f.Parent = gui
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
	end
	-- the dark line along the bottom (splash-back) and under the cornice
	for _, top in { false, true } do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.fromRGB(20, 20, 18)
		f.AnchorPoint = Vector2.new(0, if top then 0 else 1)
		f.Position = UDim2.fromScale(0, if top then 0 else 1)
		f.Size = UDim2.fromScale(1, math.min(0.25, 3 / part.Size.Y))
		f.Parent = gui
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = if top
			then NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
			else NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0.45),
			})
		g.Parent = f
	end
end

-- ===== small fixtures =====

local function plate(
	parent: Instance,
	name: string,
	cf: CFrame,
	size: Vector3,
	bg: Color3,
	text: string,
	fg: Color3
)
	local part = Build.part(parent, name, size, cf, bg, props(Enum.Material.Metal, DECOR))
	Build.sign(part, Enum.NormalId.Front, text, fg)
	return part
end

-- a security camera on a wall arm, looking along `facing`
local function camera(parent: Instance, mount: Vector3, facing: Vector3)
	local at = mount + Vector3.new(-1.3, -0.4, 0)
	rod(parent, "CamArm", mount, at + Vector3.new(0, 0.35, 0), 0.25, STEEL)
	local cf = CFrame.lookAt(at, at + facing)
	Build.part(
		parent,
		"CamBody",
		Vector3.new(0.8, 0.8, 1.8),
		cf,
		Color3.fromRGB(215, 215, 210),
		props(Enum.Material.SmoothPlastic, DECOR)
	)
	Build.part(
		parent,
		"CamHood",
		Vector3.new(1.0, 0.12, 2.1),
		cf * CFrame.new(0, 0.46, -0.1),
		Color3.fromRGB(190, 190, 186),
		props(Enum.Material.Metal, DECOR)
	)
	Build.part(
		parent,
		"CamLens",
		Vector3.new(0.5, 0.5, 0.12),
		cf * CFrame.new(0, 0, -0.94),
		Color3.fromRGB(12, 12, 15),
		props(Enum.Material.Glass, DECOR)
	)
	Build.part(
		parent,
		"CamLed",
		Vector3.new(0.14, 0.14, 0.1),
		cf * CFrame.new(0.28, 0.28, -0.93),
		Color3.fromRGB(255, 40, 40),
		props(Enum.Material.Neon, DECOR)
	)
end

-- a floodlight on a bracket, tilted down toward the Yard
local function flood(parent: Instance, mount: Vector3, range: number, aim: Vector3?)
	local at = mount + Vector3.new(-1.6, 0, 0)
	rod(parent, "FloodArm", mount, at, 0.35, DARK_STEEL)
	local cf = CFrame.lookAt(at, at + (aim or Vector3.new(-1, -0.9, 0)))
	Build.part(
		parent,
		"FloodHousing",
		Vector3.new(2.6, 1.6, 1.2),
		cf,
		DARK_STEEL,
		props(Enum.Material.Metal, DECOR)
	)
	local lens = Build.part(
		parent,
		"FloodLens",
		Vector3.new(2.2, 1.2, 0.1),
		cf * CFrame.new(0, 0, -0.62),
		Color3.fromRGB(255, 248, 225),
		props(Enum.Material.Neon, DECOR)
	)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Angle = 70
	spot.Range = range
	spot.Brightness = 2.2
	spot.Color = Color3.fromRGB(255, 244, 220)
	spot.Shadows = false
	spot.Parent = lens
end

-- a caged bulkhead light by a door
local function cagedLight(parent: Instance, at: Vector3)
	Build.part(
		parent,
		"LightBase",
		Vector3.new(0.5, 1.4, 1.4),
		CFrame.new(at + Vector3.new(-0.25, 0, 0)),
		DARK_STEEL,
		props(Enum.Material.Metal, DECOR)
	)
	local bulb = Build.part(
		parent,
		"LightBulb",
		Vector3.new(0.9, 0.9, 0.9),
		CFrame.new(at + Vector3.new(-0.75, 0, 0)),
		Color3.fromRGB(255, 214, 140),
		props(Enum.Material.Neon, { Shape = Enum.PartType.Ball, CanCollide = false, CanQuery = false })
	)
	Build.light(bulb, Color3.fromRGB(255, 200, 130), 18, 1.2)
	for k = -1, 1 do
		rod(
			parent,
			"Cage",
			at + Vector3.new(-0.5, -0.6, k * 0.4),
			at + Vector3.new(-1.25, 0, k * 0.4),
			0.08,
			DARK_STEEL
		)
		rod(
			parent,
			"Cage",
			at + Vector3.new(-1.25, 0, k * 0.4),
			at + Vector3.new(-0.5, 0.6, k * 0.4),
			0.08,
			DARK_STEEL
		)
	end
end

-- a downpipe with a hopper head under the cornice
local function downpipe(parent: Instance, x: number, z: number, top: number)
	rod(parent, "Downpipe", Vector3.new(x, 0.3, z), Vector3.new(x, top, z), 0.55, Color3.fromRGB(70, 72, 70))
	Build.box(
		parent,
		"Hopper",
		Vector3.new(x - 0.55, top - 0.1, z - 0.6),
		Vector3.new(x + 0.35, top + 1.1, z + 0.6),
		Color3.fromRGB(70, 72, 70),
		props(Enum.Material.Metal, DECOR)
	)
	rod(
		parent,
		"PipeShoe",
		Vector3.new(x, 0.55, z),
		Vector3.new(x - 0.9, 0.3, z),
		0.55,
		Color3.fromRGB(70, 72, 70)
	)
end

-- a coil of razor wire along a line, on V brackets
local function razor(parent: Instance, a: Vector3, b: Vector3)
	rod(
		parent,
		"RazorCoil",
		a + Vector3.new(0, 1.1, 0),
		b + Vector3.new(0, 1.1, 0),
		1.9,
		Color3.fromRGB(170, 175, 180),
		{
			Transparency = 0.5,
		}
	)
	local len = (b - a).Magnitude
	local n = math.max(1, math.floor(len / 5))
	for i = 0, n do
		local p = a:Lerp(b, i / n)
		for _, s in { -1, 1 } do
			Build.part(
				parent,
				"WireArm",
				Vector3.new(0.12, 2.2, 0.12),
				CFrame.new(p + Vector3.new(s * 0.45, 1.0, 0)) * CFrame.Angles(0, 0, math.rad(s * -24)),
				STEEL,
				props(Enum.Material.Metal, DECOR)
			)
		end
	end
end

-- an HVAC unit with a fan on top and a duct into the roof
local function hvac(parent: Instance, cx: number, cz: number, roof: number, sx: number, sz: number)
	local h = 3.6
	Build.box(
		parent,
		"HVAC",
		Vector3.new(cx - sx / 2, roof, cz - sz / 2),
		Vector3.new(cx + sx / 2, roof + h, cz + sz / 2),
		Color3.fromRGB(150, 152, 150),
		props(Enum.Material.Metal, DECOR)
	)
	Build.box(
		parent,
		"HVACGrille",
		Vector3.new(cx - sx / 2 - 0.08, roof + 0.4, cz - sz / 2 + 0.4),
		Vector3.new(cx - sx / 2 + 0.3, roof + h - 0.5, cz + sz / 2 - 0.4),
		Color3.fromRGB(70, 72, 74),
		props(Enum.Material.DiamondPlate, DECOR)
	)
	local fz = cz - sz / 4
	rod(
		parent,
		"Fan",
		Vector3.new(cx, roof + h - 0.05, fz),
		Vector3.new(cx, roof + h + 0.5, fz),
		math.min(sx, sz) * 0.42,
		Color3.fromRGB(60, 62, 64)
	)
	rod(
		parent,
		"FanGuard",
		Vector3.new(cx, roof + h + 0.45, fz),
		Vector3.new(cx, roof + h + 0.6, fz),
		math.min(sx, sz) * 0.44,
		Color3.fromRGB(110, 112, 114),
		{
			Transparency = 0.4,
		}
	)
	rod(
		parent,
		"Duct",
		Vector3.new(cx + sx / 2 - 0.2, roof + 1.4, cz + sz / 4),
		Vector3.new(cx + sx / 2 + 3.5, roof + 1.4, cz + sz / 4),
		1.3,
		Color3.fromRGB(160, 162, 162)
	)
end

-- a mushroom vent on the roof
local function vent(parent: Instance, x: number, z: number, roof: number)
	rod(
		parent,
		"Vent",
		Vector3.new(x, roof, z),
		Vector3.new(x, roof + 2.2, z),
		0.9,
		Color3.fromRGB(120, 122, 124)
	)
	rod(
		parent,
		"VentCap",
		Vector3.new(x, roof + 2.2, z),
		Vector3.new(x, roof + 2.6, z),
		1.6,
		Color3.fromRGB(100, 102, 104)
	)
end

-- ===== the main block: Common Room clad and raised to a 4-storey cell block =====
local function mainBlock(f: Instance)
	-- cladding over the existing wall (ground storey), leaving the Yard door open
	local clad = {
		slab(f, "Cladding", F, 0, -0.08, ZN, -12.05, 0, 26.06, CONCRETE, Enum.Material.Concrete),
		slab(f, "Cladding", F, 0, -0.08, 12.05, ZS, 0, 26.06, CONCRETE, Enum.Material.Concrete),
		slab(f, "Cladding", F, 0, -0.08, -12.05, 12.05, 14.05, 26.06, CONCRETE, Enum.Material.Concrete),
	}
	-- the upper floors, resting on the Common Room's roof
	local upper =
		Build.box(f, "CellBlockA", Vector3.new(F, 26.06, ZN), Vector3.new(BACK, TOP, ZS), CONCRETE, {
			Material = Enum.Material.Concrete,
		})
	weather(upper, Enum.NormalId.Left, 1, 26)
	weather(clad[1], Enum.NormalId.Left, 2, 8)
	weather(clad[2], Enum.NormalId.Left, 3, 8)

	-- corner piers (also close the little notches at the Common Room's corners)
	for _, s in { -1, 1 } do
		local a, b = s * 47.6, s * 53.8
		Build.box(
			f,
			"CornerPier",
			Vector3.new(F - 0.9, 0, math.min(a, b)),
			Vector3.new(-242.05, TOP + 5.2, math.max(a, b)),
			CONCRETE_DK,
			{ Material = Enum.Material.Concrete }
		)
		local c, d = s * 47.3, s * 54.1
		Build.box(
			f,
			"PierCap",
			Vector3.new(F - 1.2, TOP + 5.2, math.min(c, d)),
			Vector3.new(-241.75, TOP + 6.0, math.max(c, d)),
			CONCRETE_HI,
			{ Material = Enum.Material.Concrete }
		)
	end

	-- pilasters, plinth and belt courses (each layer at its own depth)
	for _, z in { -36.6, -25.4, 25.4, 36.6 } do
		slab(f, "Pilaster", F, 0.8, -0.66, z - 1, z + 1, 0, 55.8, CONCRETE_DK, Enum.Material.Concrete)
	end
	for _, s in { -1, 1 } do
		local a, b = s * 48.3, s * 13.8
		slab(f, "Plinth", F, 0.42, -0.9, math.min(a, b), math.max(a, b), 0, 2.6, PLINTH, Enum.Material.Slate)
	end
	slab(f, "BeltCourse", F, 0.6, -0.78, -53.2, 53.2, 24.6, 27.4, CONCRETE_HI, Enum.Material.Concrete)
	slab(f, "Band", F, 0.5, -0.7, -53.2, 53.2, 36.3, 37.4, CONCRETE_HI, Enum.Material.Concrete)
	slab(f, "Band", F, 0.5, -0.7, -53.2, 53.2, 45.8, 46.9, CONCRETE_HI, Enum.Material.Concrete)
	slab(f, "Cornice", F, 0.95, -1.02, -53.3, 53.3, 55.6, 57.3, CONCRETE_HI, Enum.Material.Concrete)
	-- parapet + coping, and the side parapets (silhouette)
	for _, s in { -1, 1 } do
		local a, b = s * 47.7, s * 13.9
		slab(
			f,
			"Parapet",
			F,
			0.3,
			-1.8,
			math.min(a, b),
			math.max(a, b),
			TOP,
			60.4,
			CONCRETE,
			Enum.Material.Concrete
		)
		slab(
			f,
			"Coping",
			F,
			0.5,
			-2.1,
			math.min(a, b),
			math.max(a, b),
			60.4,
			61.0,
			CONCRETE_HI,
			Enum.Material.Concrete
		)
		local c, d = s * 52, s * 50.4
		Build.box(
			f,
			"Parapet",
			Vector3.new(-242.0, TOP, math.min(c, d)),
			Vector3.new(BACK, 60.4, math.max(c, d)),
			CONCRETE,
			{
				Material = Enum.Material.Concrete,
			}
		)
		razor(f, Vector3.new(F + 0.9, 61.0, s * 47.4), Vector3.new(F + 0.9, 61.0, s * 14.2))
		razor(f, Vector3.new(-241.5, 60.4, s * 51.2), Vector3.new(BACK + 1, 60.4, s * 51.2))
	end

	-- windows: a clerestory row on the ground storey, three cell tiers above
	local bays = {
		{ -47.6, -37.6 },
		{ -35.6, -26.4 },
		{ -24.4, -14 },
		{ 14, 24.4 },
		{ 26.4, 35.6 },
		{ 37.6, 47.6 },
	}
	windowRows(f, F, bays, { 15.5, 29.4, 38.9, 48.4 }, 5.6, false)

	-- drain pipes in front of the outer pilasters
	for _, s in { -1, 1 } do
		downpipe(f, F - 1.15, s * 36.6, 54.0)
	end

	-- the guard catwalk along the second floor, with railings and struts
	for _, s in { -1, 1 } do
		local a, b = s * 47.6, s * 14.2
		local lo, hi = math.min(a, b), math.max(a, b)
		slab(
			f,
			"Catwalk",
			F,
			3.2,
			0.6,
			lo,
			hi,
			26.95,
			27.3,
			Color3.fromRGB(82, 86, 90),
			Enum.Material.DiamondPlate
		)
		slab(f, "CatwalkEdge", F, 3.3, 3.1, lo, hi, 26.75, 27.45, YELLOW, Enum.Material.Metal, DECOR)
		for _, y in { 28.9, 30.7 } do
			slab(f, "Rail", F, 3.15, 3.0, lo, hi, y, y + 0.14, DARK_STEEL, Enum.Material.Metal, DECOR)
		end
		local n = math.floor((hi - lo) / 3)
		for i = 0, n do
			local z = lo + 0.1 + i * (hi - lo - 0.2) / n
			slab(
				f,
				"RailPost",
				F,
				3.16,
				3.02,
				z - 0.07,
				z + 0.07,
				27.45,
				30.9,
				DARK_STEEL,
				Enum.Material.Metal,
				DECOR
			)
			if i % 2 == 0 then
				rod(
					f,
					"Strut",
					Vector3.new(F - 3.0, 27.0, z),
					Vector3.new(F - 0.7, 24.5, z),
					0.22,
					DARK_STEEL
				)
			end
		end
	end

	-- floodlights under the catwalk and on the corner piers, cameras on the piers
	for _, s in { -1, 1 } do
		flood(f, Vector3.new(F - 0.6, 23.1, s * 31), 55)
		flood(f, Vector3.new(F - 0.9, 59.2, s * 50.7), 90, Vector3.new(-1, -0.55, -s * 0.25))
		camera(f, Vector3.new(F - 0.9, 23.2, s * 50.7), Vector3.new(-1, -0.45, -s * 0.5))
	end

	-- a warning sign by the door
	plate(
		f,
		"FacadeSign",
		CFrame.new(F - 0.08, 7.5, -20) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(6, 3, 0.12),
		Color3.fromRGB(230, 228, 218),
		"ALL INMATES\nWILL BE SEARCHED",
		Color3.fromRGB(170, 30, 30)
	)
	plate(
		f,
		"FacadeSign",
		CFrame.new(F - 0.08, 7.5, 20) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(6, 3, 0.12),
		Color3.fromRGB(230, 228, 218),
		"NO LOITERING\nBY THE GATE",
		Color3.fromRGB(170, 30, 30)
	)
end

-- ===== the gate tower over the Yard door, and the sally port =====
local function gateTower(f: Instance)
	Build.box(f, "TowerBase", Vector3.new(TF, 16.1, -14), Vector3.new(F + 0.03, 26.3, 14), CONCRETE_DK, {
		Material = Enum.Material.Concrete,
	})
	local tower =
		Build.box(f, "GateTower", Vector3.new(TF, 26.3, -14), Vector3.new(-214, 72, 14), CONCRETE_DK, {
			Material = Enum.Material.Concrete,
		})
	weather(tower, Enum.NormalId.Left, 4, 10)
	-- bands and windows on the tower front
	slab(f, "Band", TF, 0.5, -0.7, -14.3, 14.3, 36.3, 37.4, CONCRETE_HI, Enum.Material.Concrete)
	slab(f, "Band", TF, 0.5, -0.7, -14.3, 14.3, 45.8, 46.9, CONCRETE_HI, Enum.Material.Concrete)
	windowRows(f, TF, { { -12.5, 0 }, { 0, 12.5 } }, { 29.4, 38.9, 48.4 }, 5.6, false)
	-- the big stencil sign
	plate(
		f,
		"PenitentiarySign",
		CFrame.new(TF - 0.1, 59.2, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(26, 4.6, 0.2),
		Color3.fromRGB(34, 36, 40),
		"STATE PENITENTIARY",
		Color3.fromRGB(232, 226, 205)
	)
	slab(f, "SignFrame", TF, 0.3, -0.05, -13.4, 13.4, 56.6, 56.9, DARK_STEEL, Enum.Material.Metal, DECOR)
	slab(f, "SignFrame", TF, 0.3, -0.05, -13.4, 13.4, 61.5, 61.8, DARK_STEEL, Enum.Material.Metal, DECOR)
	-- the glazed guard post on top
	slab(f, "Ledge", TF, 1.0, -0.1, -14.2, 14.2, 62.3, 62.9, CONCRETE_HI, Enum.Material.Concrete)
	local glass = slab(
		f,
		"GuardGlass",
		TF,
		0.12,
		-0.2,
		-12.4,
		12.4,
		62.9,
		69.2,
		Color3.fromRGB(64, 82, 88),
		Enum.Material.Glass,
		{
			Reflectance = 0.25,
		}
	)
	Build.light(glass, Color3.fromRGB(255, 230, 180), 24, 0.8)
	for i = 0, 8 do
		local z = -12.4 + i * 3.1
		slab(
			f,
			"Mullion",
			TF,
			0.3,
			-0.25,
			z - 0.2,
			z + 0.2,
			62.95,
			69.15,
			DARK_STEEL,
			Enum.Material.Metal,
			DECOR
		)
	end
	Build.box(f, "TowerCap", Vector3.new(TF - 0.7, 72, -14.7), Vector3.new(-213.3, 73.2, 14.7), CONCRETE_HI, {
		Material = Enum.Material.Concrete,
	})
	-- radio mast with a red beacon, and a flag
	rod(f, "Mast", Vector3.new(-225, 73.2, -8), Vector3.new(-225, 88, -8), 0.35, STEEL)
	Build.part(
		f,
		"Beacon",
		Vector3.new(0.8, 0.8, 0.8),
		CFrame.new(-225, 88.3, -8),
		Color3.fromRGB(255, 40, 30),
		props(Enum.Material.Neon, { Shape = Enum.PartType.Ball, CanCollide = false })
	)
	rod(
		f,
		"FlagPole",
		Vector3.new(TF + 2, 73.2, 8),
		Vector3.new(TF + 2, 84, 8),
		0.3,
		Color3.fromRGB(200, 200, 200)
	)
	Build.box(
		f,
		"Flag",
		Vector3.new(TF + 1.94, 79.4, 8.2),
		Vector3.new(TF + 2.06, 83.4, 14.2),
		Color3.fromRGB(32, 44, 78),
		props(Enum.Material.Fabric, DECOR)
	)
	Build.box(
		f,
		"FlagStripe",
		Vector3.new(TF + 1.9, 80.9, 8.25),
		Vector3.new(TF + 2.1, 81.9, 14.15),
		YELLOW,
		props(Enum.Material.Fabric, DECOR)
	)

	-- CELL BLOCK A over the door
	plate(
		f,
		"BlockSign",
		CFrame.new(TF - 0.06, 20.6, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(19, 4.4, 0.12),
		Color3.fromRGB(40, 42, 46),
		"CELL BLOCK A",
		YELLOW
	)
	for _, s in { -1, 1 } do
		cagedLight(f, Vector3.new(TF, 19.6, s * 12.2))
	end

	-- the sally port: heavy steel frame with hazard stripes
	for _, s in { -1, 1 } do
		local a, b = s * 14.2, s * 11.9
		slab(
			f,
			"PortJamb",
			F,
			1.0,
			-0.06,
			math.min(a, b),
			math.max(a, b),
			0,
			15.4,
			DARK_STEEL,
			Enum.Material.Metal
		)
		for k = 0, 4 do
			Build.part(
				f,
				"Hazard",
				Vector3.new(0.06, 0.45, 2.9),
				CFrame.new(F - 1.03, 1.2 + k * 1.6, s * 13.05) * CFrame.Angles(math.rad(45), 0, 0),
				YELLOW,
				props(Enum.Material.SmoothPlastic, DECOR)
			)
		end
	end
	slab(f, "PortHeader", F, 1.1, 0, -14.35, 14.35, 14.0, 16.2, DARK_STEEL, Enum.Material.Metal)
	for k = 0, 9 do
		Build.part(
			f,
			"Rivet",
			Vector3.new(0.2, 0.3, 0.3),
			CFrame.new(F - 1.15, 15.1, -12.6 + k * 2.8),
			STEEL,
			props(Enum.Material.Metal, { Shape = Enum.PartType.Ball, CanCollide = false })
		)
	end
	-- the sliding gate, parked open beside the door, on its overhead track
	slab(f, "GateTrack", F, 2.05, 1.35, -13, 26.6, 13.55, 13.95, DARK_STEEL, Enum.Material.Metal, DECOR)
	for _, z in { 18.5, 23 } do
		slab(
			f,
			"TrackBracket",
			F,
			1.4,
			0,
			z - 0.2,
			z + 0.2,
			13.6,
			13.9,
			DARK_STEEL,
			Enum.Material.Metal,
			DECOR
		)
	end
	local g0, g1 = 14.6, 26.2
	slab(f, "GateRail", F, 1.95, 1.45, g0, g1, 13.0, 13.5, STEEL, Enum.Material.Metal)
	slab(f, "GateRail", F, 1.95, 1.45, g0, g1, 0.3, 0.8, STEEL, Enum.Material.Metal)
	slab(f, "GateRail", F, 1.9, 1.5, g0 + 0.2, g1 - 0.2, 6.6, 7.0, STEEL, Enum.Material.Metal, DECOR)
	slab(f, "GateStile", F, 1.92, 1.48, g0, g0 + 0.4, 0.8, 13.0, STEEL, Enum.Material.Metal)
	slab(f, "GateStile", F, 1.92, 1.48, g1 - 0.4, g1, 0.8, 13.0, STEEL, Enum.Material.Metal)
	for i = 1, 9 do
		local z = g0 + 0.4 + i * (g1 - g0 - 0.8) / 10
		slab(f, "GateBar", F, 1.8, 1.6, z - 0.09, z + 0.09, 0.8, 13.0, STEEL, Enum.Material.Metal, DECOR)
	end
	-- door cameras on the tower's corners
	for _, s in { -1, 1 } do
		camera(f, Vector3.new(TF, 24.0, s * 13.3), Vector3.new(-1, -0.6, s * 0.35))
	end
end

-- ===== the Mess Hall wing: clad, one more floor, same rhythm =====
local function messWing(f: Instance)
	local clad = slab(f, "Cladding", F, 0, -0.08, ZS, MESS_END, 0, 24, CONCRETE, Enum.Material.Concrete)
	local upper =
		Build.box(f, "MessWing", Vector3.new(F, 24, ZS), Vector3.new(BACK, MESS_TOP, MESS_END), CONCRETE, {
			Material = Enum.Material.Concrete,
		})
	weather(upper, Enum.NormalId.Left, 5, 14)
	weather(clad, Enum.NormalId.Left, 6, 8)
	Build.box(
		f,
		"CornerPier",
		Vector3.new(F - 0.9, 0, 110.4),
		Vector3.new(-244, MESS_TOP + 4.2, 113.4),
		CONCRETE_DK,
		{
			Material = Enum.Material.Concrete,
		}
	)
	for _, z in { 64, 75, 88, 100 } do
		slab(f, "Pilaster", F, 0.8, -0.66, z - 1, z + 1, 0, 40.6, CONCRETE_DK, Enum.Material.Concrete)
	end
	slab(f, "Plinth", F, 0.42, -0.9, 53.5, 110.6, 0, 2.6, PLINTH, Enum.Material.Slate)
	slab(f, "BeltCourse", F, 0.6, -0.78, 53.5, 110.6, 22.6, 25.4, CONCRETE_HI, Enum.Material.Concrete)
	slab(f, "Band", F, 0.5, -0.7, 53.5, 110.6, 32.7, 33.5, CONCRETE_HI, Enum.Material.Concrete)
	slab(f, "Cornice", F, 0.95, -1.02, 53.5, 110.6, 40.4, 42.2, CONCRETE_HI, Enum.Material.Concrete)
	slab(f, "Parapet", F, 0.3, -1.8, 53.6, 110.5, MESS_TOP, 45.0, CONCRETE, Enum.Material.Concrete)
	slab(f, "Coping", F, 0.5, -2.1, 53.6, 110.5, 45.0, 45.6, CONCRETE_HI, Enum.Material.Concrete)
	razor(f, Vector3.new(F + 0.9, 45.6, 54.2), Vector3.new(F + 0.9, 45.6, 110))
	local bays = { { 53.8, 63 }, { 65, 74 }, { 76, 87 }, { 89, 99 }, { 101, 110.4 } }
	windowRows(f, F, bays, { 13.0, 27.0 }, 4.8, false)
	windowRows(f, F, bays, { 34.3 }, 4.8, true)
	flood(f, Vector3.new(F - 0.8, 21.0, 75), 50)
	downpipe(f, F - 1.15, 88, 38.6)
end

-- ===== CELL BLOCK B: a second wing north of the Common Room, behind the Yard fence =====
local function wingB(f: Instance)
	local fx = -240.5
	local z0, z1 = -97, ZN - 0.6
	local top = 46
	local wing = Build.box(f, "CellBlockB", Vector3.new(fx, -4, z0), Vector3.new(BACK, top, z1), CONCRETE, {
		Material = Enum.Material.Concrete,
	})
	weather(wing, Enum.NormalId.Left, 7, 16)
	for _, zz in { { -98.2, -95.2 }, { -54.8, z1 + 0.4 } } do
		Build.box(
			f,
			"CornerPier",
			Vector3.new(fx - 0.9, -4, zz[1]),
			Vector3.new(fx + 2, top + 3.6, zz[2]),
			CONCRETE_DK,
			{
				Material = Enum.Material.Concrete,
			}
		)
	end
	for _, z in { -86.6, -75.0, -63.4 } do
		slab(f, "Pilaster", fx, 0.8, -0.66, z - 1, z + 1, -4, 44.6, CONCRETE_DK, Enum.Material.Concrete)
	end
	slab(f, "Plinth", fx, 0.42, -0.9, -95.5, -54.5, -4, 2.6, PLINTH, Enum.Material.Slate)
	for _, y in { 15.6, 25.1, 34.6 } do
		slab(f, "Band", fx, 0.5, -0.7, -95.5, -54.5, y, y + 1.0, CONCRETE_HI, Enum.Material.Concrete)
	end
	slab(f, "Cornice", fx, 0.95, -1.02, -95.6, -54.4, 44.5, 46.3, CONCRETE_HI, Enum.Material.Concrete)
	slab(f, "Parapet", fx, 0.3, -1.8, -95.2, -54.8, top, 49.6, CONCRETE, Enum.Material.Concrete)
	plate(
		f,
		"BlockSign",
		CFrame.new(fx - 0.36, 47.8, -75) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(18, 2.9, 0.12),
		Color3.fromRGB(40, 42, 46),
		"CELL BLOCK B",
		YELLOW
	)
	razor(f, Vector3.new(fx + 0.9, 49.6, -95), Vector3.new(fx + 0.9, 49.6, -55))
	local bays = { { -95.2, -87.6 }, { -85.6, -76 }, { -74, -64.4 }, { -62.4, -54.8 } }
	windowRows(f, fx, bays, { 8.5, 18.0, 27.5, 37.0 }, 5.6, true)
	flood(f, Vector3.new(fx - 0.9, 47.4, -54.0), 70, Vector3.new(-1, -0.7, 0.3))
end

-- ===== warning signs on the Yard fence beside the building =====
local function fenceSigns(f: Instance)
	local Y = World.Yard
	local x1 = Y.x + Y.sx / 2
	local signs: { { z: number, text: string } } = {
		{ z = -69.3, text = "RESTRICTED AREA\nNO INMATES BEYOND THIS FENCE" },
		{ z = -58.8, text = "NO TRESPASSING\nAUTHORIZED PERSONNEL ONLY" },
	}
	for _, s in signs do
		local p = plate(
			f,
			"WarningSign",
			CFrame.new(x1 - 0.42, 6.5, s.z) * CFrame.Angles(0, math.pi / 2, 0),
			Vector3.new(9, 3.6, 0.16),
			Color3.fromRGB(232, 230, 222),
			s.text,
			Color3.fromRGB(175, 28, 28)
		)
		Build.part(
			f,
			"SignStripe",
			Vector3.new(0.06, 0.4, 9),
			p.CFrame * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.new(-0.11, 1.6, 0),
			Color3.fromRGB(175, 28, 28),
			props(Enum.Material.SmoothPlastic, DECOR)
		)
	end
	-- a high voltage plate between them
	plate(
		f,
		"WarningSign",
		CFrame.new(x1 - 0.42, 10.6, -64) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(3.4, 2.2, 0.16),
		YELLOW,
		"⚡ DANGER\nHIGH VOLTAGE",
		Color3.fromRGB(20, 20, 20)
	)
end

-- ===== the roof: HVAC units, vents, a water tank on legs =====
local function roof(f: Instance)
	hvac(f, -232, -38, TOP, 6, 8)
	hvac(f, -228, 33, TOP, 7, 9)
	hvac(f, -186, 22, TOP, 6, 8)
	for _, v in { { -238, -30 }, { -238, 20 }, { -238, 42 }, { -205, -44 }, { -205, 44 } } do
		vent(f, v[1], v[2], TOP)
	end
	vent(f, -236, 70, MESS_TOP)
	vent(f, -236, 96, MESS_TOP)
	hvac(f, -232, 84, MESS_TOP, 6, 8)
	-- the water tank
	local tx, tz, legs = -196, -30, 9
	for _, d in { { -3.2, -3.2 }, { 3.2, -3.2 }, { -3.2, 3.2 }, { 3.2, 3.2 } } do
		rod(
			f,
			"TankLeg",
			Vector3.new(tx + d[1], TOP, tz + d[2]),
			Vector3.new(tx + d[1] * 0.8, TOP + legs, tz + d[2] * 0.8),
			0.6,
			RUST
		)
	end
	rod(
		f,
		"TankBrace",
		Vector3.new(tx - 3.0, TOP + 3, tz - 3.0),
		Vector3.new(tx + 3.0, TOP + 3, tz + 3.0),
		0.3,
		RUST
	)
	rod(
		f,
		"TankBrace",
		Vector3.new(tx + 3.0, TOP + 3, tz - 3.0),
		Vector3.new(tx - 3.0, TOP + 3, tz + 3.0),
		0.3,
		RUST
	)
	rod(
		f,
		"Tank",
		Vector3.new(tx, TOP + legs, tz),
		Vector3.new(tx, TOP + legs + 8, tz),
		9.5,
		Color3.fromRGB(112, 92, 76),
		{
			Material = Enum.Material.CorrodedMetal,
		}
	)
	rod(
		f,
		"TankRoof",
		Vector3.new(tx, TOP + legs + 8, tz),
		Vector3.new(tx, TOP + legs + 9.6, tz),
		7,
		Color3.fromRGB(92, 76, 64),
		{
			Material = Enum.Material.CorrodedMetal,
		}
	)
	rod(
		f,
		"TankRoof",
		Vector3.new(tx, TOP + legs + 9.6, tz),
		Vector3.new(tx, TOP + legs + 10.4, tz),
		3,
		Color3.fromRGB(92, 76, 64),
		{
			Material = Enum.Material.CorrodedMetal,
		}
	)
end

function Facade.build(prison: Instance)
	local f = Instance.new("Folder")
	f.Name = "Facade"
	f.Parent = prison
	mainBlock(f)
	gateTower(f)
	messWing(f)
	wingB(f)
	fenceSigns(f)
	roof(f)
	for _, d in f:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = d.Size.Magnitude > 20
		end
	end
end

return Facade
