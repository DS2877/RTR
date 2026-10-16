--!strict
-- Set dressing on top of the built prison (WorldBuilder calls Dressing.dress last): real pendant
-- lamps instead of flat light panels, pipe runs, security cameras, a checkered linoleum floor and
-- frosted windows in the Common Room, posters, vending machines, a wall clock, lived-in cells,
-- razor wire on every fence, a basketball court, the outer prison wall with guard towers, and
-- terrain: the hill the tunnels dig into plus mountains on the horizon.
-- Purely visual. Tags: "SkyWindow" (the client dims them at night), "Searchlight" (client sweeps it).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Config.World)
local Build = require(script.Parent.Build)
local GymProps = require(script.Parent.GymProps)

local Dressing = {}

local STEEL = Color3.fromRGB(78, 82, 88)
local DARK = Color3.fromRGB(36, 38, 42)
local H = World.TunnelHeight * World.BlockSize -- 24: cell block ceiling
local HALF_CORR = World.CorridorWidth / 2
local BACK_Z = HALF_CORR + World.CellDepth

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

-- a cylinder from a to b (Roblox cylinders run along their X axis)
local function rod(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	d: number,
	color: Color3,
	mat: Enum.Material?
)
	local len = (b - a).Magnitude
	return p(
		parent,
		name,
		Vector3.new(len, d, d),
		CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0),
		color,
		mat or Enum.Material.Metal,
		{ Shape = Enum.PartType.Cylinder, CanCollide = false }
	)
end

local function signOn(part: BasePart, face: Enum.NormalId, text: string, fg: Color3)
	Build.sign(part, face, text, fg)
end

-- ===== lamps: flat neon panels become hanging industrial pendants =====
local function pendants(folder: Instance)
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Lamp" and d.Material == Enum.Material.Neon then
			local at = d.Position
			local ceiling = at.Y + d.Size.Y / 2 -- the panel was flush with its ceiling
			local drop = 3.2
			local y = ceiling - drop
			local parent = d.Parent :: Instance
			rod(
				parent,
				"LampCable",
				Vector3.new(at.X, ceiling, at.Z),
				Vector3.new(at.X, y + 0.6, at.Z),
				0.12,
				DARK
			)
			p(
				parent,
				"LampShade",
				Vector3.new(0.9, 3.4, 3.4),
				CFrame.new(at.X, y + 0.25, at.Z) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(52, 70, 60),
				Enum.Material.Metal,
				{ Shape = Enum.PartType.Cylinder, CanCollide = false }
			)
			-- the old panel becomes the glowing disc under the shade (keeps its light)
			d.Shape = Enum.PartType.Cylinder
			d.Size = Vector3.new(0.2, 2.8, 2.8)
			d.CFrame = CFrame.new(at.X, y - 0.3, at.Z) * CFrame.Angles(0, 0, math.pi / 2)
			d.Color = Color3.fromRGB(255, 236, 200)
		end
	end
end

-- ===== small props =====
local function camera(parent: Instance, at: Vector3, facing: Vector3)
	local cf = CFrame.lookAt(at, at + facing)
	p(parent, "CamBody", Vector3.new(0.8, 0.8, 1.8), cf, Color3.fromRGB(225, 225, 220))
	p(
		parent,
		"CamLens",
		Vector3.new(0.5, 0.5, 0.2),
		cf * CFrame.new(0, 0, -1),
		Color3.fromRGB(15, 15, 18),
		Enum.Material.Glass
	)
	p(
		parent,
		"CamLed",
		Vector3.new(0.15, 0.15, 0.1),
		cf * CFrame.new(0.3, 0.3, -0.95),
		Color3.fromRGB(255, 40, 40),
		Enum.Material.Neon
	)
end

local function poster(parent: Instance, cf: CFrame, text: string, bg: Color3, fg: Color3)
	local part = p(parent, "Poster", Vector3.new(4.2, 5.4, 0.12), cf, bg)
	signOn(part, Enum.NormalId.Front, text, fg)
end

