--!strict
-- Builds THE BREAKOUT course (Shared/Breakout has the layout and the rules) far above the prison:
-- a dripping sewer with gaps over the water, a rusty ladder up a manhole, the outer yard under
-- three guard towers, the perimeter wall with razor wire, and the road where the getaway car
-- waits with its engine running. Everything is anchored; nothing moves on the server (the
-- searchlights are drawn by the client from the same shared math the server checks).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Rules = require(Shared.Breakout)
local Config = require(Shared.Config.Breakout)

local Build = require(script.Parent.Build)
local Props = require(script.Parent.Props)

local Course = {}

local O = Vector3.new(Config.Origin.x, Config.Origin.y, Config.Origin.z)
local Y = Rules.YardY
local TOP = Rules.WallTopY
local HW = Rules.HalfWidth

local BRICK = Color3.fromRGB(74, 70, 62)
local SLUDGE = Color3.fromRGB(56, 74, 50)
local CONCRETE = Color3.fromRGB(112, 112, 106)
local DARK = Color3.fromRGB(34, 34, 38)
local RUST = Color3.fromRGB(122, 74, 44)
local GRASS = Color3.fromRGB(46, 58, 40)
local DIRT = Color3.fromRGB(70, 60, 48)

-- an axis-aligned box from two local corners
local function box(parent: Instance, name: string, a: Vector3, b: Vector3, color: Color3, props: any?): Part
	return Build.box(parent, name, O + a, O + b, color, props)
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(O + Vector3.new(x, y, z))
end

local function invisibleWall(parent: Instance, a: Vector3, b: Vector3)
	box(parent, "Boundary", a, b, Color3.new(), { Transparency = 1, CastShadow = false })
end

local function sewer(m: Model)
	local brick = { Material = Enum.Material.Brick }
	-- the channel: walls, ceiling, a murky stream you can't stand in, a catch floor below
	box(m, "SewerWall", Vector3.new(0, -11, -7), Vector3.new(96, 12, -6), BRICK, brick)
	box(m, "SewerWall", Vector3.new(0, -11, 6), Vector3.new(96, 12, 7), BRICK, brick)
	box(m, "SewerCeiling", Vector3.new(-1, 12, -7), Vector3.new(86, 13, 7), BRICK:Lerp(DARK, 0.3), brick)
	box(m, "SewerStart", Vector3.new(-1, -11, -6), Vector3.new(0, 12, 6), BRICK:Lerp(DARK, 0.2), brick)
	box(m, "SewerEnd", Vector3.new(96, -11, -7), Vector3.new(97, 13, 7), BRICK:Lerp(DARK, 0.2), brick)
	box(m, "Water", Vector3.new(0, -4, -6), Vector3.new(96, -3, 6), SLUDGE, {
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		CanCollide = false,
	})
	box(m, "Sludge", Vector3.new(0, -11, -6), Vector3.new(96, -10, 6), SLUDGE:Lerp(DARK, 0.5), {
		Material = Enum.Material.Slate,
	})
	-- the walkways (the gaps between them are the jumps)
	for i, w in Rules.Walkways do
		box(
			m,
			"Walkway" .. i,
			Vector3.new(w[1], -1, -6),
			Vector3.new(w[2], 0, 6),
			CONCRETE:Lerp(DARK, 0.25),
			{
				Material = Enum.Material.Concrete,
			}
		)
		-- yellow hazard edges where the walkway ends over the water
		for _, x in { w[1], w[2] } do
			if x > 0 and x < 96 then
				local x0 = if x == w[1] then x else x - 0.6
				box(
					m,
					"Hazard",
					Vector3.new(x0, 0.01, -6),
					Vector3.new(x0 + 0.6, 0.06, 6),
					Color3.fromRGB(230, 180, 40),
					{
						Material = Enum.Material.SmoothPlastic,
						CanCollide = false,
					}
				)
			end
		end
	end
	-- pipes along both walls, dripping lamps under the ceiling
	for _, z in { -5.3, 5.3 } do
		Build.part(m, "Pipe", Vector3.new(86, 1.2, 1.2), at(43, 9.5, z), RUST, {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.CorrodedMetal,
		})
		Build.part(m, "Pipe", Vector3.new(86, 0.7, 0.7), at(43, 7.6, z * 1.04), DARK, {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Metal,
		})
	end
	for x = 8, 80, 16 do
		local lamp = Build.part(
			m,
			"SewerLamp",
			Vector3.new(1.4, 0.4, 1.4),
			at(x, 11.8, 0),
			Color3.fromRGB(200, 220, 140),
			{
				Material = Enum.Material.Neon,
			}
		)
		Build.light(lamp, Color3.fromRGB(170, 210, 120), 22, 0.9)
	end
	-- the grate you crawl out of, and the outflow sign
	for z = -5, 5, 1.25 do
		Build.part(
			m,
			"Grate",
			Vector3.new(0.3, 10, 0.25),
			at(0.35, 5.5, z),
			DARK,
			{ Material = Enum.Material.Metal }
		)
	end
	local sign =
		Build.part(m, "OutflowSign", Vector3.new(6, 2, 0.2), at(12, 6, 5.85), Color3.fromRGB(30, 60, 40))
	Build.sign(sign, Enum.NormalId.Front, "OUTFLOW 7 →", Color3.fromRGB(230, 230, 210))
	-- the ladder up the manhole (TrussParts are climbable on phones too)
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Anchored = true
	ladder.Size = Vector3.new(2, 16, 2)
	ladder.CFrame = at(95, 8, 0)
	ladder.Color = RUST
	ladder.Material = Enum.Material.CorrodedMetal
	ladder.Style = Enum.Style.AlternatingSupports
	ladder.Parent = m
	local up =
		Build.part(m, "UpSign", Vector3.new(0.2, 1.6, 4), at(95.85 - 1, 3, -4), Color3.fromRGB(230, 180, 40))
	Build.sign(up, Enum.NormalId.Left, "↑ CLIMB", Color3.fromRGB(30, 30, 30))
