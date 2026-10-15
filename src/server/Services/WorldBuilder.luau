--!strict
-- Builds the whole prison at runtime: Cell Block (12 cells + bedrock boxes around every tunnel
-- volume), corridor, Common Room with the shop counters and the Yard with the dump and the gym.
-- The voxel walls themselves are drawn by each client (client/Controllers/VoxelRender).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Economy = require(Shared.Config.Economy)
local Tunnel = require(Shared.Tunnel)
local Build = require(script.Parent.Parent.Util.Build)

local WorldBuilder = {}

export type CellRecord = {
	index: number,
	frame: CFrame,
	spawn: CFrame,
	sign: TextLabel,
	model: Model,
}

export type WorldRecord = {
	cells: { CellRecord },
	shops: { [string]: BasePart },
	dump: BasePart,
	stations: { BasePart },
}

local C = {
	floor = Color3.fromRGB(150, 150, 146),
	corridorFloor = Color3.fromRGB(120, 124, 128),
	wall = Color3.fromRGB(196, 192, 180),
	wallLow = Color3.fromRGB(70, 110, 120), -- painted lower half of prison walls
	ceiling = Color3.fromRGB(170, 170, 165),
	bedrock = Color3.fromRGB(38, 36, 42),
	bars = Color3.fromRGB(70, 74, 82),
	line = Color3.fromRGB(240, 200, 40),
	grass = Color3.fromRGB(96, 160, 72),
	orange = Color3.fromRGB(255, 140, 40),
}

local H = World.TunnelHeight * World.BlockSize -- 24: cell and corridor height
local WALL = World.WallThickness
local HALF_CORR = World.CorridorWidth / 2
local BACK_Z = HALF_CORR + World.CellDepth -- 32
local END_Z = BACK_Z + World.TunnelDepth * World.BlockSize -- 1232
local ROW_HALF = World.CellsPerRow * World.CellPitch / 2 -- 120

-- ===== cell block =====

local function buildRowShell(parent: Instance, row: number)
	local s = if row == 0 then -1 else 1
	local function zz(a: number, b: number): (number, number)
		return a * s, b * s
	end
	local z0, z1 = zz(HALF_CORR, BACK_Z)
	Build.box(
		parent,
		"CellFloor",
		Vector3.new(-ROW_HALF - 2, -4, z0),
		Vector3.new(ROW_HALF + 2, 0, z1),
		C.floor,
		{
			Material = Enum.Material.Concrete,
		}
	)
	local t0, t1 = zz(BACK_Z, END_Z + WALL)
	-- bedrock under, over and at the end of every tunnel volume: the unbreakable boundary
	Build.box(
		parent,
		"BedrockFloor",
		Vector3.new(-ROW_HALF - 2, -4, t0),
		Vector3.new(ROW_HALF + 2, 0, t1),
		C.bedrock,
		{
			Material = Enum.Material.Basalt,
		}
	)
	local c0, c1 = zz(HALF_CORR, END_Z + WALL)
	Build.box(
		parent,
		"Ceiling",
		Vector3.new(-ROW_HALF - 2, H, c0),
		Vector3.new(ROW_HALF + 2, H + 4, c1),
		C.bedrock,
		{
			Material = Enum.Material.Basalt,
		}
	)
	Build.box(
		parent,
		"Grass",
		Vector3.new(-ROW_HALF - 2, H + 4, c0),
		Vector3.new(ROW_HALF + 2, H + 5, c1),
		C.grass,
		{
			Material = Enum.Material.Grass,
		}
	)
	local e0, e1 = zz(END_Z, END_Z + WALL)
	Build.box(
		parent,
		"BedrockEnd",
		Vector3.new(-ROW_HALF - 2, 0, e0),
		Vector3.new(ROW_HALF + 2, H, e1),
		C.bedrock,
		{
			Material = Enum.Material.Basalt,
		}
	)
	-- walls between cells: painted in the cell, bedrock along the tunnel
	for k = 0, World.CellsPerRow do
		local x = -ROW_HALF + k * World.CellPitch
		local a0, a1 = zz(HALF_CORR, BACK_Z)
		Build.box(parent, "CellWall", Vector3.new(x - 2, 0, a0), Vector3.new(x + 2, H, a1), C.wall, {
			Material = Enum.Material.Concrete,
		})
		Build.box(
			parent,
			"CellWallLow",
			Vector3.new(x - 2.1, 0, a0),
			Vector3.new(x + 2.1, 6, a1),
			C.wallLow,
			{
				Material = Enum.Material.Concrete,
				CanCollide = false,
			}
		)
		local b0, b1 = zz(BACK_Z, END_Z)
		Build.box(parent, "BedrockWall", Vector3.new(x - 2, 0, b0), Vector3.new(x + 2, H, b1), C.bedrock, {
			Material = Enum.Material.Basalt,
		})
	end