local function trashCan(parent: Instance, at: Vector3)
	p(
		parent,
		"TrashCan",
		Vector3.new(3, 2.2, 2.2),
		CFrame.new(at + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(46, 70, 52),
		Enum.Material.Metal,
		{ Shape = Enum.PartType.Cylinder }
	)
	p(
		parent,
		"TrashLid",
		Vector3.new(0.3, 2.4, 2.4),
		CFrame.new(at + Vector3.new(0, 3.12, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(36, 54, 40),
		Enum.Material.Metal,
		{ Shape = Enum.PartType.Cylinder }
	)
end

local function clock(parent: Instance, cf: CFrame)
	p(
		parent,
		"ClockFace",
		Vector3.new(0.3, 4, 4),
		cf * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0),
		Color3.fromRGB(235, 232, 220),
		Enum.Material.SmoothPlastic,
		{ Shape = Enum.PartType.Cylinder, CanCollide = false }
	)
	p(parent, "ClockHand", Vector3.new(0.15, 1.5, 0.08), cf * CFrame.new(0, 0.6, -0.2), DARK)
	p(
		parent,
		"ClockHand",
		Vector3.new(0.15, 1.1, 0.08),
		cf * CFrame.new(0.4, -0.15, -0.22) * CFrame.Angles(0, 0, math.rad(-70)),
		DARK
	)
end

local function bench(parent: Instance, cf: CFrame)
	p(
		parent,
		"BenchSeat",
		Vector3.new(7, 0.4, 1.8),
		cf * CFrame.new(0, 1.8, 0),
		Color3.fromRGB(110, 84, 58),
		Enum.Material.WoodPlanks
	)
	for _, dx in { -2.8, 2.8 } do
		p(
			parent,
			"BenchLeg",
			Vector3.new(0.4, 1.6, 1.4),
			cf * CFrame.new(dx, 0.8, 0),
			STEEL,
			Enum.Material.Metal
		)
	end
end

-- ===== areas =====
local function cellBlock(prison: Instance, cells: { any })
	local block = prison:FindFirstChild("CellBlock") :: Instance
	local d = Instance.new("Folder")
	d.Name = "Dressing"
	d.Parent = block
	local x0, x1 = -World.CellsPerRow * World.CellPitch / 2, World.CellsPerRow * World.CellPitch / 2
	-- pipe runs along both corridor walls, under the ceiling
	for _, side in { -1, 1 } do
		local z = side * (HALF_CORR - 1)
		rod(d, "Pipe", Vector3.new(x0, 21.2, z), Vector3.new(x1, 21.2, z), 1.1, Color3.fromRGB(96, 102, 108))
		rod(
			d,
			"Pipe",
			Vector3.new(x0, 22.6, z - side * 0.2),
			Vector3.new(x1, 22.6, z - side * 0.2),
			0.6,
			Color3.fromRGB(150, 50, 40)
		)
		for x = x0 + 6, x1 - 6, 12 do
			p(
				d,
				"PipeBracket",
				Vector3.new(0.3, 2.6, 1.4),
				CFrame.new(x, 21.9, z + side * 0.3),
				DARK,
				Enum.Material.Metal
			)
		end
	end
	camera(d, Vector3.new(x1 - 2, 19, -HALF_CORR + 2), Vector3.new(-1, -0.35, 0.4))
	camera(d, Vector3.new(x0 + 2, 19, HALF_CORR - 2), Vector3.new(1, -0.35, -0.4))
	-- the corridor's far end: a notice board, a mop bucket
	local board = p(
		d,
		"NoticeBoard",
		Vector3.new(0.2, 5, 8),
		CFrame.new(x1 + 1.9, 8, -6),
		Color3.fromRGB(150, 110, 70),
		Enum.Material.Wood
	)
	signOn(board, Enum.NormalId.Left, "RULES  1. NO DIGGING  2. SEE RULE 1", Color3.fromRGB(30, 30, 30))
	p(d, "MopBucket", Vector3.new(2, 1.6, 2), CFrame.new(x1 - 2, 0.8, 8), Color3.fromRGB(230, 190, 40))
	rod(
		d,
		"Mop",
		Vector3.new(x1 - 2, 0.8, 8),
		Vector3.new(x1 - 1.2, 5.5, 8.6),
		0.2,
		Color3.fromRGB(150, 120, 80),
		Enum.Material.Wood
	)
	pendants(block)
	pendants(prison:FindFirstChild("Cells") :: Instance)

	-- cells: rug, desk with books, mirror, tally marks
	for _, cell in cells do
		local m = cell.model :: Model
		local cx = cell.frame.Position.X
		local s = if cell.frame.Position.Z < 0 then -1 else 1
		-- world x offset from the cell's center, height, distance from the back wall
		local function at(x: number, y: number, depthFromBack: number): CFrame
			return CFrame.new(cx + x, y, s * (BACK_Z - depthFromBack))
		end
		p(
			m,
			"Rug",
			Vector3.new(7, 0.08, 5),
			at(-1, 0.04, 8),
			Color3.fromRGB(120, 48, 40),
			Enum.Material.Fabric
		)
		p(
			m,
			"Desk",
			Vector3.new(4, 0.3, 2.2),
			at(-12, 3, 15.6),
			Color3.fromRGB(120, 92, 62),
			Enum.Material.WoodPlanks
		)
		for _, dx in { -1.7, 1.7 } do
			p(m, "DeskLeg", Vector3.new(0.3, 2.85, 1.9), at(-12 + dx, 1.43, 15.6), STEEL, Enum.Material.Metal)
		end
		for i, c in { Color3.fromRGB(160, 50, 40), Color3.fromRGB(40, 80, 140), Color3.fromRGB(200, 170, 60) } do
			p(
				m,
				"Book",
				Vector3.new(1.4, 0.3, 1),
				at(-11.6, 3.3 + i * 0.3, 15.6) * CFrame.Angles(0, i * 0.3, 0),
				c
			)
		end
		p(
			m,
			"Mirror",
			Vector3.new(0.1, 1.8, 1.4),
			at(17.9, 6.2, 9),
			Color3.fromRGB(190, 210, 220),
			Enum.Material.Glass,
			{ Reflectance = 0.4 }
		)
		-- tally marks scratched into the left wall
		local scratch = p(
			m,
			"Scratches",
			Vector3.new(0.05, 3, 4),
			at(17.97, 9, 3),
			Color3.new(),
			Enum.Material.SmoothPlastic,
			{ Transparency = 1, CanCollide = false }
		)
		signOn(scratch, Enum.NormalId.Left, "|||| |||| |||| ||", Color3.fromRGB(40, 40, 44))
	end
end

local function commonRoom(prison: Instance)
	local common = prison:FindFirstChild("CommonRoom") :: Instance
	local d = Instance.new("Folder")
	d.Name = "Dressing"
	d.Parent = common
	local cr = World.CommonRoom
	local x0, x1 = cr.x - cr.sx / 2, cr.x + cr.sx / 2
	local z0, z1 = cr.z - cr.sz / 2, cr.z + cr.sz / 2
	-- checkered linoleum (8-stud tiles)
	local A, Bc = Color3.fromRGB(116, 120, 126), Color3.fromRGB(88, 92, 100)
	for ix = 0, 13 do
		for iz = 0, 11 do
			p(
				d,
				"Tile",
				Vector3.new(8, 0.04, 8),
				CFrame.new(x0 + 2 + 4 + ix * 8, 0.02, z0 + 4 + iz * 8),
				if (ix + iz) % 2 == 0 then A else Bc,
				Enum.Material.Marble
			)
		end
	end
	-- pipes along the long walls, under the ceiling
	for _, z in { z0 + 0.8, z1 - 0.8 } do
		rod(
			d,
			"Pipe",
			Vector3.new(x0 + 1, 25, z),
			Vector3.new(x1 - 3, 25, z),
			1.2,
			Color3.fromRGB(96, 102, 108)
		)
	end
	-- frosted windows high on the north wall (dim at night: tag SkyWindow)
	for i = 0, 3 do
		local x = x0 + 14 + i * 30
		local w = p(
			d,
			"SkyWindow",
			Vector3.new(8, 4, 0.2),
			CFrame.new(x, 22, z0 + 0.12),
			Color3.fromRGB(210, 222, 235),
			Enum.Material.Glass,
			{ Transparency = 0.1 }
		)
		CollectionService:AddTag(w, "SkyWindow")
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Back
		light.Angle = 70
		light.Range = 30
		light.Brightness = 1.2
		light.Color = Color3.fromRGB(215, 228, 240)
		light.Parent = w
		for k = -1, 1 do
			p(
				d,
				"WindowBar",
				Vector3.new(0.25, 4.2, 0.25),
				CFrame.new(x + k * 2.6, 22, z0 + 0.4),
				DARK,
				Enum.Material.Metal
			)
		end
	end
	-- cameras in the corners, a clock over the Yard door
	camera(d, Vector3.new(x0 + 3, 21, z0 + 3), Vector3.new(1, -0.5, 1))
	camera(d, Vector3.new(x1 - 5, 21, z1 - 3), Vector3.new(-1, -0.5, -1))
	clock(d, CFrame.new(x0 + 0.3, 22.5, 0) * CFrame.Angles(0, -math.pi / 2, 0))
	-- vending machines by the corridor door
	for i, z in { -20, -27 } do
		local v = GymProps.build("Vending")
		v.Name = "VendingMachine" .. i
		v:PivotTo(CFrame.new(x1 - 2 - 1.6, 0, z) * CFrame.Angles(0, math.pi / 2, 0))
		v.Parent = d
	end
	trashCan(d, Vector3.new(cr.x, 0, 9))
	trashCan(d, Vector3.new(cr.x, 0, -9))
	-- posters with fair warnings
	poster(
		d,
		CFrame.new(x0 + 8, 8, z0 + 0.18) * CFrame.Angles(0, math.pi, 0),
		"NO DIGGING",
		Color3.fromRGB(190, 40, 40),
		Color3.new(1, 1, 1)
	)
	poster(
		d,
		CFrame.new(x0 + 20, 8, z0 + 0.18) * CFrame.Angles(0, math.pi, 0),
		"SMILE! YOU'RE ON CAMERA",
		Color3.fromRGB(230, 200, 60),
		Color3.fromRGB(30, 30, 30)
	)
	poster(
		d,
		CFrame.new(x1 - 2.06, 8, -36) * CFrame.Angles(0, math.pi / 2, 0),
		"REPORT TUNNELS  REWARD: 5 NOODLES",
		Color3.fromRGB(40, 70, 130),
		Color3.new(1, 1, 1)
	)
	pendants(common)
end

local function yard(prison: Instance)
	local yardFolder = prison:FindFirstChild("Yard") :: Instance
	local d = Instance.new("Folder")
	d.Name = "Dressing"
	d.Parent = yardFolder
	local Y = World.Yard
	local x0, x1 = Y.x - Y.sx / 2, Y.x + Y.sx / 2
	local z0, z1 = Y.z - Y.sz / 2, Y.z + Y.sz / 2
	-- razor wire coils along the top of every fence
	for _, w in yardFolder:GetChildren() do
		if w:IsA("BasePart") and w.Name == "Wire" then
			local cf = w.CFrame
			local len = w.Size.Z
			p(
				d,
				"RazorCoil",
				Vector3.new(len, 1.9, 1.9),
				cf * CFrame.new(0, 1.35, 0) * CFrame.Angles(0, math.pi / 2, 0),
				Color3.fromRGB(170, 175, 180),
				Enum.Material.Metal,
				{ Shape = Enum.PartType.Cylinder, Transparency = 0.55, CanCollide = false }
			)
			for k = -len / 2 + 2, len / 2 - 2, 4 do
				p(
					d,
					"Barb",
					Vector3.new(0.12, 2.4, 0.12),
					cf * CFrame.new(0, 1.35, k) * CFrame.Angles(0, 0, math.rad(45)),
					Color3.fromRGB(150, 155, 160),
					Enum.Material.Metal,
					{ CanCollide = false }
				)
				p(
					d,
					"Barb",
					Vector3.new(0.12, 2.4, 0.12),
					cf * CFrame.new(0, 1.35, k + 0.6) * CFrame.Angles(0, 0, math.rad(-45)),
					Color3.fromRGB(150, 155, 160),
					Enum.Material.Metal,
					{ CanCollide = false }
				)
			end
		end
	end
	-- basketball court: lines + two hoops
	local cx0, cx1 = x0 + 20, x1 - 30
	local line = Color3.fromRGB(225, 225, 215)
	local lines = 0
	local function courtLine(a: Vector3, b: Vector3)
		local len = (b - a).Magnitude
		lines += 1
		-- each line a little higher than the last: their crossings never fight
		local y = 0.12 + (lines % 7) * 0.035
		p(
			d,
			"CourtLine",
			Vector3.new(0.35, 0.04, len + 0.35),
			CFrame.lookAt((a + b) / 2, b) + Vector3.new(0, y, 0),
			line,
			Enum.Material.SmoothPlastic,
			{ CanCollide = false }
		)
	end
	courtLine(Vector3.new(cx0 + 2, 0, -16), Vector3.new(cx1 - 2, 0, -16))
	courtLine(Vector3.new(cx0 + 2, 0, 16), Vector3.new(cx1 - 2, 0, 16))
	courtLine(Vector3.new(cx0 + 2, 0, -16), Vector3.new(cx0 + 2, 0, 16))
	courtLine(Vector3.new(cx1 - 2, 0, -16), Vector3.new(cx1 - 2, 0, 16))
	local mid = (cx0 + cx1) / 2
	courtLine(Vector3.new(mid, 0, -16), Vector3.new(mid, 0, 16))
	for k = 0, 11 do
		local a1, a2 = k / 12 * math.pi * 2, (k + 1) / 12 * math.pi * 2
		courtLine(
			Vector3.new(mid + math.cos(a1) * 6, 0, math.sin(a1) * 6),
			Vector3.new(mid + math.cos(a2) * 6, 0, math.sin(a2) * 6)
		)
	end
	for _, side in { -1, 1 } do
		local hx = if side < 0 then cx0 + 1 else cx1 - 1
		p(d, "HoopPole", Vector3.new(0.6, 12, 0.6), CFrame.new(hx, 6, 0), STEEL, Enum.Material.Metal)
		local board = p(
			d,
			"Backboard",
			Vector3.new(0.3, 4, 6),
			CFrame.new(hx - side * 1.6, 12.5, 0),
			Color3.fromRGB(235, 235, 235)
		)
		local _ = board
		p(
			d,
			"HoopArm",
			Vector3.new(1.6, 0.4, 0.4),
			CFrame.new(hx - side * 0.8, 11.6, 0),
			STEEL,
			Enum.Material.Metal
		)
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			p(
				d,
				"Rim",
				Vector3.new(0.18, 0.18, 0.75),
				CFrame.new(hx - side * 2.7 + math.cos(a) * 0.9, 11.2, math.sin(a) * 0.9)
					* CFrame.Angles(0, -a, 0),
				Color3.fromRGB(230, 90, 30),
				Enum.Material.Metal,
				{ CanCollide = false }
			)
		end
	end
	-- benches along the Common Room side, puddles on the asphalt
	for _, z in { -53, -43, 43, 53 } do
		bench(d, CFrame.new(x1 - 6, 0, z) * CFrame.Angles(0, math.pi / 2, 0))
	end
	for i, pos in { Vector3.new(-300, 0, 24), Vector3.new(-372, 0, -26), Vector3.new(-330, 0, -40) } do
		p(
			d,
			"Puddle",
			Vector3.new(6 + i, 0.03, 4 + i * 0.5),
			CFrame.new(pos + Vector3.new(0, 0.015, 0)) * CFrame.Angles(0, i, 0),
			Color3.fromRGB(40, 44, 50),
			Enum.Material.Glass,
			{ Reflectance = 0.3, Transparency = 0.2, CanCollide = false }
		)
	end
	-- the searchlight sweeps (client side) with a visible beam
	local search = yardFolder:FindFirstChild("Searchlight") :: BasePart?
	if search then
		CollectionService:AddTag(search, "Searchlight")
		local a0 = Instance.new("Attachment")
		a0.Parent = search
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -60, 0)
		a1.Parent = search
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 1.5
		beam.Width1 = 16
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 250, 220))
		beam.Transparency = NumberSequence.new(0.75, 1)
		beam.Parent = search
	end

	-- the outer prison wall with guard towers (a ring around the Yard, meeting the cell block hill)
	local wallColor = Color3.fromRGB(122, 124, 126)
	local wx0, wz0, wz1 = x0 - 26, z0 - 26, z1 + 43 -- (south: clear of the Mess Hall, which ends at z 112)
	local wallEnd = -World.CellsPerRow * World.CellPitch / 2 - 2
	local function wall(a: Vector3, b: Vector3)
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		p(
			d,
			"PrisonWall",
			Vector3.new(4, 30, len),
			cf + Vector3.new(0, 11, 0),
			wallColor,
			Enum.Material.Concrete
		)
		p(
			d,
			"WallCap",
			Vector3.new(5, 1, len),
			cf + Vector3.new(0, 26.5, 0),
			Color3.fromRGB(96, 98, 100),
			Enum.Material.Concrete
		)
		p(
			d,
			"WallCoil",
			Vector3.new(len, 2, 2),
			cf * CFrame.new(0, 28.2, 0) * CFrame.Angles(0, math.pi / 2, 0),
			Color3.fromRGB(170, 175, 180),
			Enum.Material.Metal,
			{ Shape = Enum.PartType.Cylinder, Transparency = 0.5, CanCollide = false }
		)
	end
	wall(Vector3.new(wx0, 0, wz0), Vector3.new(wx0, 0, wz1))
	wall(Vector3.new(wx0 + 2.5, 0, wz0), Vector3.new(wallEnd, 0, wz0))
	wall(Vector3.new(wx0 + 2.5, 0, wz1), Vector3.new(wallEnd, 0, wz1))
	for _, c in { Vector3.new(wx0, 0, wz0), Vector3.new(wx0, 0, wz1) } do
		p(
			d,
			"WallTower",
			Vector3.new(12, 40, 12),
			CFrame.new(c + Vector3.new(0, 16, 0)),
			Color3.fromRGB(110, 112, 114),
			Enum.Material.Concrete
		)
		p(
			d,
			"WallTowerCabin",
			Vector3.new(15, 7, 15),
			CFrame.new(c + Vector3.new(0, 39.5, 0)),
			Color3.fromRGB(70, 74, 80),
			Enum.Material.Metal
		)
		p(
			d,
			"WallTowerGlass",
			Vector3.new(15.2, 3, 15.2),
			CFrame.new(c + Vector3.new(0, 40, 0)),
			Color3.fromRGB(240, 220, 150),
			Enum.Material.Neon,
			{ Transparency = 0.35 }
		)
		p(
			d,
			"WallTowerRoof",
			Vector3.new(17, 1.2, 17),
			CFrame.new(c + Vector3.new(0, 43.6, 0)),
			Color3.fromRGB(50, 52, 56),
			Enum.Material.Metal
		)
	end