end

local function tower(m: Model, x: number, z: number, baseY: number?)
	local base = Vector3.new(x, baseY or Y, z)
	for _, d in { { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } } do
		Build.part(
			m,
			"TowerLeg",
			Vector3.new(0.6, 18, 0.6),
			CFrame.new(O + base + Vector3.new(d[1], 9, d[2])),
			DARK,
			{
				Material = Enum.Material.Metal,
			}
		)
	end
	Build.part(
		m,
		"TowerCabin",
		Vector3.new(6, 4, 6),
		CFrame.new(O + base + Vector3.new(0, 20, 0)),
		CONCRETE:Lerp(DARK, 0.4),
		{
			Material = Enum.Material.Concrete,
		}
	)
	Build.part(
		m,
		"TowerRoof",
		Vector3.new(7.4, 0.6, 7.4),
		CFrame.new(O + base + Vector3.new(0, 22.3, 0)),
		DARK,
		{
			Material = Enum.Material.Metal,
		}
	)
	local glass = Build.part(
		m,
		"TowerWindow",
		Vector3.new(6.1, 1.4, 6.1),
		CFrame.new(O + base + Vector3.new(0, 20.6, 0)),
		Color3.fromRGB(255, 230, 150),
		{
			Material = Enum.Material.Neon,
			Transparency = 0.35,
		}
	)
	Build.light(glass, Color3.fromRGB(255, 220, 150), 14, 0.6)
	Build.part(
		m,
		"Searchlight",
		Vector3.new(1.6, 1.6, 2.4),
		CFrame.new(O + base + Vector3.new(0, Rules.TowerHeadY, 0)),
		Color3.fromRGB(70, 70, 76),
		{
			Material = Enum.Material.Metal,
		}
	)
end

