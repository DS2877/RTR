--!strict
-- Lived-in details for the shared rooms (called from Dressing): the Mess Hall gets barred daylight
-- windows, quarry-tile floor, painted lower walls with a trim line, ceiling fans (tag CeilingFan:
-- the client spins them), trays of slop on every table, a tray rack, a kitchen (fridge, stove,
-- shelves of cans) with steaming pots, posters, a clock and a guard at the door. The Common Room
-- gets a notice board, a water fountain, fire extinguishers, vents, floor drains and a mop bucket.
-- Purely visual. Windows are tagged SkyWindow (dimmed at night).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Config.World)
local Build = require(script.Parent.Build)
local Props = require(script.Parent.Props)

local Interior = {}

local STEEL = Color3.fromRGB(78, 82, 88)
local DARK = Color3.fromRGB(36, 38, 42)
local PAINT = Color3.fromRGB(52, 72, 66)
local TRIM = Color3.fromRGB(176, 150, 70)

local function p(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material?,
	extra: { [string]: any }?
): Part
	local props: { [string]: any } = { Material = mat or Enum.Material.SmoothPlastic }
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
	return Build.part(parent, name, size, cf, color, props)
end

local function box(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	color: Color3,
	mat: Enum.Material?,
	extra: { [string]: any }?
): Part
	local lo, hi = a:Min(b), a:Max(b)
	return p(parent, name, hi - lo, CFrame.new((lo + hi) / 2), color, mat, extra)
end