end

local function buildCell(parent: Instance, index: number): CellRecord
	local frame = Tunnel.frame(index)
	local model = Instance.new("Model")
	model.Name = "Cell" .. index
	model.Parent = parent
	local cx = Tunnel.cellCenterX(index)
	local s = if Tunnel.row(index) == 0 then -1 else 1
	local halfW = World.TunnelWidth * World.BlockSize / 2 -- 18
	local frontZ = HALF_CORR * s
	local wallIn = (HALF_CORR + 2) * s
	-- front wall with a door opening (10 wide, 12 high)
	local doorHalf = 5
	local doorH = 12
	Build.box(
		model,
		"Front",
		Vector3.new(cx - halfW, 0, frontZ),
		Vector3.new(cx - doorHalf, H, wallIn),
		C.wall,
		{
			Material = Enum.Material.Concrete,
		}
	)
	Build.box(
		model,
		"Front",
		Vector3.new(cx + doorHalf, 0, frontZ),
		Vector3.new(cx + halfW, H, wallIn),
		C.wall,
		{
			Material = Enum.Material.Concrete,
		}
	)
	Build.box(
		model,
		"Front",
		Vector3.new(cx - doorHalf, doorH, frontZ),
		Vector3.new(cx + doorHalf, H, wallIn),
		C.wall,
		{
			Material = Enum.Material.Concrete,
		}
	)
	-- painted stripe on the corridor side
	Build.box(
		model,
		"Stripe",
		Vector3.new(cx - halfW, 0, frontZ - 0.1 * s),
		Vector3.new(cx - doorHalf, 6, frontZ),
		C.wallLow,
		{ CanCollide = false }
	)
	Build.box(
		model,
		"Stripe",
		Vector3.new(cx + doorHalf, 0, frontZ - 0.1 * s),
		Vector3.new(cx + halfW, 6, frontZ),
		C.wallLow,
		{ CanCollide = false }
	)
	-- the barred door, slid open (it locks at night from M2)
	local door = Instance.new("Model")
	door.Name = "Door"
	door.Parent = model
	local doorZ = frontZ - 0.6 * s
	for i = 0, 6 do
		local x = cx - doorHalf - 8 + i * 1.5
		Build.part(door, "Bar", Vector3.new(0.4, doorH, 0.4), CFrame.new(x, doorH / 2, doorZ), C.bars, {
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
	end
	for _, y in { 0.5, doorH - 0.5 } do
		Build.part(
			door,
			"Rail",
			Vector3.new(10, 0.5, 0.5),
			CFrame.new(cx - doorHalf - 3.5, y, doorZ),
			C.bars,
			{
				Material = Enum.Material.Metal,
				CanCollide = false,
			}
		)
	end
	-- name + depth sign above the door
	local signPart = Build.part(
		model,
		"Sign",
		Vector3.new(14, 4, 0.4),
		CFrame.new(cx, doorH + 3, frontZ - 0.3 * s),
		Color3.fromRGB(40, 44, 52)
	)
	local sign = Build.sign(
		signPart,
		if s < 0 then Enum.NormalId.Back else Enum.NormalId.Front,
		"CELL " .. index .. "\nFREE",
		Color3.fromRGB(255, 235, 120)
	)
	Build.part(
		model,
		"Number",
		Vector3.new(3, 3, 0.3),
		CFrame.new(cx - doorHalf - 2, doorH + 3, frontZ - 0.3 * s),
		C.orange
	)
	-- inside the cell (along the side walls, the back wall is the voxel face)
	local innerZ = (HALF_CORR + 2) * s
	local function inCell(x: number, y: number, depthFromFront: number): CFrame
		return CFrame.new(cx + x, y, innerZ + depthFromFront * s)
	end
	-- bed
	Build.part(model, "BedFrame", Vector3.new(4, 1.6, 9), inCell(-halfW + 2.2, 0.8, 9), C.bars, {
		Material = Enum.Material.Metal,
	})
	Build.part(
		model,
		"Mattress",
		Vector3.new(3.8, 0.8, 8.8),
		inCell(-halfW + 2.2, 2, 9),
		Color3.fromRGB(230, 230, 220),
		{
			Material = Enum.Material.Fabric,
		}
	)
	Build.part(model, "Blanket", Vector3.new(3.9, 0.3, 5.5), inCell(-halfW + 2.2, 2.5, 10.5), C.orange, {
		Material = Enum.Material.Fabric,
	})
	Build.part(
		model,
		"Pillow",
		Vector3.new(3, 0.6, 1.6),
		inCell(-halfW + 2.2, 2.6, 5.4),
		Color3.fromRGB(250, 250, 245)
	)
	-- toilet + sink
	Build.part(
		model,
		"Toilet",
		Vector3.new(2.4, 2.2, 2.6),
		inCell(halfW - 1.6, 1.1, 14),
		Color3.fromRGB(235, 238, 240),
		{
			Material = Enum.Material.Marble,
		}
	)
	Build.part(
		model,
		"Tank",
		Vector3.new(2.6, 2.4, 1),
		inCell(halfW - 1.6, 3, 15.4),
		Color3.fromRGB(235, 238, 240)
	)
	Build.part(
		model,
		"Sink",
		Vector3.new(2.2, 0.8, 1.8),
		inCell(halfW - 1.4, 4, 9),
		Color3.fromRGB(220, 224, 228),
		{
			Material = Enum.Material.Metal,
		}
	)
	-- poster on the side wall
	local poster = Build.part(
		model,
		"Poster",
		Vector3.new(0.2, 5, 3.6),
		inCell(halfW - 0.1, 8, 5),
		Color3.fromRGB(70, 140, 220)
	)
	Build.sign(poster, Enum.NormalId.Left, "🏝️\nDREAM BIG", Color3.new(1, 1, 1))
	Build.sign(poster, Enum.NormalId.Right, "🏝️\nDREAM BIG", Color3.new(1, 1, 1))
	-- ceiling lamp
	local lamp = Build.part(
		model,
		"Lamp",
		Vector3.new(4, 0.5, 2),
		inCell(0, H - 0.25, 8),
		Color3.fromRGB(255, 250, 225),
		{
			Material = Enum.Material.Neon,
		}
	)
	Build.light(lamp, Color3.fromRGB(255, 240, 210), 30, 1.2)
	-- where you spawn: inside, facing the back wall
	local spawnPos = Vector3.new(cx, 3, (HALF_CORR + 13) * s)
	local spawn = CFrame.lookAt(spawnPos, spawnPos + Vector3.new(0, 0, s))
	model:SetAttribute("Cell", index)
	return { index = index, frame = frame, spawn = spawn, sign = sign, model = model }
end

local function buildCorridor(parent: Instance)
	local x0, x1 = -ROW_HALF - 2, ROW_HALF + 2
	Build.box(
		parent,
		"CorridorFloor",
		Vector3.new(x0, -4, -HALF_CORR),
		Vector3.new(x1, 0, HALF_CORR),
		C.corridorFloor,
		{
			Material = Enum.Material.Concrete,
		}
	)
	for _, z in { -HALF_CORR + 3, HALF_CORR - 3 } do
		Build.box(parent, "FloorLine", Vector3.new(x0, 0, z - 0.4), Vector3.new(x1, 0.05, z + 0.4), C.line, {
			CanCollide = false,
		})
	end
	Build.box(
		parent,
		"CorridorCeiling",
		Vector3.new(x0, H, -HALF_CORR),
		Vector3.new(x1, H + 2, HALF_CORR),
		C.ceiling
	)
	-- the far end of the corridor (+X) is a wall with a big clock; -X opens into the Common Room
	local endWall = Build.box(
		parent,
		"CorridorEnd",
		Vector3.new(x1, 0, -HALF_CORR),
		Vector3.new(x1 + 4, H, HALF_CORR),
		C.wall,
		{
			Material = Enum.Material.Concrete,
		}
	)
	Build.sign(endWall, Enum.NormalId.Left, "CELL BLOCK D", Color3.fromRGB(255, 235, 120))
	for i = 0, 5 do
		local lamp = Build.part(
			parent,
			"Lamp",
			Vector3.new(6, 0.5, 2),
			CFrame.new(-100 + i * 40, H - 0.25, 0),
			Color3.fromRGB(255, 250, 225),
			{ Material = Enum.Material.Neon }
		)
		Build.light(lamp, Color3.fromRGB(255, 240, 210), 40, 1)
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.5, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = parent
end

-- ===== Common Room =====

local function counter(parent: Instance, name: string, title: string, cf: CFrame, color: Color3): BasePart
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	local top = Build.part(m, "Counter", Vector3.new(14, 3.4, 3), cf * CFrame.new(0, 1.7, 0), color, {
		Material = Enum.Material.WoodPlanks,
	})
	Build.part(
		m,
		"CounterTop",
		Vector3.new(14.4, 0.4, 3.4),
		cf * CFrame.new(0, 3.6, 0),
		Color3.fromRGB(90, 70, 50)
	)
	Build.npc(m, "Keeper", cf * CFrame.new(0, 0, 3.5), color, C.bars)
	local board = Build.part(
		m,
		"Board",
		Vector3.new(14, 4.5, 0.5),
		cf * CFrame.new(0, 10, 5.5),
		Color3.fromRGB(35, 38, 46)
	)
	Build.sign(board, Enum.NormalId.Front, title, Color3.fromRGB(255, 235, 120))
	local prompt = Build.prompt(top, "Open", title, Economy.ShopRange)
	prompt.Name = "ShopPrompt"
	top:SetAttribute("Shop", name)
	CollectionService:AddTag(top, "Shop")
	return top
end

local function buildCommonRoom(parent: Instance): { [string]: BasePart }
	local cr = World.CommonRoom
	local x0, x1 = cr.x - cr.sx / 2, cr.x + cr.sx / 2
	local z0, z1 = cr.z - cr.sz / 2, cr.z + cr.sz / 2
	local h = cr.height
	Build.box(
		parent,
		"CommonFloor",
		Vector3.new(x0, -4, z0),
		Vector3.new(x1, 0, z1),
		Color3.fromRGB(176, 150, 120),
		{
			Material = Enum.Material.Wood,
		}
	)
	Build.box(parent, "CommonCeiling", Vector3.new(x0, h, z0), Vector3.new(x1, h + 2, z1), C.ceiling)
	-- walls (+X wall has the corridor opening, -X wall the door to the Yard)
	Build.box(parent, "Wall", Vector3.new(x0, 0, z0 - 4), Vector3.new(x1, h, z0), C.wall)
	Build.box(parent, "Wall", Vector3.new(x0, 0, z1), Vector3.new(x1, h, z1 + 4), C.wall)
	Build.box(parent, "Wall", Vector3.new(x1 - 2, 0, z0), Vector3.new(x1 + 2, h, -HALF_CORR), C.wall)
	Build.box(parent, "Wall", Vector3.new(x1 - 2, 0, HALF_CORR), Vector3.new(x1 + 2, h, z1), C.wall)
	Build.box(parent, "Wall", Vector3.new(x1 - 2, H, -HALF_CORR), Vector3.new(x1 + 2, h, HALF_CORR), C.wall)
	local yardDoor = 12
	Build.box(parent, "Wall", Vector3.new(x0 - 4, 0, z0), Vector3.new(x0, h, -yardDoor), C.wall)
	Build.box(parent, "Wall", Vector3.new(x0 - 4, 0, yardDoor), Vector3.new(x0, h, z1), C.wall)
	Build.box(parent, "Wall", Vector3.new(x0 - 4, 14, -yardDoor), Vector3.new(x0, h, yardDoor), C.wall)
	local yardSign =
		Build.part(parent, "YardSign", Vector3.new(0.4, 4, 16), CFrame.new(x0 + 0.3, 17, 0), C.orange)
	Build.sign(yardSign, Enum.NormalId.Right, "YARD ➜", Color3.new(1, 1, 1))
	Build.sign(yardSign, Enum.NormalId.Left, "COMMON ROOM", Color3.new(1, 1, 1))
	local crSign =
		Build.part(parent, "CommonSign", Vector3.new(0.4, 4, 20), CFrame.new(x1 - 2.3, 17, 0), C.orange)
	Build.sign(crSign, Enum.NormalId.Right, "COMMON ROOM ★ SHOPS", Color3.new(1, 1, 1))
	-- painted lower walls
	Build.box(
		parent,
		"Paint",
		Vector3.new(x0, 0, z0),
		Vector3.new(x1, 6, z0 + 0.1),
		C.wallLow,
		{ CanCollide = false }
	)
	Build.box(
		parent,
		"Paint",
		Vector3.new(x0, 0, z1 - 0.1),
		Vector3.new(x1, 6, z1),
		C.wallLow,
		{ CanCollide = false }
	)
	for i = 0, 2 do
		for j = 0, 1 do
			local lamp = Build.part(
				parent,
				"Lamp",
				Vector3.new(6, 0.5, 6),
				CFrame.new(x0 + 22 + i * 38, h - 0.25, -22 + j * 44),
				Color3.fromRGB(255, 248, 225),
				{ Material = Enum.Material.Neon }
			)
			Build.light(lamp, Color3.fromRGB(255, 238, 205), 50, 1.1)
		end
	end
	-- tables with benches in the middle
	for i = 0, 1 do
		local tx = cr.x - 14 + i * 28
		Build.part(
			parent,
			"Table",
			Vector3.new(12, 0.6, 5),
			CFrame.new(tx, 3, 0),
			Color3.fromRGB(120, 124, 130),
			{
				Material = Enum.Material.Metal,
			}
		)
		Build.part(parent, "Leg", Vector3.new(1, 3, 1), CFrame.new(tx, 1.4, 0), C.bars)
		for _, dz in { -4, 4 } do
			Build.part(
				parent,
				"Bench",
				Vector3.new(12, 0.5, 1.8),
				CFrame.new(tx, 1.8, dz),
				Color3.fromRGB(120, 124, 130)
			)
		end
	end
	-- wall clock + PA speaker
	local clock = Build.part(
		parent,
		"Clock",
		Vector3.new(4, 4, 0.4),
		CFrame.new(cr.x, 16, z0 + 0.3),
		Color3.new(1, 1, 1)
	)
	Build.sign(clock, Enum.NormalId.Back, "🕒", Color3.new(0, 0, 0), Color3.new(1, 1, 1))
	Build.part(
		parent,
		"Speaker",
		Vector3.new(2.4, 1.6, 1.4),
		CFrame.new(cr.x + 10, 20, z0 + 0.8),
		Color3.fromRGB(60, 60, 64)
	)

	local shops: { [string]: BasePart } = {}
	-- counters face into the room (their keeper stands between counter and wall)
	shops.Workshop = counter(
		parent,
		"Workshop",
		"🔨 WORKSHOP",
		CFrame.new(cr.x + 20, 0, z0 + 10) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(230, 130, 40)
	)
	shops.Commissary = counter(
		parent,
		"Commissary",
		"🎒 COMMISSARY",
		CFrame.new(cr.x + 20, 0, z1 - 10),
		Color3.fromRGB(60, 150, 230)
	)
	shops.Fence = counter(
		parent,
		"Fence",
		"💰 THE FENCE",
		CFrame.new(cr.x - 30, 0, z1 - 10),
		Color3.fromRGB(150, 80, 200)
	)
	return shops
end

-- ===== Yard =====

local function buildYard(parent: Instance): (BasePart, { BasePart })
	local y = World.Yard
	local x0, x1 = y.x - y.sx / 2, y.x + y.sx / 2
	local z0, z1 = y.z - y.sz / 2, y.z + y.sz / 2
	Build.box(parent, "YardGround", Vector3.new(x0, -4, z0), Vector3.new(x1, 0, z1), C.grass, {
		Material = Enum.Material.Grass,
	})
	Build.box(
		parent,
		"Court",
		Vector3.new(x0 + 20, 0, -18),
		Vector3.new(x1 - 30, 0.1, 18),
		Color3.fromRGB(150, 140, 130),
		{
			Material = Enum.Material.Asphalt,
		}
	)
	-- outside ground so the prison doesn't float
	for _, zr in { { -1300, 0 }, { 0, 1300 } } do
		Build.box(
			parent,
			"Outside",
			Vector3.new(x0 - 300, -5, zr[1]),
			Vector3.new(x1 + 1000, -4, zr[2]),
			Color3.fromRGB(80, 130, 60),
			{
				Material = Enum.Material.Grass,
			}
		)
	end
	-- fences: posts + see-through mesh panels
	local fence = Color3.fromRGB(150, 155, 160)
	local function fenceLine(a: Vector3, b: Vector3)
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid, b) * CFrame.new(0, 7, 0)
		Build.part(parent, "FenceMesh", Vector3.new(0.3, 14, len), cf, fence, {
			Material = Enum.Material.DiamondPlate,
			Transparency = 0.55,
		})
		Build.part(
			parent,
			"Wire",
			Vector3.new(0.6, 0.6, len),
			cf * CFrame.new(0, 7.6, 0),
			Color3.fromRGB(110, 110, 115),
			{
				Material = Enum.Material.Metal,
			}
		)
		local n = math.floor(len / 12)
		for i = 0, n do
			local p = a:Lerp(b, i / math.max(1, n))
			Build.part(
				parent,
				"Post",
				Vector3.new(0.7, 15, 0.7),
				CFrame.new(p + Vector3.new(0, 7.5, 0)),
				fence,
				{
					Material = Enum.Material.Metal,
				}
			)
		end
	end
	fenceLine(Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0))
	fenceLine(Vector3.new(x0, 0, z1), Vector3.new(x1, 0, z1))
	fenceLine(Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1))
	local crHalf = World.CommonRoom.sz / 2 + 4
	fenceLine(Vector3.new(x1, 0, z0), Vector3.new(x1, 0, -crHalf))
	fenceLine(Vector3.new(x1, 0, crHalf), Vector3.new(x1, 0, z1))
	-- guard tower in the far corner
	local tx, tz = x0 + 10, z0 + 10
	for _, d in { { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } } do
		Build.part(
			parent,
			"TowerLeg",
			Vector3.new(1, 22, 1),
			CFrame.new(tx + d[1], 11, tz + d[2]),
			Color3.fromRGB(90, 80, 70),
			{
				Material = Enum.Material.Wood,
			}
		)
	end
	Build.part(
		parent,
		"TowerCabin",
		Vector3.new(10, 6, 10),
		CFrame.new(tx, 25, tz),
		Color3.fromRGB(200, 190, 170),
		{
			Material = Enum.Material.WoodPlanks,
		}
	)
	Build.part(
		parent,
		"TowerRoof",
		Vector3.new(12, 1, 12),
		CFrame.new(tx, 28.5, tz),
		Color3.fromRGB(150, 50, 40)
	)
	local search = Build.part(
		parent,
		"Searchlight",
		Vector3.new(2, 2, 2),
		CFrame.new(tx + 5, 26, tz + 5),
		Color3.fromRGB(255, 255, 220),
		{
			Material = Enum.Material.Neon,
		}
	)
	local spot = Instance.new("SpotLight")
	spot.Range = 60
	spot.Angle = 40
	spot.Brightness = 3
	spot.Face = Enum.NormalId.Bottom
	spot.Parent = search
	-- floodlights on poles
	for _, p in
		{ Vector3.new(x0 + 40, 0, z1 - 6), Vector3.new(x1 - 40, 0, z1 - 6), Vector3.new(x1 - 40, 0, z0 + 6) }
	do
		Build.part(
			parent,
			"Pole",
			Vector3.new(0.8, 24, 0.8),
			CFrame.new(p + Vector3.new(0, 12, 0)),
			Color3.fromRGB(90, 90, 95)
		)
		local head = Build.part(
			parent,
			"Flood",
			Vector3.new(4, 1.5, 2),
			CFrame.new(p + Vector3.new(0, 24, 0)),
			Color3.fromRGB(255, 255, 230),
			{
				Material = Enum.Material.Neon,
			}
		)
		Build.light(head, Color3.fromRGB(255, 250, 230), 60, 1.5)
	end

	-- RUBBLE DUMP: a big skip next to the door from the Common Room
	local dumpCf = CFrame.new(x1 - 22, 0, -32)
	local dumpModel = Instance.new("Model")
	dumpModel.Name = "Dump"
	dumpModel.Parent = parent
	local dumpColor = Color3.fromRGB(230, 170, 30)
	Build.part(dumpModel, "SkipBottom", Vector3.new(16, 1, 10), dumpCf * CFrame.new(0, 0.5, 0), dumpColor, {
		Material = Enum.Material.Metal,
	})
	for _, side in { { 0, -5, 16, 0.6 }, { 0, 5, 16, 0.6 }, { -8, 0, 0.6, 10 }, { 8, 0, 0.6, 10 } } do
		Build.part(
			dumpModel,
			"SkipSide",
			Vector3.new(side[3], 6, side[4]),
			dumpCf * CFrame.new(side[1], 3, side[2]),
			dumpColor,
			{
				Material = Enum.Material.Metal,
			}
		)
	end
	local rubble = Build.part(
		dumpModel,
		"Rubble",
		Vector3.new(15, 3, 9),
		dumpCf * CFrame.new(0, 3, 0),
		Color3.fromRGB(140, 130, 120),
		{
			Material = Enum.Material.Slate,
		}
	)
	local dumpSign = Build.part(
		dumpModel,
		"Board",
		Vector3.new(16, 4, 0.5),
		dumpCf * CFrame.new(0, 10, -5.5),
		Color3.fromRGB(35, 38, 46)
	)
	Build.sign(dumpSign, Enum.NormalId.Back, "🪨 RUBBLE DUMP", Color3.fromRGB(255, 220, 90))
	Build.sign(dumpSign, Enum.NormalId.Front, "🪨 RUBBLE DUMP", Color3.fromRGB(255, 220, 90))
	local dumpPrompt = Build.prompt(rubble, "Dump rubble", "Rubble Dump", Economy.DumpRange)
	dumpPrompt.Name = "DumpPrompt"
	CollectionService:AddTag(rubble, "Dump")

	-- GYM: one station per Economy.Gym entry
	local stations: { BasePart } = {}
	for i, st in Economy.Gym do
		local cf = CFrame.new(x1 - 30 - (i - 1) * 16, 0, 34)
		local m = Instance.new("Model")
		m.Name = "Gym" .. i
		m.Parent = parent
		local mat = Build.part(
			m,
			"Mat",
			Vector3.new(10, 0.3, 10),
			cf * CFrame.new(0, 0.15, 0),
			Color3.fromRGB(50, 50, 60),
			{
				Material = Enum.Material.Rubber,
			}
		)
		local metal = Color3.fromRGB(80, 84, 92)
		if i == 1 then
			Build.part(
				m,
				"Bench",
				Vector3.new(2, 1.6, 6),
				cf * CFrame.new(0, 1.1, 0),
				Color3.fromRGB(200, 40, 40)
			)
			Build.part(m, "Bar", Vector3.new(7, 0.3, 0.3), cf * CFrame.new(0, 3.4, -1.5), metal)
			for _, dx in { -3.2, 3.2 } do
				Build.part(
					m,
					"Plate",
					Vector3.new(0.5, 2, 2),
					cf * CFrame.new(dx, 3.4, -1.5),
					Color3.fromRGB(30, 30, 30)
				)
				Build.part(
					m,
					"Upright",
					Vector3.new(0.3, 3.4, 0.3),
					cf * CFrame.new(dx * 0.8, 1.7, -1.5),
					metal
				)
			end
		elseif i == 2 then
			Build.part(m, "Rack", Vector3.new(6, 2.4, 1.6), cf * CFrame.new(0, 1.2, 0), metal)
			for k = -2, 2 do
				Build.part(
					m,
					"Dumbbell",
					Vector3.new(0.9, 0.9, 1.6),
					cf * CFrame.new(k * 1.1, 2.9, 0),
					Color3.fromRGB(40, 120, 220)
				)
			end
		else
			Build.part(m, "Barbell", Vector3.new(9, 0.4, 0.4), cf * CFrame.new(0, 1.3, 0), metal)
			for _, dx in { -4, 4 } do
				Build.part(
					m,
					"Plate",
					Vector3.new(0.7, 2.6, 2.6),
					cf * CFrame.new(dx, 1.3, 0),
					Color3.fromRGB(230, 170, 30)
				)
			end
		end
		local board = Build.part(
			m,
			"Board",
			Vector3.new(9, 3.4, 0.4),
			cf * CFrame.new(0, 7, 5),
			Color3.fromRGB(35, 38, 46)
		)
		local need = if st.minStrength > 0
			then string.format("\nneeds %d 💪", st.minStrength)
			else "\nfree for all"
		Build.sign(
			board,
			Enum.NormalId.Front,
			string.format("%s %s +%d%s", st.emoji, string.upper(st.name), st.gain, need),
			Color3.fromRGB(255, 235, 120)
		)
		mat:SetAttribute("Station", i)
		CollectionService:AddTag(mat, "GymStation")
		table.insert(stations, mat)
	end
	local gymSign =
		Build.part(parent, "GymSign", Vector3.new(0.5, 5, 20), CFrame.new(x1 - 10, 8, 34), C.orange)
	Build.sign(gymSign, Enum.NormalId.Left, "💪 GYM", Color3.new(1, 1, 1))
	Build.sign(gymSign, Enum.NormalId.Right, "💪 GYM", Color3.new(1, 1, 1))
	return rubble, stations