local function yard(m: Model)
	local grass = { Material = Enum.Material.Grass }
	-- the ground (with the manhole cut out of it)
	box(m, "Yard", Vector3.new(86, Y - 3, -HW), Vector3.new(90, Y, HW), GRASS, grass)
	box(m, "Yard", Vector3.new(96, Y - 3, -HW), Vector3.new(216, Y, HW), GRASS, grass)
	box(m, "Yard", Vector3.new(90, Y - 3, -HW), Vector3.new(96, Y, -3), GRASS, grass)
	box(m, "Yard", Vector3.new(90, Y - 3, 3), Vector3.new(96, Y, HW), GRASS, grass)
	-- the manhole rim and its lid pushed aside
	box(
		m,
		"ManholeRim",
		Vector3.new(89.6, Y, -3.4),
		Vector3.new(96.4, Y + 0.25, -3),
		DARK,
		{ Material = Enum.Material.Metal }
	)
	box(
		m,
		"ManholeRim",
		Vector3.new(89.6, Y, 3),
		Vector3.new(96.4, Y + 0.25, 3.4),
		DARK,
		{ Material = Enum.Material.Metal }
	)
	Build.part(
		m,
		"ManholeLid",
		Vector3.new(0.3, 5.4, 5.4),
		at(99, Y + 0.15, -6) * CFrame.Angles(0, 0, math.pi / 2),
		DARK,
		{
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.DiamondPlate,
		}
	)
	-- a worn dirt path toward the wall
	box(
		m,
		"Path",
		Vector3.new(100, Y, -2.5),
		Vector3.new(214, Y + 0.05, 2.5),
		DIRT,
		{ Material = Enum.Material.Ground, CanCollide = false }
	)
	-- the prison behind you: a dark block with a few lit windows
	box(m, "PrisonBack", Vector3.new(80, Y, -HW), Vector3.new(86, Y + 26, HW), CONCRETE:Lerp(DARK, 0.45), {
		Material = Enum.Material.Concrete,
	})
	for k = 0, 6 do
		local z = -30 + k * 10
		local lit = k % 3 ~= 1
		box(
			m,
			"Window",
			Vector3.new(86, Y + 14, z - 1.5),
			Vector3.new(86.15, Y + 17, z + 1.5),
			if lit then Color3.fromRGB(255, 220, 140) else Color3.fromRGB(30, 34, 40),
			{ Material = if lit then Enum.Material.Neon else Enum.Material.Glass }
		)
	end
	-- fences along both sides (and invisible walls so nobody wanders off the course)
	for _, z in { -HW, HW } do
		box(
			m,
			"Fence",
			Vector3.new(86, Y, z - 0.1),
			Vector3.new(216, Y + 10, z + 0.1),
			Color3.fromRGB(150, 156, 160),
			{
				Material = Enum.Material.DiamondPlate,
				Transparency = 0.55,
			}
		)
		for x = 90, 214, 12 do
			Build.part(
				m,
				"FencePost",
				Vector3.new(0.4, 11, 0.4),
				at(x, Y + 5.5, z),
				DARK,
				{ Material = Enum.Material.Metal }
			)
		end
		invisibleWall(
			m,
			Vector3.new(80, Y, z + (if z < 0 then -2 else 0.2)),
			Vector3.new(300, Y + 60, z + (if z < 0 then -0.2 else 2))
		)
	end
	-- three guard towers outside the fence, one per searchlight
	for _, t in Rules.Towers do
		tower(m, t.x, t.z)
	end
	-- cover and clutter
	local wood = { Material = Enum.Material.WoodPlanks }
	for _, c in { { 124, 10 }, { 141, -18 }, { 150, 22 }, { 168, -8 }, { 176, 26 }, { 199, 12 } } do
		box(
			m,
			"Crate",
			Vector3.new(c[1] - 2, Y, c[2] - 2),
			Vector3.new(c[1] + 2, Y + 4, c[2] + 2),
			Color3.fromRGB(122, 92, 58),
			wood
		)
	end
	for _, b in { { 136, 4 }, { 188, -20 }, { 160, -27 } } do
		Build.part(
			m,
			"Barrel",
			Vector3.new(3, 2.4, 2.4),
			at(b[1], Y + 1.5, b[2]) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(60, 80, 110),
			{
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Metal,
			}
		)
	end
	-- sandbags in front of the wall
	for z = -30, 30, 6 do
		if math.abs(z) > 4 then
			Build.part(
				m,
				"Sandbag",
				Vector3.new(2, 1.2, 4),
				at(210, Y + 0.6, z),
				Color3.fromRGB(150, 132, 96),
				{
					Material = Enum.Material.Fabric,
				}
			)
		end
	end