-- an upright cylinder standing on `at` (Roblox cylinders run along X: turn it up)
local function can(
	parent: Instance,
	name: string,
	at: Vector3,
	height: number,
	d: number,
	color: Color3,
	mat: Enum.Material?
): Part
	return p(
		parent,
		name,
		Vector3.new(height, d, d),
		CFrame.new(at + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		mat or Enum.Material.Metal,
		{ Shape = Enum.PartType.Cylinder, CanCollide = false }
	)
end

local function poster(parent: Instance, cf: CFrame, text: string, bg: Color3, fg: Color3)
	Props.poster(parent, cf, text, bg, fg)
end

-- a fake window on a wall: glowing frosted glass, a steel frame, bars and a sill. cf = the wall
-- surface at the window's center, -Z pointing into the room.
local function window(parent: Instance, cf: CFrame, w: number, h: number)
	local glass = p(
		parent,
		"SkyWindow",
		Vector3.new(w, h, 0.2),
		cf * CFrame.new(0, 0, -0.12),
		Color3.fromRGB(214, 226, 238),
		Enum.Material.Glass,
		{
			Transparency = 0.1,
			CanCollide = false,
		}
	)
	CollectionService:AddTag(glass, "SkyWindow")
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Front
	light.Angle = 80
	light.Range = 26
	light.Brightness = 1.1
	light.Color = Color3.fromRGB(220, 230, 240)
	light.Parent = glass
	for _, s in { -1, 1 } do
		p(
			parent,
			"WindowFrame",
			Vector3.new(0.4, h + 0.8, 0.5),
			cf * CFrame.new(s * (w / 2 + 0.2), 0, -0.25),
			STEEL,
			Enum.Material.Metal
		)
	end
	p(
		parent,
		"WindowFrame",
		Vector3.new(w, 0.4, 0.5),
		cf * CFrame.new(0, h / 2 + 0.2, -0.25),
		STEEL,
		Enum.Material.Metal
	)
	p(
		parent,
		"WindowSill",
		Vector3.new(w + 1.2, 0.35, 0.8),
		cf * CFrame.new(0, -h / 2 - 0.18, -0.52), -- (off the wall: the frame's back face is there)
		STEEL,
		Enum.Material.Concrete
	)
	local bars = math.max(2, math.floor(w / 1.6))
	for k = 1, bars do
		local x = -w / 2 + k * w / (bars + 1)
		p(
			parent,
			"WindowBar",
			Vector3.new(0.18, h, 0.18),
			cf * CFrame.new(x, 0, -0.62),
			DARK,
			Enum.Material.Metal,
			{ CanCollide = false }
		)
	end
	p(
		parent,
		"WindowBar",
		Vector3.new(w, 0.18, 0.18),
		cf * CFrame.new(0, 0, -0.66),
		DARK,
		Enum.Material.Metal,
		{ CanCollide = false }
	)
end

local function fan(parent: Instance, at: Vector3, ceiling: number)
	local m = Instance.new("Model")
	m.Name = "CeilingFan"
	p(
		m,
		"FanRod",
		Vector3.new(0.2, ceiling - at.Y, 0.2),
		CFrame.new(at.X, (ceiling + at.Y) / 2, at.Z),
		STEEL,
		Enum.Material.Metal,
		{ CanCollide = false }
	)
	local hub = p(
		m,
		"FanHub",
		Vector3.new(0.6, 1.1, 1.1),
		CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2),
		DARK,
		Enum.Material.Metal,
		{
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
		}
	)
	for k = 0, 3 do
		local a = k * math.pi / 2
		p(
			m,
			"FanBlade",
			Vector3.new(4.4, 0.08, 0.9),
			CFrame.new(at) * CFrame.Angles(0, a, 0) * CFrame.new(2.6, -0.1, 0) * CFrame.Angles(0.12, 0, 0),
			Color3.fromRGB(150, 120, 86),
			Enum.Material.Wood,
			{
				CanCollide = false,
			}
		)
	end
	m.PrimaryPart = hub
	m.Parent = parent
	CollectionService:AddTag(m, "CeilingFan")
end

local function drain(parent: Instance, at: Vector3)
	p(
		parent,
		"Drain",
		Vector3.new(0.05, 1.6, 1.6),
		CFrame.new(at + Vector3.new(0, 0.065, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(40, 42, 46),
		Enum.Material.DiamondPlate,
		{
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
		}
	)
end

local function extinguisher(parent: Instance, wallCf: CFrame)
	-- wallCf: on the wall surface, -Z into the room
	p(
		parent,
		"ExtBracket",
		Vector3.new(0.9, 0.2, 0.4),
		wallCf * CFrame.new(0, 3.9, -0.32),
		DARK,
		Enum.Material.Metal
	)
	p(
		parent,
		"Extinguisher",
		Vector3.new(2, 0.75, 0.75),
		wallCf * CFrame.new(0, 3.1, -0.55) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(196, 30, 30),
		Enum.Material.Metal,
		{
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
		}
	)
	p(
		parent,
		"ExtHose",
		Vector3.new(0.12, 1.2, 0.12),
		wallCf * CFrame.new(0.32, 3.4, -0.85),
		DARK,
		Enum.Material.Rubber,
		{ CanCollide = false }
	)
end

local function vent(parent: Instance, wallCf: CFrame)
	p(
		parent,
		"Vent",
		Vector3.new(3, 1.6, 0.15),
		wallCf * CFrame.new(0, 0, -0.08),
		Color3.fromRGB(110, 114, 118),
		Enum.Material.Metal
	)
	for k = -2, 2 do
		p(
			parent,
			"VentSlat",
			Vector3.new(2.6, 0.12, 0.2),
			wallCf * CFrame.new(0, k * 0.28, -0.22),
			DARK,
			Enum.Material.Metal,
			{ CanCollide = false }
		)
	end
end

local function mopBucket(parent: Instance, at: Vector3)
	can(parent, "MopBucket", at, 1.4, 1.5, Color3.fromRGB(230, 190, 40), Enum.Material.SmoothPlastic)
	can(
		parent,
		"MopWater",
		at + Vector3.new(0, 1.1, 0),
		0.2,
		1.3,
		Color3.fromRGB(110, 120, 100),
		Enum.Material.Glass
	)
	p(
		parent,
		"MopStick",
		Vector3.new(0.15, 5, 0.15),
		CFrame.new(at + Vector3.new(0.3, 2.9, 0)) * CFrame.Angles(0, 0, 0.18),
		Color3.fromRGB(150, 110, 70),
		Enum.Material.Wood,
		{ CanCollide = false }
	)
	-- the yellow A-frame sign next to it
	local sign = at + Vector3.new(2.6, 0, 0.4)
	for _, s in { -1, 1 } do
		local part = p(
			parent,
			"WetFloor",
			Vector3.new(1.4, 2.4, 0.08),
			CFrame.new(sign + Vector3.new(0, 1.15, s * 0.32)) * CFrame.Angles(s * 0.27, 0, 0),
			Color3.fromRGB(240, 200, 40),
			Enum.Material.SmoothPlastic,
			{
				CanCollide = false,
			}
		)
		Build.sign(
			part,
			if s > 0 then Enum.NormalId.Back else Enum.NormalId.Front,
			"CAUTION\nWET FLOOR",
			Color3.fromRGB(30, 30, 30),
			Color3.fromRGB(240, 200, 40)
		)
	end
end

local function tray(parent: Instance, at: Vector3, flip: boolean)
	local trayColors =
		{ Color3.fromRGB(196, 120, 60), Color3.fromRGB(120, 140, 150), Color3.fromRGB(150, 160, 90) }
	local c = trayColors[(math.floor(at.X * 7 + at.Z * 3) % 3) + 1]
	p(
		parent,
		"Tray",
		Vector3.new(2.2, 0.12, 1.5),
		CFrame.new(at + Vector3.new(0, 0.06, 0)),
		c,
		Enum.Material.SmoothPlastic,
		{ CanCollide = false }
	)
	local s = if flip then -1 else 1
	can(
		parent,
		"Bowl",
		at + Vector3.new(-0.45 * s, 0.12, 0),
		0.38,
		0.95,
		Color3.fromRGB(230, 230, 226),
		Enum.Material.SmoothPlastic
	)
	can(
		parent,
		"Slop",
		at + Vector3.new(-0.45 * s, 0.3, 0),
		0.12,
		0.8,
		Color3.fromRGB(150, 140, 110),
		Enum.Material.Sand
	)
	can(
		parent,
		"Cup",
		at + Vector3.new(0.55 * s, 0.12, 0.35),
		0.55,
		0.42,
		Color3.fromRGB(235, 236, 240),
		Enum.Material.SmoothPlastic
	)
	p(
		parent,
		"Bread",
		Vector3.new(0.6, 0.25, 0.4),
		CFrame.new(at + Vector3.new(0.5 * s, 0.245, -0.3)),
		Color3.fromRGB(200, 160, 100),
		Enum.Material.Sand,
		{ CanCollide = false }
	)
end

-- ===== Mess Hall =====

function Interior.messHall(common: Instance)
	local d = Instance.new("Folder")
	d.Name = "MessDressing"
	d.Parent = common
	local cr = World.CommonRoom
	local x0, x1 = cr.x - cr.sx / 2, cr.x + cr.sx / 2 - 4
	local z0 = cr.z + cr.sz / 2 + 4
	local z1 = z0 + 56
	local h = 22
	local cx = cr.x
	-- quarry-tile floor (terracotta / cream checks)
	local A, B = Color3.fromRGB(168, 96, 70), Color3.fromRGB(206, 192, 164)
	for ix = 0, 13 do
		for iz = 0, 6 do
			p(
				d,
				"Tile",
				Vector3.new(8, 0.04, 8),
				CFrame.new(x0 + 2 + 4 + ix * 8, 0.02, z0 + 4 + iz * 8),
				if (ix + iz) % 2 == 0 then A else B,
				Enum.Material.Slate
			)
		end
	end
	-- painted lower walls + a trim line (the back wall already has its paint)
	box(d, "Paint", Vector3.new(x0, 0, z0), Vector3.new(x0 + 0.1, 6, z1 - 0.1), PAINT)
	box(d, "Paint", Vector3.new(x1 - 0.1, 0, z0), Vector3.new(x1, 6, z1 - 0.1), PAINT)
	box(d, "Paint", Vector3.new(x0 + 0.1, 0, z0), Vector3.new(cx - 6, 6, z0 + 0.1), PAINT)
	box(d, "Paint", Vector3.new(cx + 6, 0, z0), Vector3.new(x1 - 0.1, 6, z0 + 0.1), PAINT)
	box(d, "Trim", Vector3.new(x0, 6, z0), Vector3.new(x0 + 0.2, 6.3, z1 - 0.2), TRIM, Enum.Material.Metal)
	box(d, "Trim", Vector3.new(x1 - 0.2, 6, z0), Vector3.new(x1, 6.3, z1 - 0.2), TRIM, Enum.Material.Metal)
	box(d, "Trim", Vector3.new(x0, 6, z1 - 0.2), Vector3.new(x1, 6.3, z1), TRIM, Enum.Material.Metal)
	box(
		d,
		"Trim",
		Vector3.new(x0 + 0.2, 6, z0),
		Vector3.new(cx - 6, 6.3, z0 + 0.2),
		TRIM,
		Enum.Material.Metal
	)
	box(
		d,
		"Trim",
		Vector3.new(cx + 6, 6, z0),
		Vector3.new(x1 - 0.2, 6.3, z0 + 0.2),
		TRIM,
		Enum.Material.Metal
	)
	-- barred daylight windows: back wall (clear of the menu board), both side walls
	for _, x in { cx - 46, cx - 28, cx + 28, cx + 46 } do
		window(d, CFrame.new(x, 15, z1), 7, 6)
	end
	-- (a wall frame's -Z must point into the room: west wall -90°, east wall +90°)
	window(d, CFrame.new(x0, 15, z0 + 8) * CFrame.Angles(0, -math.pi / 2, 0), 7, 6)
	for _, z in { z0 + 10, z0 + 24, z0 + 38 } do
		window(d, CFrame.new(x1, 15, z) * CFrame.Angles(0, math.pi / 2, 0), 7, 6)
	end
	-- ceiling fans + pipes
	for _, x in { cx - 34, cx, cx + 34 } do
		for _, z in { z0 + 14, z0 + 38 } do
			fan(d, Vector3.new(x, h - 3, z), h)
		end
	end
	for _, z in { z0 + 1, z1 - 1 } do
		p(
			d,
			"Pipe",
			Vector3.new(x1 - x0 - 2, 1, 1),
			CFrame.new((x0 + x1) / 2, h - 1.2, z),
			Color3.fromRGB(96, 102, 108),
			Enum.Material.Metal,
			{
				Shape = Enum.PartType.Cylinder,
				CanCollide = false,
			}
		)
	end
	-- trays of slop on every table (tables: WorldBuilder.buildMessHall)
	for row = 0, 2 do
		for col = 0, 1 do
			local tx = cx - 24 + col * 48
			local tz = z0 + 10 + row * 12
			for k, dx in { -10, -4, 3, 9 } do
				local side = if k % 2 == 0 then 1 else -1
				tray(d, Vector3.new(tx + dx, 3.3, tz + side * 1.1), side < 0)
			end
		end
	end
	-- the tray rack at the start of the line
	local rx, rz = cx - 26, z1 - 8
	for _, s in { -1, 1 } do
		p(
			d,
			"RackPost",
			Vector3.new(0.25, 6, 0.25),
			CFrame.new(rx + s * 1.6, 3, rz - 1.1),
			STEEL,
			Enum.Material.Metal
		)
		p(
			d,
			"RackPost",
			Vector3.new(0.25, 6, 0.25),
			CFrame.new(rx + s * 1.6, 3, rz + 1.1),
			STEEL,
			Enum.Material.Metal
		)
	end
	for k = 0, 3 do
		local y = 1 + k * 1.5
		p(d, "RackShelf", Vector3.new(3, 0.12, 2.2), CFrame.new(rx, y, rz), STEEL, Enum.Material.DiamondPlate)
		for n = 0, 3 do
			p(
				d,
				"Tray",
				Vector3.new(2.2, 0.1, 1.5),
				CFrame.new(rx, y + 0.11 + n * 0.11, rz),
				Color3.fromRGB(196, 120, 60),
				Enum.Material.SmoothPlastic,
				{ CanCollide = false }
			)
		end
	end
	-- kitchen behind the counter: fridge, stove with pots, shelves of cans
	p(
		d,
		"Fridge",
		Vector3.new(3.6, 8, 2.6),
		CFrame.new(cx - 16, 4, z1 - 1.5),
		Color3.fromRGB(220, 222, 226),
		Enum.Material.Metal
	)
	p(
		d,
		"FridgeHandle",
		Vector3.new(0.2, 2.4, 0.2),
		CFrame.new(cx - 14.6, 4.6, z1 - 2.95),
		STEEL,
		Enum.Material.Metal
	)
	p(
		d,
		"Stove",
		Vector3.new(6, 3.4, 2.6),
		CFrame.new(cx + 16, 1.7, z1 - 1.5),
		Color3.fromRGB(60, 62, 66),
		Enum.Material.DiamondPlate
	)
	local steamPots = {}
	for _, dx in { -1.5, 1.5 } do
		table.insert(
			steamPots,
			can(
				d,
				"StovePot",
				Vector3.new(cx + 16 + dx, 3.4, z1 - 1.5),
				1.4,
				1.6,
				Color3.fromRGB(150, 152, 158)
			)
		)
	end
	for _, side in { -1, 1 } do
		local sx = cx + side * 30
		for k = 0, 1 do
			local y = 5 + k * 2.6
			p(
				d,
				"Shelf",
				Vector3.new(12, 0.2, 1.2),
				CFrame.new(sx, y, z1 - 0.7),
				Color3.fromRGB(120, 92, 62),
				Enum.Material.WoodPlanks
			)
			for n = 0, 7 do
				local colors = {
					Color3.fromRGB(190, 60, 40),
					Color3.fromRGB(220, 190, 60),
					Color3.fromRGB(70, 120, 60),
					Color3.fromRGB(200, 200, 205),
				}
				can(
					d,
					"Can",
					Vector3.new(sx - 5 + n * 1.4, y + 0.1, z1 - 0.7),
					1,
					0.7,
					colors[(n + k) % 4 + 1]
				)
			end
		end
	end
	-- steam from the pots on the counter and the stove
	for _, part in common:GetChildren() do
		if part:IsA("BasePart") and part.Name == "Pot" and part.Position.Z > z0 then
			table.insert(steamPots, part)
		end
	end
	for _, pot in steamPots do
		local a = Instance.new("Attachment")
		a.Parent = pot
		a.WorldPosition = pot.Position + Vector3.new(0, 0.9, 0)
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Rate = 3
		e.Lifetime = NumberRange.new(1.6, 2.6)
		e.Speed = NumberRange.new(1.5, 2.5)
		e.SpreadAngle = Vector2.new(12, 12)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, 0.6, 0)
		e.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.6) })
		e.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(Color3.fromRGB(240, 240, 240))
		e.LightInfluence = 1
		e.Parent = a
	end
	-- trash cans by the door, a mop bucket, drains
	for _, s in { -1, 1 } do
		can(d, "TrashCan", Vector3.new(cx + s * 14, 0, z0 + 3), 3, 2.2, Color3.fromRGB(46, 70, 52))
		can(d, "TrashLid", Vector3.new(cx + s * 14, 3, z0 + 3), 0.3, 2.4, Color3.fromRGB(36, 54, 40))
	end
	mopBucket(d, Vector3.new(cx + 5, 0, z0 + 30))
	drain(d, Vector3.new(cx, 0, z0 + 16))
	drain(d, Vector3.new(cx, 0, z0 + 40))
	-- posters, a clock, vents
	poster(
		d,
		CFrame.new(cx - 34, 9, z0 + 0.18) * CFrame.Angles(0, math.pi, 0),
		"NO SECONDS",
		Color3.fromRGB(190, 40, 40),
		Color3.new(1, 1, 1)
	)
	poster(
		d,
		CFrame.new(cx + 34, 9, z0 + 0.18) * CFrame.Angles(0, math.pi, 0),
		"TRAYS GO BACK ON THE RACK",
		Color3.fromRGB(40, 70, 130),
		Color3.new(1, 1, 1)
	)
	poster(
		d,
		CFrame.new(x0 + 0.18, 9, z0 + 40) * CFrame.Angles(0, -math.pi / 2, 0),
		"MYSTERY MEAT MONDAY",
		Color3.fromRGB(230, 200, 60),
		Color3.fromRGB(30, 30, 30)
	)
	poster(
		d,
		CFrame.new(x1 - 0.18, 9, z0 + 17) * CFrame.Angles(0, math.pi / 2, 0),
		"WASH YOUR HANDS (PLEASE)",
		Color3.fromRGB(60, 130, 90),
		Color3.new(1, 1, 1)
	)
	poster(
		d,
		CFrame.new(x1 - 0.18, 9, z0 + 31) * CFrame.Angles(0, math.pi / 2, 0),
		"TODAY: GRAY",
		Color3.fromRGB(110, 110, 116),
		Color3.new(1, 1, 1)
	)
	local clockCf = CFrame.new(x1 - 0.3, 15, z0 + 50) * CFrame.Angles(0, math.pi / 2, 0)
	p(
		d,
		"ClockFace",
		Vector3.new(0.3, 4, 4),
		clockCf * CFrame.Angles(0, math.pi / 2, 0),
		Color3.fromRGB(235, 232, 220),
		Enum.Material.SmoothPlastic,
		{
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
		}
	)
	p(d, "ClockHand", Vector3.new(0.15, 1.5, 0.08), clockCf * CFrame.new(0, 0.6, -0.2), DARK)
	p(
		d,
		"ClockHand",
		Vector3.new(0.15, 1.1, 0.08),
		clockCf * CFrame.new(0.4, -0.15, -0.22) * CFrame.Angles(0, 0, math.rad(-70)),
		DARK
	)
	for _, z in { z0 + 4, z0 + 46 } do
		vent(d, CFrame.new(x0, 19, z) * CFrame.Angles(0, -math.pi / 2, 0))
	end
	extinguisher(d, CFrame.new(x1, 0, z0 + 4) * CFrame.Angles(0, math.pi / 2, 0))
	extinguisher(d, CFrame.new(x0, 0, z0 + 52) * CFrame.Angles(0, -math.pi / 2, 0))
	-- a guard keeping an eye on the line
	Build.npc(
		d,
		"MessGuard",
		CFrame.new(cx - 9, 0, z0 + 3) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(40, 60, 110),
		Color3.fromRGB(20, 30, 60)
	)