end

local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(110, 110, 118)
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 140)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.GlobalShadows = true
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ZoneTint"
	cc.Saturation = 0.08
	cc.Contrast = 0.05
	cc.Parent = Lighting
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.25
	atm.Haze = 1
	atm.Color = Color3.fromRGB(200, 210, 225)
	atm.Parent = Lighting
end

function WorldBuilder.build(): WorldRecord
	local old = workspace:FindFirstChild("Prison")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Prison"
	root.Parent = workspace
	local block = Instance.new("Folder")
	block.Name = "CellBlock"
	block.Parent = root
	buildRowShell(block, 0)
	buildRowShell(block, 1)
	buildCorridor(block)
	local cellsFolder = Instance.new("Folder")
	cellsFolder.Name = "Cells"
	cellsFolder.Parent = root
	local cells = {}
	for i = 1, World.CellCount do
		cells[i] = buildCell(cellsFolder, i)
	end
	local common = Instance.new("Folder")
	common.Name = "CommonRoom"
	common.Parent = root
	local shops = buildCommonRoom(common)
	local yard = Instance.new("Folder")
	yard.Name = "Yard"
	yard.Parent = root
	local dump, stations = buildYard(yard)
	setupLighting()
	return { cells = cells, shops = shops, dump = dump, stations = stations }
end

return WorldBuilder