end

local function wall(m: Model)
	box(m, "PerimeterWall", Vector3.new(216, Y, -HW), Vector3.new(220, TOP, HW), CONCRETE, {
		Material = Enum.Material.Concrete,
	})
	local ladder = Instance.new("TrussPart")
	ladder.Name = "WallLadder"
	ladder.Anchored = true
	ladder.Size = Vector3.new(2, 24, 2)
	ladder.CFrame = at(215, Y + 12, 0)
	ladder.Color = RUST
	ladder.Material = Enum.Material.CorrodedMetal
	ladder.Style = Enum.Style.AlternatingSupports
	ladder.Parent = m
	-- razor wire on the outer edge: rings of wire
	for z = -HW + 1, HW - 1, 2 do
		Build.part(
			m,
			"RazorWire",
			Vector3.new(0.12, 1.4, 1.4),
			at(219.4, TOP + 0.7, z) * CFrame.Angles(0, math.pi / 2, 0.3),
			Color3.fromRGB(176, 180, 186),
			{
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Metal,
				Transparency = 0.15,
				CanCollide = false,
			}
		)
	end
	-- the tower on the wall's end, its light sweeps the top
	tower(m, Rules.WallTower.x, Rules.WallTower.z, TOP)
	invisibleWall(m, Vector3.new(214, TOP, -HW - 0.2), Vector3.new(222, TOP + 30, -HW))
	invisibleWall(m, Vector3.new(214, TOP, HW), Vector3.new(222, TOP + 30, HW + 0.2))
	local sign =
		Build.part(m, "WallSign", Vector3.new(0.2, 3, 10), at(215.85, Y + 6, 7), Color3.fromRGB(150, 30, 30))
	Build.sign(sign, Enum.NormalId.Left, "DANGER · NO CLIMBING", Color3.fromRGB(255, 240, 220))
end