end

-- ===== Common Room extras =====

function Interior.commonRoom(common: Instance)
	local d = Instance.new("Folder")
	d.Name = "CommonDetails"
	d.Parent = common
	local cr = World.CommonRoom
	local x0 = cr.x - cr.sx / 2
	local x1 = cr.x + cr.sx / 2 - 2 -- inner face of the east wall
	local z0, z1 = cr.z - cr.sz / 2, cr.z + cr.sz / 2
	-- notice board on the north wall: cork with pinned notes
	local boardCf = CFrame.new(cr.x - 2, 8, z0) * CFrame.Angles(0, math.pi, 0)
	-- (clear of the painted wall band: its back face sits in the wall plane too)
	p(
		d,
		"NoticeFrame",
		Vector3.new(9, 5.4, 0.2),
		boardCf * CFrame.new(0, 0, -0.22),
		Color3.fromRGB(110, 78, 50),
		Enum.Material.Wood
	)
	p(
		d,
		"NoticeCork",
		Vector3.new(8.4, 4.8, 0.1),
		boardCf * CFrame.new(0, 0, -0.37),
		Color3.fromRGB(176, 130, 84),
		Enum.Material.Sand
	)
	local notes = {
		{ -2.8, 1.2, "LOST: SPOON" },
		{ 0, 1.4, "CHESS CLUB\nTUESDAYS" },
		{ 2.6, 1, "NO RUNNING" },
		{ -2.4, -1.1, "LAUNDRY\nTHURSDAY" },
		{ 0.6, -1.2, "MISSING: 1 WALL" },
		{ 2.9, -1.4, "THANKS\n- WARDEN" },
	}
	for k, n in notes do
		local note = p(
			d,
			"Note",
			Vector3.new(2.2, 1.6, 0.04),
			boardCf * CFrame.new(n[1], n[2], -0.44) * CFrame.Angles(0, 0, (k % 3 - 1) * 0.08),
			if k % 2 == 0 then Color3.fromRGB(250, 246, 220) else Color3.fromRGB(250, 236, 150),
			Enum.Material.SmoothPlastic,
			{
				CanCollide = false,
			}
		)
		Build.sign(note, Enum.NormalId.Front, n[3], Color3.fromRGB(40, 40, 50), Color3.fromRGB(250, 246, 220))
		p(
			d,
			"Pin",
			Vector3.new(0.18, 0.18, 0.18),
			boardCf * CFrame.new(n[1], n[2] + 0.62, -0.5),
			Color3.fromRGB(220, 40, 40),
			Enum.Material.SmoothPlastic,
			{
				Shape = Enum.PartType.Ball,
				CanCollide = false,
			}
		)
	end
	-- a water fountain on the west wall
	local fcf = CFrame.new(x0, 0, -40) * CFrame.Angles(0, -math.pi / 2, 0)
	p(
		d,
		"Fountain",
		Vector3.new(2.4, 1, 1.6),
		fcf * CFrame.new(0, 3.2, -0.8),
		Color3.fromRGB(200, 204, 210),
		Enum.Material.Metal
	)
	p(
		d,
		"FountainPipe",
		Vector3.new(0.3, 2.7, 0.3),
		fcf * CFrame.new(0, 1.35, -0.4),
		STEEL,
		Enum.Material.Metal
	)
	p(
		d,
		"FountainSpout",
		Vector3.new(0.2, 0.3, 0.2),
		fcf * CFrame.new(0.5, 3.85, -1),
		STEEL,
		Enum.Material.Metal,
		{ CanCollide = false }
	)
	-- fire extinguishers, vents, drains, a mop bucket by the Mess Hall door
	extinguisher(d, CFrame.new(x0, 0, -20) * CFrame.Angles(0, -math.pi / 2, 0))
	extinguisher(d, CFrame.new(x1, 0, -42) * CFrame.Angles(0, math.pi / 2, 0))
	for _, x in { x0 + 50, x0 + 80 } do
		vent(d, CFrame.new(x, 19.5, z0) * CFrame.Angles(0, math.pi, 0))
	end
	drain(d, Vector3.new(cr.x, 0.04, 20))
	drain(d, Vector3.new(cr.x + 30, 0.04, -12))
	mopBucket(d, Vector3.new(cr.x - 14, 0.04, z1 - 4))