end

-- ===== terrain: the hill over the tunnels and the land outside; mountain silhouettes =====
local function landscape(prison: Instance)
	local terrain = workspace.Terrain
	local rowHalf = World.CellsPerRow * World.CellPitch / 2 + 2
	local tunnelEnd = BACK_Z + World.TunnelDepth * World.BlockSize + 8
	local top = H + 5 -- over the tunnel roofs
	for _, s in { -1, 1 } do
		local zc = s * (BACK_Z + tunnelEnd) / 2
		local len = tunnelEnd - BACK_Z
		-- the hill: a grassy ridge on top of both tunnel rows (the tunnels dig into it)
		terrain:FillBlock(
			CFrame.new(0, top + 6, zc),
			Vector3.new(rowHalf * 2 + 20, 12, len),
			Enum.Material.Grass
		)
		for k = 0, 9 do
			local z = s * (BACK_Z + 60 + k * 120)
			local r = 50 + (k % 3) * 18
			terrain:FillBall(Vector3.new((k % 2 * 2 - 1) * 40, top + 8, z), r, Enum.Material.Grass)
			terrain:FillBall(
				Vector3.new((k % 2 * 2 - 1) * -50, top + 2, z + s * 60),
				r * 0.7,
				Enum.Material.Rock
			)
		end
		-- nothing may grow into the tunnels, cells or the Common Room below the roof line
		terrain:FillBlock(
			CFrame.new(0, (top - 1) / 2 - 2, zc),
			Vector3.new(rowHalf * 2 + 60, top + 3, len + 60),
			Enum.Material.Air
		)
	end
	-- grass plains around the compound (just under the outside ground)
	terrain:FillBlock(CFrame.new(-200, -8, 0), Vector3.new(2400, 6, 3000), Enum.Material.Grass)
	-- distant mountain ridges (a few huge rock wedges in the haze; cheaper than terrain)
	local far = Instance.new("Folder")
	far.Name = "Mountains"
	far.Parent = prison
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2 + 0.3
		local dist = 1500 + (i % 3) * 220
		local pos = Vector3.new(-200 + math.cos(a) * dist, 0, math.sin(a) * dist)
		local hgt = 260 + (i % 4) * 70
		local w = 700 + (i % 3) * 200
		local face = CFrame.lookAt(pos, Vector3.new(-200, 0, 0))
		-- two wedges back to back = a ridge (a wedge is tall at its +Z end)
		for _, side in { 1, -1 } do
			local wedge = Instance.new("WedgePart")
			wedge.Name = "Mountain"
			wedge.Anchored = true
			wedge.CanCollide = false
			wedge.CanQuery = false
			wedge.CanTouch = false
			wedge.CastShadow = false
			wedge.Material = Enum.Material.Rock
			wedge.Color = if i % 2 == 0 then Color3.fromRGB(78, 82, 88) else Color3.fromRGB(70, 74, 80)
			wedge.Size = Vector3.new(w, hgt, hgt * 1.3)
			wedge.CFrame = face
				* CFrame.new(0, hgt / 2 - 10, side * hgt * 0.65)
				* CFrame.Angles(0, if side > 0 then math.pi else 0, 0)
			wedge.Parent = far
		end
	end
end

function Dressing.dress(prison: Instance, cells: { any })
	cellBlock(prison, cells)
	commonRoom(prison)
	yard(prison)
	landscape(prison)
end

return Dressing