local function outside(m: Model)
	box(m, "Outside", Vector3.new(220, Y - 3, -HW), Vector3.new(300, Y, HW), DIRT:Lerp(DARK, 0.35), {
		Material = Enum.Material.Ground,
	})
	box(m, "Road", Vector3.new(273, Y, -HW), Vector3.new(289, Y + 0.05, HW), Color3.fromRGB(44, 44, 48), {
		Material = Enum.Material.Asphalt,
		CanCollide = false,
	})
	for z = -HW + 2, HW - 4, 7 do
		box(
			m,
			"RoadLine",
			Vector3.new(280.8, Y + 0.05, z),
			Vector3.new(281.2, Y + 0.08, z + 3.5),
			Color3.fromRGB(230, 200, 60),
			{
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
			}
		)
	end
	invisibleWall(m, Vector3.new(300, Y, -HW), Vector3.new(302, Y + 60, HW))
	-- trees in the dark beyond
	local k = 0
	for _, p in { { 236, -26 }, { 250, 24 }, { 296, -12 }, { 294, 18 }, { 240, 6 } } do
		k += 1
		Props.tree(m, O + Vector3.new(p[1], Y, p[2]), 14, k)
	end
	-- a road sign: the only way is out
	Build.part(
		m,
		"SignPost",
		Vector3.new(0.3, 6, 0.3),
		at(271, Y + 3, -14),
		DARK,
		{ Material = Enum.Material.Metal }
	)
	local sign =
		Build.part(m, "RoadSign", Vector3.new(0.2, 2.4, 6), at(271, Y + 6.4, -14), Color3.fromRGB(30, 90, 50))
	Build.sign(sign, Enum.NormalId.Left, "FREEDOM  ↑", Color3.fromRGB(240, 240, 230))
	-- the getaway car, engine running, door open
	local car = Instance.new("Model")
	car.Name = "GetawayCar"
	local c = at(Rules.Car.x, Y, Rules.Car.z)
	local paint = Color3.fromRGB(150, 28, 32)
	local metal = { Material = Enum.Material.Metal }
	local body = Build.part(car, "Body", Vector3.new(6, 2.2, 13), c * CFrame.new(0, 1.9, 0), paint, metal)
	Build.part(
		car,
		"Cabin",
		Vector3.new(5.4, 2, 6.6),
		c * CFrame.new(0, 3.9, 0.6),
		paint:Lerp(DARK, 0.2),
		metal
	)
	Build.part(
		car,
		"Windshield",
		Vector3.new(5, 1.7, 0.15),
		c * CFrame.new(0, 3.9, -2.75) * CFrame.Angles(-0.35, 0, 0),
		Color3.fromRGB(40, 50, 60),
		{
			Material = Enum.Material.Glass,
			Transparency = 0.3,
		}
	)
	for _, w in { { -3, -4 }, { 3, -4 }, { -3, 4 }, { 3, 4 } } do
		Build.part(
			car,
			"Wheel",
			Vector3.new(1, 2.4, 2.4),
			c * CFrame.new(w[1], 1.25, w[2]),
			Color3.fromRGB(24, 24, 26),
			{
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Rubber,
			}
		)
	end
	for _, x in { -2.1, 2.1 } do
		local head = Build.part(
			car,
			"Headlight",
			Vector3.new(1, 0.6, 0.2),
			c * CFrame.new(x, 2.2, -6.6),
			Color3.fromRGB(255, 250, 220),
			{
				Material = Enum.Material.Neon,
			}
		)
		local beam = Instance.new("SpotLight")
		beam.Face = Enum.NormalId.Front
		beam.Range = 40
		beam.Angle = 45
		beam.Brightness = 3
		beam.Color = Color3.fromRGB(255, 245, 220)
		beam.Parent = head
		Build.part(
			car,
			"Taillight",
			Vector3.new(1, 0.5, 0.2),
			c * CFrame.new(x, 2.2, 6.6),
			Color3.fromRGB(255, 40, 40),
			{
				Material = Enum.Material.Neon,
			}
		)
	end
	local door = Build.part(
		car,
		"Door",
		Vector3.new(0.2, 1.8, 3),
		c * CFrame.new(-4.2, 3.2, 1.4) * CFrame.Angles(0, -0.9, 0),
		paint,
		metal
	)
	door:SetAttribute("Door", true)
	car.PrimaryPart = body
	car.Parent = m
end

-- Builds the course once (returns the Model).
function Course.build(): Model
	local existing = workspace:FindFirstChild("Breakout")
	if existing and existing:IsA("Model") then
		return existing
	end
	local m = Instance.new("Model")
	m.Name = "Breakout"
	sewer(m)
	yard(m)
	wall(m)
	outside(m)
	m.Parent = workspace
	return m
end

-- World position of a spawn (1..3), facing the way out.
function Course.spawn(index: number): CFrame
	local s = Rules.Spawns[index] or Rules.Spawns[1]
	local p = O + Vector3.new(s.x, s.y, s.z)
	return CFrame.lookAt(p, p + Vector3.xAxis)
end

function Course.toLocal(pos: Vector3): Vector3
	return pos - O
end

return Course