end

-- ===== grime: soft dark bands where walls meet the floor and the ceiling, and darker floor edges
-- (a cheap ambient-occlusion look that gives every room depth) =====

local function band(parent: Instance, fromTop: boolean, height: number, alpha: number)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
	f.AnchorPoint = Vector2.new(0, if fromTop then 0 else 1)
	f.Position = UDim2.fromScale(0, if fromTop then 0 else 1)
	f.Size = UDim2.fromScale(1, height)
	f.Parent = parent
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = if fromTop
		then NumberSequence.new({ NumberSequenceKeypoint.new(0, alpha), NumberSequenceKeypoint.new(1, 1) })
		else NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, alpha),
		})
	g.Parent = f
end

local function wallGrime(wall: BasePart)
	local size = wall.Size
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local width = if face == Enum.NormalId.Front or face == Enum.NormalId.Back then size.X else size.Z
		if width >= 3 then
			local gui = Instance.new("SurfaceGui")
			gui.Name = "Grime"
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 6
			gui.LightInfluence = 1
			gui.Parent = wall
			band(gui, false, math.min(0.4, 3.5 / size.Y), 0.45) -- floor line
			band(gui, true, math.min(0.3, 2.5 / size.Y), 0.55) -- ceiling line
		end
	end
end

local function floorGrime(parent: Instance, floor: BasePart)
	local overlay = Instance.new("Part")
	overlay.Name = "FloorShade"
	overlay.Anchored = true
	overlay.CanCollide = false
	overlay.CanQuery = false
	overlay.CanTouch = false
	overlay.CastShadow = false
	overlay.Transparency = 1
	overlay.Size = Vector3.new(floor.Size.X, 0.02, floor.Size.Z)
	overlay.CFrame = floor.CFrame * CFrame.new(0, floor.Size.Y / 2 + 0.07, 0)
	overlay.Parent = parent
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 4
	gui.LightInfluence = 1
	gui.Parent = overlay
	local function edge(rotation: number, w: number, horizontal: boolean, pos: UDim2, anchor: Vector2)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
		f.AnchorPoint = anchor
		f.Position = pos
		f.Size = if horizontal then UDim2.new(1, 0, w, 0) else UDim2.new(w, 0, 1, 0)
		f.Parent = gui
		local g = Instance.new("UIGradient")
		g.Rotation = rotation
		g.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
	end
	local fx = math.min(0.3, 3 / floor.Size.X)
	local fz = math.min(0.3, 3 / floor.Size.Z)
	edge(0, fx, false, UDim2.fromScale(0, 0), Vector2.new(0, 0))
	edge(180, fx, false, UDim2.fromScale(1, 0), Vector2.new(1, 0))
	edge(90, fz, true, UDim2.fromScale(0, 0), Vector2.new(0, 0))
	edge(270, fz, true, UDim2.fromScale(0, 1), Vector2.new(0, 1))
end

function Interior.grime(prison: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Grime"
	folder.Parent = prison
	for _, d in prison:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.5 then
			if (d.Name == "Wall" or d.Name == "CellWall") and d.Size.Y >= 8 then
				wallGrime(d)
			elseif
				d.Name == "CommonFloor"
				or d.Name == "MessFloor"
				or d.Name == "CorridorFloor"
				or d.Name == "CellFloor"
			then
				floorGrime(folder, d)
			end
		end
	end
end

-- ===== Yard =====

local function picnicTable(parent: Instance, at: Vector3)
	local wood = Color3.fromRGB(122, 92, 62)
	p(
		parent,
		"PicnicTop",
		Vector3.new(8, 0.4, 3),
		CFrame.new(at + Vector3.new(0, 3, 0)),
		wood,
		Enum.Material.WoodPlanks
	)
	for _, dz in { -2.4, 2.4 } do
		p(
			parent,
			"PicnicBench",
			Vector3.new(8, 0.3, 1.1),
			CFrame.new(at + Vector3.new(0, 1.8, dz)),
			wood,
			Enum.Material.WoodPlanks
		)
	end
	for _, dx in { -3.2, 3.2 } do
		p(
			parent,
			"PicnicLeg",
			Vector3.new(0.4, 2.8, 5.4),
			CFrame.new(at + Vector3.new(dx, 1.4, 0)),
			STEEL,
			Enum.Material.Metal
		)
	end
end

local function patch(parent: Instance, at: Vector3, size: Vector3, yaw: number)
	p(
		parent,
		"Weeds",
		size,
		CFrame.new(at) * CFrame.Angles(0, yaw, 0),
		Color3.fromRGB(78, 104, 58),
		Enum.Material.Grass,
		{
			CanCollide = false,
		}
	)
end

function Interior.yard(prison: Instance)
	local yardFolder = prison:FindFirstChild("Yard") or prison
	local d = Instance.new("Folder")
	d.Name = "YardDetails"
	d.Parent = yardFolder
	local y = World.Yard
	local x0, x1 = y.x - y.sx / 2, y.x + y.sx / 2
	local z0, z1 = y.z - y.sz / 2, y.z + y.sz / 2
	-- picnic area between the court and the gym
	for i, x in { x0 + 16, x0 + 32, x0 + 48 } do
		picnicTable(d, Vector3.new(x, 0, 27 + (i % 2) * 4))
	end
	-- the burn barrel with benches around it (a warm light at night)
	local bx, bz = x0 + 58, z0 + 16
	can(d, "BurnBarrel", Vector3.new(bx, 0, bz), 3.2, 2.4, Color3.fromRGB(70, 50, 40))
	local fireHolder = p(
		d,
		"BurnFire",
		Vector3.new(1.6, 0.2, 1.6),
		CFrame.new(bx, 3.3, bz),
		Color3.fromRGB(40, 30, 25),
		Enum.Material.Slate,
		{
			CanCollide = false,
		}
	)
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 7
	fire.Color = Color3.fromRGB(255, 140, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 120)
	fire.Parent = fireHolder
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 150, 70)
	glow.Range = 22
	glow.Brightness = 1.4
	glow.Shadows = true
	glow.Parent = fireHolder
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2 + 0.4
		local cf = CFrame.new(bx + math.cos(a) * 6, 0, bz + math.sin(a) * 6)
			* CFrame.Angles(0, -a + math.pi / 2, 0)
		p(
			d,
			"BenchSeat",
			Vector3.new(5, 0.4, 1.6),
			cf * CFrame.new(0, 1.8, 0),
			Color3.fromRGB(110, 84, 58),
			Enum.Material.WoodPlanks
		)
		for _, dx in { -1.8, 1.8 } do
			p(
				d,
				"BenchLeg",
				Vector3.new(0.4, 1.6, 1.2),
				cf * CFrame.new(dx, 0.8, 0),
				STEEL,
				Enum.Material.Metal
			)
		end
	end
	-- the prison garden (raised bed, dirt, plants, a sign)
	local gx, gz = x1 - 46, z0 + 14
	local border = Color3.fromRGB(110, 80, 52)
	box(
		d,
		"GardenEdge",
		Vector3.new(gx - 9, 0, gz - 6),
		Vector3.new(gx + 9, 1, gz - 5.4),
		border,
		Enum.Material.Wood
	)
	box(
		d,
		"GardenEdge",
		Vector3.new(gx - 9, 0, gz + 5.4),
		Vector3.new(gx + 9, 1, gz + 6),
		border,
		Enum.Material.Wood
	)
	box(
		d,
		"GardenEdge",
		Vector3.new(gx - 9, 0, gz - 5.4),
		Vector3.new(gx - 8.4, 1, gz + 5.4),
		border,
		Enum.Material.Wood
	)
	box(
		d,
		"GardenEdge",
		Vector3.new(gx + 8.4, 0, gz - 5.4),
		Vector3.new(gx + 9, 1, gz + 5.4),
		border,
		Enum.Material.Wood
	)
	box(
		d,
		"GardenDirt",
		Vector3.new(gx - 8.4, 0, gz - 5.4),
		Vector3.new(gx + 8.4, 0.8, gz + 5.4),
		Color3.fromRGB(78, 56, 40),
		Enum.Material.Ground
	)
	for ix = 0, 5 do
		for iz = 0, 2 do
			local px, pz = gx - 6.5 + ix * 2.6, gz - 3.4 + iz * 3.4
			Props.bush(d, Vector3.new(px, 1.4, pz), 1.5)
			if (ix + iz) % 2 == 0 then
				p(
					d,
					"Tomato",
					Vector3.new(0.4, 0.4, 0.4),
					CFrame.new(px + 0.5, 1.75, pz + 0.55),
					Color3.fromRGB(210, 40, 30),
					Enum.Material.SmoothPlastic,
					{
						Shape = Enum.PartType.Ball,
						CanCollide = false,
					}
				)
			end
		end
	end
	local gardenSign = p(
		d,
		"GardenSign",
		Vector3.new(6, 2, 0.2),
		CFrame.new(gx, 2.6, gz - 6.8),
		Color3.fromRGB(230, 222, 196),
		Enum.Material.Wood
	)
	Build.sign(
		gardenSign,
		Enum.NormalId.Back,
		"PRISON GARDEN\nDO NOT DIG HERE",
		Color3.fromRGB(60, 40, 30),
		Color3.fromRGB(230, 222, 196)
	)
	p(
		d,
		"GardenSignPost",
		Vector3.new(0.3, 2, 0.3),
		CFrame.new(gx, 0.8, gz - 6.8),
		border,
		Enum.Material.Wood
	)
	can(d, "WateringCan", Vector3.new(gx + 10.5, 0, gz - 3), 1, 1, Color3.fromRGB(70, 140, 90))
	-- laundry line with orange jumpsuits drying
	local lx0, lx1, lz = x0 + 20, x0 + 44, z0 + 8
	for _, x in { lx0, lx1 } do
		p(d, "LinePole", Vector3.new(0.4, 8, 0.4), CFrame.new(x, 4, lz), STEEL, Enum.Material.Metal)
	end
	p(
		d,
		"Line",
		Vector3.new(lx1 - lx0, 0.08, 0.08),
		CFrame.new((lx0 + lx1) / 2, 7.6, lz),
		Color3.fromRGB(220, 220, 214),
		Enum.Material.Fabric,
		{
			CanCollide = false,
		}
	)
	for k = 0, 4 do
		local x = lx0 + 3.5 + k * 4.2
		local c = if k == 2 then Color3.fromRGB(70, 90, 130) else Color3.fromRGB(214, 104, 34)
		p(
			d,
			"Jumpsuit",
			Vector3.new(2.2, 2.2, 0.1),
			CFrame.new(x, 6.5, lz),
			c,
			Enum.Material.Fabric,
			{ CanCollide = false }
		)
		for _, dx in { -0.55, 0.55 } do
			p(
				d,
				"JumpsuitLeg",
				Vector3.new(0.9, 1.8, 0.1),
				CFrame.new(x + dx, 4.5, lz),
				c,
				Enum.Material.Fabric,
				{ CanCollide = false }
			)
		end
	end
	-- a payphone on the west fence
	local phone = CFrame.new(x0 + 3, 0, 34) * CFrame.Angles(0, -math.pi / 2, 0)
	p(
		d,
		"PhoneBooth",
		Vector3.new(3, 7, 0.3),
		phone * CFrame.new(0, 3.5, 0),
		Color3.fromRGB(60, 64, 70),
		Enum.Material.Metal
	)
	p(
		d,
		"PhoneHood",
		Vector3.new(3.2, 0.3, 1.6),
		phone * CFrame.new(0, 7, -0.7),
		Color3.fromRGB(60, 64, 70),
		Enum.Material.Metal
	)
	p(
		d,
		"Phone",
		Vector3.new(1, 1.6, 0.5),
		phone * CFrame.new(0, 4.4, -0.35),
		Color3.fromRGB(30, 30, 34),
		Enum.Material.SmoothPlastic
	)
	local phoneSign = p(
		d,
		"PhoneSign",
		Vector3.new(2.6, 0.8, 0.05),
		phone * CFrame.new(0, 6.2, -0.2),
		Color3.fromRGB(40, 90, 160)
	)
	Build.sign(
		phoneSign,
		Enum.NormalId.Front,
		"COLLECT CALLS ONLY",
		Color3.new(1, 1, 1),
		Color3.fromRGB(40, 90, 160)
	)
	-- tires and cones by the court
	for k = 0, 2 do
		can(
			d,
			"Tire",
			Vector3.new(x0 + 15, k * 0.9, -30),
			0.9,
			2.6,
			Color3.fromRGB(30, 30, 32),
			Enum.Material.Rubber
		)
	end
	can(
		d,
		"Tire",
		Vector3.new(x0 + 18.5, 0, -27.5),
		0.9,
		2.6,
		Color3.fromRGB(30, 30, 32),
		Enum.Material.Rubber
	)
	for k = 0, 4 do
		local cx = x0 + 40 + k * 6
		p(
			d,
			"Cone",
			Vector3.new(0.9, 1.6, 0.9),
			CFrame.new(cx, 0.8, -22),
			Color3.fromRGB(240, 120, 30),
			Enum.Material.SmoothPlastic,
			{
				CanCollide = false,
			}
		)
		p(
			d,
			"ConeStripe",
			Vector3.new(0.95, 0.25, 0.95),
			CFrame.new(cx, 1.05, -22),
			Color3.fromRGB(240, 240, 240),
			Enum.Material.SmoothPlastic,
			{
				CanCollide = false,
			}
		)
	end
	-- the painted "RUBBLE DUMP" box on the ground
	local mark = p(
		d,
		"DumpMark",
		Vector3.new(14, 0.04, 4),
		CFrame.new(x1 - 22, 0.03, -20),
		Color3.fromRGB(70, 70, 74),
		Enum.Material.Pavement,
		{
			CanCollide = false,
		}
	)
	Build.sign(
		mark,
		Enum.NormalId.Top,
		"RUBBLE DUMP ▼",
		Color3.fromRGB(235, 200, 60),
		Color3.fromRGB(70, 70, 74)
	)
	-- trees in planters along the fences
	for k, pos in
		{
			Vector3.new(x0 + 8, 0, z0 + 56),
			Vector3.new(x0 + 8, 0, 4),
			Vector3.new(x0 + 70, 0, z0 + 4),
			Vector3.new(x0 + 104, 0, z0 + 4),
			Vector3.new(x1 - 14, 0, z0 + 30),
		}
	do
		Props.tree(d, pos, 13 + (k % 3) * 2, k)
	end
	-- weeds along the edges
	local spots = {
		{ x0 + 4, z0 + 4, 10, 4, 0.3 },
		{ x0 + 30, z0 + 3, 14, 3, -0.1 },
		{ x0 + 80, z0 + 3, 9, 3, 0.2 },
		{ x0 + 3, -50, 4, 12, 0 },
		{ x0 + 3, 60, 4, 10, 0.1 },
		{ x1 - 60, z1 - 4, 12, 4, -0.2 },
		{ x0 + 70, 20, 6, 4, 0.6 },
		{ x0 + 110, -60, 8, 5, -0.4 },
	}
	for _, sp in spots do
		patch(d, Vector3.new(sp[1], 0.03, sp[2]), Vector3.new(sp[3], 0.06, sp[4]), sp[5])
	end
end

return Interior
