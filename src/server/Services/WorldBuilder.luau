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
local Cycle = require(Shared.Config.Cycle)
local LockerConfig = require(Shared.Config.Locker)
local Build = require(script.Parent.Parent.Util.Build)
local Props = require(script.Parent.Parent.Util.Props)
local GymProps = require(script.Parent.Parent.Util.GymProps)
local Dressing = require(script.Parent.Parent.Util.Dressing)
local Facade = require(script.Parent.Parent.Util.Facade)
local Format = require(Shared.Format)

local WorldBuilder = {}

export type CellRecord = {
	index: number,
	frame: CFrame,
	spawn: CFrame,
	sign: TextLabel,
	model: Model,
	door: Model,
	doorOpen: CFrame,
	doorClosed: CFrame,
	doorBlock: BasePart,
	shelf: Frame, -- collection slots (Services/Collection fills it)
	stash: BasePart,
	toilet: BasePart, -- FlushPrompt: the night dump (Loot.flush)
	locker: BasePart, -- LockerPrompt: the LIFER'S LOCKER (Services/Locker)
}

export type WorldRecord = {
	cells: { CellRecord },
	boards: { [string]: Frame },
	shops: { [string]: BasePart },
	dump: BasePart,
	stations: { BasePart },
}

-- the prison palette: grey concrete, dirty green paint, dark steel, worn yellow lines
local C = {
	floor = Color3.fromRGB(88, 90, 92),
	corridorFloor = Color3.fromRGB(74, 76, 80),
	wall = Color3.fromRGB(128, 130, 132),
	wallLow = Color3.fromRGB(52, 72, 66), -- painted lower half of prison walls
	ceiling = Color3.fromRGB(95, 97, 100),
	bedrock = Color3.fromRGB(34, 33, 38),
	bars = Color3.fromRGB(58, 62, 68),
	line = Color3.fromRGB(176, 150, 46),
	grass = Color3.fromRGB(84, 82, 76), -- the yard: trampled gravel and dirt
	orange = Color3.fromRGB(46, 49, 54), -- sign plates: dark steel
	lamp = Color3.fromRGB(225, 235, 240), -- cold fluorescent tubes
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
			Material = Enum.Material.Pavement,
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
		local l0, l1 = zz(HALF_CORR + 2, BACK_Z - 0.05)
		Build.box(
			parent,
			"CellWallLow",
			Vector3.new(x - 2.1, 0, l0),
			Vector3.new(x + 2.1, 6, l1),
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

-- The LIFER'S LOCKER in a cell: steel body, a door with vents, a handle, a padlock and a name
-- plate, its back against the front wall. `x` = center across the cell, s = the row's direction.
-- Returns the body (it holds the prompt).
local function buildLocker(
	model: Instance,
	inCell: (x: number, y: number, d: number) -> CFrame,
	s: number,
	x: number
): BasePart
	local steel = Color3.fromRGB(74, 92, 104)
	local dark = Color3.fromRGB(34, 38, 44)
	local metal = { Material = Enum.Material.Metal }
	local m = Instance.new("Model")
	m.Name = "Locker"
	m.Parent = model
	local body = Build.part(m, "LockerBody", Vector3.new(2.8, 6.4, 1.8), inCell(x, 3.2, 1.0), steel, metal)
	Build.part(m, "LockerCap", Vector3.new(2.9, 0.15, 1.9), inCell(x, 6.475, 1.0), dark, metal)
	Build.part(
		m,
		"LockerDoor",
		Vector3.new(2.5, 6.0, 0.1),
		inCell(x, 3.2, 1.95),
		steel:Lerp(Color3.new(1, 1, 1), 0.08),
		metal
	)
	for i = 0, 3 do
		Build.part(
			m,
			"LockerVent",
			Vector3.new(1.8, 0.12, 0.05),
			inCell(x, 5.1 + i * 0.22, 2.025),
			dark,
			{ CanCollide = false }
		)
	end
	-- the handle and a brass padlock (a lifer keeps the good stuff locked up)
	local hx = x + 0.85 -- (the hinge side is against the side wall)
	Build.part(m, "LockerHandle", Vector3.new(0.14, 0.8, 0.14), inCell(hx, 3.4, 2.07), dark, metal)
	Build.part(
		m,
		"LockerPadlock",
		Vector3.new(0.36, 0.42, 0.16),
		inCell(hx, 2.8, 2.08),
		Color3.fromRGB(214, 170, 60),
		metal
	)
	local plate = Build.part(
		m,
		"LockerPlate",
		Vector3.new(1.9, 0.5, 0.05),
		inCell(x, 4.4, 2.025),
		Color3.fromRGB(28, 30, 36),
		{ CanCollide = false }
	)
	Build.sign(
		plate,
		if s < 0 then Enum.NormalId.Front else Enum.NormalId.Back,
		"🗝️ LIFER",
		Color3.fromRGB(255, 220, 120)
	)
	local prompt = Build.prompt(body, "Open", "Lifer's Locker", LockerConfig.Range)
	prompt.Name = "LockerPrompt"
	return body
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
	-- the barred door: slid open by day, across the doorway at night (DayNight moves it)
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
	local doorOpen = CFrame.new(cx - doorHalf - 3.5, doorH / 2, doorZ)
	door.WorldPivot = doorOpen
	local doorClosed = doorOpen + Vector3.new(doorHalf + 3.5, 0, 0)
	local doorBlock = Build.part(
		model,
		"DoorBlock",
		Vector3.new(doorHalf * 2, doorH, 1),
		CFrame.new(cx, doorH / 2, doorZ),
		C.bars,
		{ Transparency = 1, CanCollide = false }
	)
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
	-- bed, toilet, sink (Util/Props: detailed; the named parts keep their jobs)
	Props.bed(model, inCell, -halfW + 2.2, 9, Color3.fromRGB(190, 92, 40))
	local toilet = Props.toilet(model, inCell, halfW - 1.6, 14)
	-- at night the toilet is your rubble dump (Loot.flush)
	local flush = Build.prompt(
		toilet,
		"Flush rubble",
		"Toilet · " .. math.floor(Economy.FlushRate * 100) .. "%",
		Economy.FlushRange
	)
	flush.Name = "FlushPrompt"
	flush.Enabled = false
	Props.sink(model, inCell, halfW - 1.4, 4, 9)
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
	local lamp = Build.part(model, "Lamp", Vector3.new(4, 0.5, 2), inCell(0, H - 0.25, 8), C.lamp, {
		Material = Enum.Material.Neon,
	})
	Build.light(lamp, Color3.fromRGB(215, 228, 235), 30, 1.2)
	-- where you spawn: inside, facing the back wall
	local spawnPos = Vector3.new(cx, 3, (HALF_CORR + 13) * s)
	local spawn = CFrame.lookAt(spawnPos, spawnPos + Vector3.new(0, 0, s))
	model:SetAttribute("Cell", index)
	-- Stash chest (raiders can steal ONE find from it by day)
	local stashCf = inCell(halfW - 2, 0, 3) * CFrame.Angles(0, -math.pi / 2, 0)
	local stash = Build.part(
		model,
		"Stash",
		Vector3.new(3.4, 2.2, 2.2),
		stashCf * CFrame.new(0, 1.1, 0),
		Color3.fromRGB(150, 100, 50),
		{
			Material = Enum.Material.WoodPlanks,
		}
	)
	Build.part(
		model,
		"StashLid",
		Vector3.new(3.6, 0.5, 2.4),
		stashCf * CFrame.new(0, 2.45, 0),
		Color3.fromRGB(120, 80, 40),
		{
			Material = Enum.Material.WoodPlanks,
		}
	)
	Build.part(
		model,
		"StashBand",
		Vector3.new(3.7, 0.3, 0.3),
		stashCf * CFrame.new(0, 1.6, -1.15),
		Color3.fromRGB(230, 190, 60),
		{
			Material = Enum.Material.Metal,
		}
	)
	local stashPrompt = Build.prompt(stash, "Stash", "Stash chest", 9)
	stashPrompt.Name = "StashPrompt"
	stash:SetAttribute("Cell", index)
	CollectionService:AddTag(stash, "Stash")
	-- LIFER'S LOCKER: a tall steel locker in the front corner by the bed (between the front wall
	-- and the desk; clear of the bed, the door, the back wall and the shelf above the bed)
	local locker = buildLocker(model, inCell, s, -halfW + 1.5)
	-- collection shelf above the bed: one slot per find, silhouettes for the missing ones
	local shelfPart = Build.part(
		model,
		"Shelf",
		Vector3.new(0.4, 7, 13),
		inCell(-halfW + 0.2, 10.5, 9),
		Color3.fromRGB(110, 78, 50),
		{ Material = Enum.Material.WoodPlanks }
	)
	local shelfGui = Instance.new("SurfaceGui")
	shelfGui.Name = "Collection"
	shelfGui.Face = Enum.NormalId.Right
	shelfGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	shelfGui.PixelsPerStud = 24
	shelfGui.LightInfluence = 0.3
	shelfGui.Parent = shelfPart
	local shelf = Instance.new("Frame")
	shelf.Name = "Slots"
	shelf.BackgroundTransparency = 1
	shelf.Size = UDim2.fromScale(1, 1)
	shelf.Parent = shelfGui
	return {
		index = index,
		frame = frame,
		spawn = spawn,
		sign = sign,
		model = model,
		door = door,
		doorOpen = doorOpen,
		doorClosed = doorClosed,
		doorBlock = doorBlock,
		shelf = shelf,
		stash = stash,
		toilet = toilet,
		locker = locker,
	}
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
			C.lamp,
			{ Material = Enum.Material.Neon }
		)
		Build.light(lamp, Color3.fromRGB(215, 228, 235), 40, 1)
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

-- ===== prison-style vendor stations =====
-- Every station is a Model named after the shop with a part "Counter" that holds the prompt
-- (Shop attribute + "Shop" tag). `cf` = floor center of the counter; customers stand at local -Z,
-- the vendor and the props sit behind it (local +Z, up to ~6 studs).

local STEEL = Color3.fromRGB(70, 74, 80)
local DARK_STEEL = Color3.fromRGB(44, 47, 52)

local function plate(m: Instance, title: string, cf: CFrame, width: number?)
	local p = Build.part(
		m,
		"Sign",
		Vector3.new(width or 12, 2.4, 0.3),
		cf,
		DARK_STEEL,
		{ Material = Enum.Material.Metal }
	)
	Build.sign(p, Enum.NormalId.Front, title, Color3.fromRGB(235, 205, 90))
	return p
end

local function finishCounter(top: BasePart, name: string, title: string, action: string)
	local prompt = Build.prompt(top, action, title, Economy.ShopRange)
	prompt.Name = "ShopPrompt"
	top:SetAttribute("Shop", name)
	CollectionService:AddTag(top, "Shop")
end

-- vertical bars across an opening (x from -w/2 to w/2 around cf, height h)
local function bars(m: Instance, cf: CFrame, w: number, h: number, step: number?)
	local st = step or 0.9
	local n = math.floor(w / st)
	for i = 0, n do
		Build.part(
			m,
			"Bar",
			Vector3.new(0.18, h, 0.18),
			cf * CFrame.new(-w / 2 + i * w / n, h / 2, 0),
			STEEL,
			{
				Material = Enum.Material.Metal,
			}
		)
	end
end

local function station(parent: Instance, name: string, title: string, cf: CFrame, kind: string): BasePart
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	local top: BasePart
	if kind == "ToolCrib" then
		-- chain-link cage with a service window, pegboard of tools, workbench with a vise
		top = Build.part(m, "Counter", Vector3.new(6, 0.5, 2.4), cf * CFrame.new(0, 3.6, -0.2), STEEL, {
			Material = Enum.Material.DiamondPlate,
		})
		for _, side in { -1, 1 } do
			Build.part(
				m,
				"Mesh",
				Vector3.new(4.5, 10, 0.2),
				cf * CFrame.new(side * 5.25, 5, 0),
				Color3.fromRGB(140, 145, 150),
				{
					Material = Enum.Material.DiamondPlate,
					Transparency = 0.45,
				}
			)
			Build.part(
				m,
				"Post",
				Vector3.new(0.5, 10.4, 0.5),
				cf * CFrame.new(side * 7.5, 5.2, 0),
				STEEL,
				{ Material = Enum.Material.Metal }
			)
		end
		Build.part(
			m,
			"MeshLow",
			Vector3.new(5.9, 3.3, 0.2),
			cf * CFrame.new(0, 1.65, 0),
			Color3.fromRGB(140, 145, 150),
			{
				Material = Enum.Material.DiamondPlate,
				Transparency = 0.45,
			}
		)
		Build.part(
			m,
			"MeshTop",
			Vector3.new(6, 3, 0.2),
			cf * CFrame.new(0, 8.5, 0),
			Color3.fromRGB(140, 145, 150),
			{
				Material = Enum.Material.DiamondPlate,
				Transparency = 0.45,
			}
		)
		Build.part(
			m,
			"Pegboard",
			Vector3.new(14, 6, 0.3),
			cf * CFrame.new(0, 6, 5.8),
			Color3.fromRGB(120, 95, 70),
			{
				Material = Enum.Material.Wood,
			}
		)
		-- tool silhouettes on the pegboard
		local tools = {
			{ -5, 7, 0.4, 3, 0 }, -- shovel handle
			{ -5, 5.3, 1.2, 1, 0 },
			{ -2.5, 6.5, 0.3, 2.6, 0.5 }, -- wrench
			{ 0, 6.5, 2.4, 0.4, 0 }, -- saw
			{ 0, 6, 2.4, 0.8, 0 },
			{ 2.5, 7, 0.35, 2.2, -0.4 }, -- hammer
			{ 2.8, 7.9, 1.2, 0.5, -0.4 },
			{ 5, 6.5, 0.6, 2.8, 0 }, -- pickaxe
			{ 5, 7.8, 2.4, 0.4, 0.2 },
		}
		for k, t in tools do
			Build.part(
				m,
				"Tool",
				Vector3.new(t[3], t[4], 0.2),
				cf * CFrame.new(t[1], t[2], 5.6 - k * 0.04) * CFrame.Angles(0, 0, t[5]),
				DARK_STEEL,
				{
					Material = Enum.Material.Metal,
				}
			)
		end
		Build.part(
			m,
			"Workbench",
			Vector3.new(10, 0.6, 3),
			cf * CFrame.new(0, 3.2, 3.6),
			Color3.fromRGB(110, 85, 60),
			{
				Material = Enum.Material.WoodPlanks,
			}
		)
		Build.part(
			m,
			"Vise",
			Vector3.new(1, 0.9, 0.9),
			cf * CFrame.new(-3.5, 3.95, 3.2),
			Color3.fromRGB(40, 70, 110),
			{
				Material = Enum.Material.Metal,
			}
		)
		local keeper = Build.inmate(m, "Keeper", cf * CFrame.new(1.5, 0, 2.1))
		-- welding goggles
		local head = keeper:FindFirstChild("Head") :: BasePart
		Build.part(
			keeper,
			"Goggles",
			Vector3.new(1.56, 0.35, 0.2),
			head.CFrame * CFrame.new(0, 0.2, -0.82),
			Color3.fromRGB(30, 30, 30)
		)
		plate(m, title, cf * CFrame.new(0, 10.6, -0.2))
	elseif kind == "Commissary" then
		-- concrete wall with a barred window and a slot, shelves of ramen behind it
		local wallColor = Color3.fromRGB(118, 120, 122)
		Build.part(
			m,
			"Wall",
			Vector3.new(14, 3.4, 1),
			cf * CFrame.new(0, 1.7, 0.3),
			wallColor,
			{ Material = Enum.Material.Concrete }
		)
		Build.part(
			m,
			"Wall",
			Vector3.new(14, 3.6, 1),
			cf * CFrame.new(0, 9.2, 0.3),
			wallColor,
			{ Material = Enum.Material.Concrete }
		)
		Build.part(
			m,
			"Wall",
			Vector3.new(4, 4, 1),
			cf * CFrame.new(-5, 5.4, 0.3),
			wallColor,
			{ Material = Enum.Material.Concrete }
		)
		Build.part(
			m,
			"Wall",
			Vector3.new(4, 4, 1),
			cf * CFrame.new(5, 5.4, 0.3),
			wallColor,
			{ Material = Enum.Material.Concrete }
		)
		bars(m, cf * CFrame.new(0, 3.4, -0.35), 6, 4, 0.75)
		top = Build.part(m, "Counter", Vector3.new(6, 0.35, 1.6), cf * CFrame.new(0, 3.55, -0.6), STEEL, {
			Material = Enum.Material.Metal,
		})
		for row = 0, 2 do
			Build.part(
				m,
				"Shelf",
				Vector3.new(12, 0.3, 1.6),
				cf * CFrame.new(0, 2 + row * 2.6, 5.3),
				Color3.fromRGB(90, 92, 96),
				{
					Material = Enum.Material.Metal,
				}
			)
			for i = 0, 9 do
				local packColor = if (i + row) % 3 == 0
					then Color3.fromRGB(200, 60, 40)
					elseif (i + row) % 3 == 1 then Color3.fromRGB(230, 170, 40)
					else Color3.fromRGB(60, 120, 200)
				Build.part(
					m,
					"Ramen",
					Vector3.new(0.9, 0.9, 0.4),
					cf * CFrame.new(-5 + i * 1.1, 2.65 + row * 2.6, 5.2),
					packColor
				)
			end
		end
		Build.npc(
			m,
			"Clerk",
			cf * CFrame.new(0, 0, 2.4),
			Color3.fromRGB(70, 90, 120),
			Color3.fromRGB(30, 40, 60)
		)
		local board = Build.part(
			m,
			"Prices",
			Vector3.new(3.6, 2.6, 0.2),
			cf * CFrame.new(-5, 5.4, -0.25),
			Color3.fromRGB(30, 34, 30)
		)
		Build.sign(
			board,
			Enum.NormalId.Front,
			"RAMEN 🍜\nSOAP · SOCKS\nNO CREDIT",
			Color3.fromRGB(230, 230, 220)
		)
		plate(m, title, cf * CFrame.new(0, 11.8, -0.25))
	elseif kind == "Fence" then
		-- a shady inmate on an upturned bucket with a laundry cart full of "goods"
		top = Build.part(
			m,
			"Counter",
			Vector3.new(4.6, 2.6, 3),
			cf * CFrame.new(-2.5, 1.8, 0.6),
			Color3.fromRGB(150, 150, 160),
			{
				Material = Enum.Material.Fabric,
			}
		)
		Build.part(
			m,
			"CartFrame",
			Vector3.new(4.8, 0.3, 3.2),
			cf * CFrame.new(-2.5, 0.5, 0.6),
			STEEL,
			{ Material = Enum.Material.Metal }
		)
		for _, g in
			{
				{ -3.5, 3.4, 0.2, Color3.fromRGB(200, 170, 50) },
				{ -2, 3.5, 1, Color3.fromRGB(120, 60, 160) },
				{ -1.2, 3.3, 0.1, Color3.fromRGB(60, 160, 120) },
			}
		do
			Build.part(
				m,
				"Goods",
				Vector3.new(1.2, 1, 1),
				cf * CFrame.new(g[1], g[2], g[3]) * CFrame.Angles(0.3, 0.6, 0),
				g[4],
				{
					Material = Enum.Material.Neon,
					Transparency = 0.2,
				}
			)
		end
		for i, c in { { 2, 0.8, 1.5 }, { 3.8, 0.8, 1.2 }, { 2.9, 2.3, 1.3 } } do
			Build.part(
				m,
				"Crate",
				Vector3.new(1.6, 1.5, 1.6),
				cf * CFrame.new(c[1], c[2], c[3] + 2) * CFrame.Angles(0, i * 0.4, 0),
				Color3.fromRGB(40, 90, 160),
				{
					Material = Enum.Material.Plastic,
				}
			)
		end
		Build.part(
			m,
			"Bucket",
			Vector3.new(1.6, 1.4, 1.6),
			cf * CFrame.new(1.5, 0.7, 1.5),
			Color3.fromRGB(70, 90, 110),
			{
				Shape = Enum.PartType.Cylinder,
				Orientation = Vector3.new(0, 0, 90),
			}
		)
		local guy = Build.inmate(
			m,
			"Fence",
			cf * CFrame.new(1.5, 1.2, 1.5) * CFrame.Angles(0, math.rad(-20), 0),
			Color3.fromRGB(30, 30, 35)
		)
		local head = guy:FindFirstChild("Head") :: BasePart
		Build.part(
			guy,
			"Shades",
			Vector3.new(1.52, 0.35, 0.2),
			head.CFrame * CFrame.new(0, 0.18, -0.82),
			Color3.fromRGB(10, 10, 12)
		)
		-- blanket hung as a curtain behind him
		Build.part(
			m,
			"Curtain",
			Vector3.new(12, 9, 0.2),
			cf * CFrame.new(0, 4.5, 5.5),
			Color3.fromRGB(110, 40, 50),
			{
				Material = Enum.Material.Fabric,
			}
		)
		local card = Build.part(
			m,
			"Cardboard",
			Vector3.new(3.2, 2, 0.15),
			cf * CFrame.new(-2.5, 4.1, -0.95) * CFrame.Angles(-0.2, 0, 0.05),
			Color3.fromRGB(170, 130, 80)
		)
		Build.sign(
			card,
			Enum.NormalId.Front,
			"WE BUY\nSTUFF",
			Color3.fromRGB(40, 30, 20),
			Color3.fromRGB(170, 130, 80)
		)
		plate(m, title, cf * CFrame.new(0, 9.8, 5.3))
	elseif kind == "Visitation" then
		-- glass partition with phones: gifts from the outside world (the Robux store)
		Build.part(
			m,
			"Desk",
			Vector3.new(14, 3.4, 1.4),
			cf * CFrame.new(0, 1.7, 0),
			Color3.fromRGB(105, 108, 112),
			{
				Material = Enum.Material.Concrete,
			}
		)
		top = Build.part(
			m,
			"Counter",
			Vector3.new(14, 0.3, 1.8),
			cf * CFrame.new(0, 3.55, -0.2),
			Color3.fromRGB(140, 142, 146),
			{
				Material = Enum.Material.Metal,
			}
		)
		Build.part(
			m,
			"Glass",
			Vector3.new(14, 6, 0.2),
			cf * CFrame.new(0, 6.7, 0.4),
			Color3.fromRGB(190, 220, 230),
			{
				Material = Enum.Material.Glass,
				Transparency = 0.6,
			}
		)
		for i = -1, 1 do
			Build.part(
				m,
				"Divider",
				Vector3.new(0.3, 6.3, 2),
				cf * CFrame.new(i * 4.6 + 2.3, 6.85, -0.4),
				Color3.fromRGB(105, 108, 112)
			)
			Build.part(
				m,
				"Phone",
				Vector3.new(0.5, 1.2, 0.4),
				cf * CFrame.new(i * 4.6 - 1.2, 5.2, 0.2),
				Color3.fromRGB(25, 25, 28)
			)
			Build.part(
				m,
				"Stool",
				Vector3.new(1.4, 0.4, 1.4),
				cf * CFrame.new(i * 4.6, 1.9, -2.2),
				Color3.fromRGB(150, 40, 40)
			)
			Build.part(m, "StoolLeg", Vector3.new(0.3, 1.8, 0.3), cf * CFrame.new(i * 4.6, 0.9, -2.2), STEEL)
		end
		Build.npc(
			m,
			"Visitor",
			cf * CFrame.new(0, 0, 2.6),
			Color3.fromRGB(230, 200, 60),
			Color3.fromRGB(200, 60, 120)
		)
		plate(m, title, cf * CFrame.new(0, 10.6, 0.4), 13)
	elseif kind == "Laundry" then
		-- folding table with stacks of uniforms, carts, a steaming press
		top = Build.part(
			m,
			"Counter",
			Vector3.new(10, 0.5, 3.2),
			cf * CFrame.new(0, 3.2, 0),
			Color3.fromRGB(180, 182, 186),
			{
				Material = Enum.Material.Metal,
			}
		)
		for _, dx in { -4.5, 4.5 } do
			Build.part(m, "Leg", Vector3.new(0.4, 3, 0.4), cf * CFrame.new(dx, 1.5, 0), STEEL)
		end
		local colors = {
			Color3.fromRGB(214, 104, 34),
			Color3.fromRGB(230, 230, 230),
			Color3.fromRGB(60, 110, 200),
			Color3.fromRGB(255, 120, 190),
		}
		for i, c in colors do
			for k = 0, i % 3 + 1 do
				Build.part(
					m,
					"Folded",
					Vector3.new(1.8, 0.35, 1.4),
					cf * CFrame.new(-4.5 + i * 2, 3.65 + k * 0.36, 0),
					c,
					{ Material = Enum.Material.Fabric }
				)
			end
		end
		for _, dx in { -4, 4 } do
			Build.part(
				m,
				"Cart",
				Vector3.new(3, 2.4, 2.4),
				cf * CFrame.new(dx, 1.6, 4),
				Color3.fromRGB(200, 200, 205),
				{
					Material = Enum.Material.Fabric,
				}
			)
			Build.part(
				m,
				"CartLoad",
				Vector3.new(2.8, 0.8, 2.2),
				cf * CFrame.new(dx, 3, 4),
				Color3.fromRGB(240, 240, 235),
				{ Material = Enum.Material.Fabric }
			)
		end
		Build.inmate(m, "Keeper", cf * CFrame.new(0, 0, 2.2))
		plate(m, title, cf * CFrame.new(0, 8.5, 1.5))
	elseif kind == "FenceHole" then
		-- BLACK MARKET: a guy in a trench coat by a hole cut in the yard fence
		top = Build.part(
			m,
			"Counter",
			Vector3.new(3, 2.4, 2.4),
			cf * CFrame.new(-2.5, 1.2, 0),
			Color3.fromRGB(100, 80, 55),
			{
				Material = Enum.Material.WoodPlanks,
			}
		)
		Build.part(
			m,
			"Crate2",
			Vector3.new(2, 1.6, 2),
			cf * CFrame.new(-2.3, 3.2, 0.2) * CFrame.Angles(0, 0.4, 0),
			Color3.fromRGB(85, 70, 50),
			{
				Material = Enum.Material.WoodPlanks,
			}
		)
		local coat = Color3.fromRGB(95, 75, 50)
		local guy = Build.npc(m, "Dealer", cf * CFrame.new(2, 0, 1.5), coat, Color3.fromRGB(40, 35, 30), coat)
		local head = guy:FindFirstChild("Head") :: BasePart
		Build.part(
			guy,
			"Shades",
			Vector3.new(1.52, 0.35, 0.2),
			head.CFrame * CFrame.new(0, 0.18, -0.82),
			Color3.fromRGB(10, 10, 12)
		)
		Build.part(
			guy,
			"CoatTail",
			Vector3.new(2.4, 2.4, 1.3),
			cf * CFrame.new(2, 1.6, 1.5),
			coat,
			{ Material = Enum.Material.Fabric }
		)
		-- the cut flap of fence + a flashlight on the ground
		Build.part(
			m,
			"Flap",
			Vector3.new(4, 4, 0.2),
			cf * CFrame.new(0, 2, 5) * CFrame.Angles(0, 0.7, 0),
			Color3.fromRGB(140, 145, 150),
			{
				Material = Enum.Material.DiamondPlate,
				Transparency = 0.45,
			}
		)
		local light = Build.part(
			m,
			"Flashlight",
			Vector3.new(0.4, 0.4, 1.2),
			cf * CFrame.new(-0.5, 0.2, -1),
			Color3.fromRGB(30, 30, 30)
		)
		local spot = Instance.new("SpotLight")
		spot.Range = 18
		spot.Angle = 50
		spot.Brightness = 2
		spot.Color = Color3.fromRGB(255, 230, 170)
		spot.Face = Enum.NormalId.Front
		spot.Parent = light
		local card = Build.part(
			m,
			"Cardboard",
			Vector3.new(2.6, 1.6, 0.15),
			cf * CFrame.new(-2.5, 2.6, -1.25),
			Color3.fromRGB(170, 130, 80)
		)
		Build.sign(
			card,
			Enum.NormalId.Front,
			"PSST...",
			Color3.fromRGB(40, 30, 20),
			Color3.fromRGB(170, 130, 80)
		)
		plate(m, title, cf * CFrame.new(0, 6.5, 2.5), 10)
	else
		error("unknown station " .. kind)
	end
	finishCounter(
		top,
		name,
		title,
		if kind == "Visitation"
			then "Visit"
			elseif kind == "Fence" or kind == "FenceHole" then "Trade"
			else "Open"
	)
	return top
end

local function buildCommonRoom(parent: Instance, boards: { [string]: Frame }): { [string]: BasePart }
	local cr = World.CommonRoom
	local x0, x1 = cr.x - cr.sx / 2, cr.x + cr.sx / 2
	local z0, z1 = cr.z - cr.sz / 2, cr.z + cr.sz / 2
	local h = cr.height
	Build.box(
		parent,
		"CommonFloor",
		Vector3.new(x0, -4, z0),
		Vector3.new(x1, 0, z1),
		Color3.fromRGB(96, 98, 100),
		{
			Material = Enum.Material.Wood,
		}
	)
	Build.box(parent, "CommonCeiling", Vector3.new(x0, h, z0), Vector3.new(x1, h + 2, z1), C.ceiling)
	-- walls (+X wall has the corridor opening, -X wall the door to the Yard)
	Build.box(parent, "Wall", Vector3.new(x0, 0, z0 - 4), Vector3.new(x1, h, z0), C.wall)
	-- south wall: door to the Mess Hall in the middle
	local mess = 6
	Build.box(parent, "Wall", Vector3.new(x0, 0, z1), Vector3.new(cr.x - mess, h, z1 + 4), C.wall)
	Build.box(parent, "Wall", Vector3.new(cr.x + mess, 0, z1), Vector3.new(x1, h, z1 + 4), C.wall)
	Build.box(parent, "Wall", Vector3.new(cr.x - mess, 13, z1), Vector3.new(cr.x + mess, h, z1 + 4), C.wall)
	-- floor through the doorway (the wall is 4 studs thick: there was a hole here)
	Build.box(
		parent,
		"Threshold",
		Vector3.new(cr.x - mess, -4, z1),
		Vector3.new(cr.x + mess, 0, z1 + 4),
		Color3.fromRGB(96, 98, 100),
		{ Material = Enum.Material.Concrete }
	)
	local messSign =
		Build.part(parent, "MessSign", Vector3.new(14, 3, 0.4), CFrame.new(cr.x, 15, z1 - 0.3), C.orange)
	Build.sign(messSign, Enum.NormalId.Front, "🍲 MESS HALL", Color3.new(1, 1, 1))
	Build.box(parent, "Wall", Vector3.new(x1 - 2, 0, z0), Vector3.new(x1, h, -HALF_CORR), C.wall)
	Build.box(parent, "Wall", Vector3.new(x1 - 2, 0, HALF_CORR), Vector3.new(x1, h, z1), C.wall)
	Build.box(parent, "Wall", Vector3.new(x1 - 2, H, -HALF_CORR), Vector3.new(x1, h, HALF_CORR), C.wall)
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
	Build.sign(crSign, Enum.NormalId.Right, "COMMON ROOM", Color3.new(1, 1, 1))
	-- painted lower walls
	Build.box(
		parent,
		"Paint",
		Vector3.new(x0, 0, z0),
		Vector3.new(x1 - 2, 6, z0 + 0.1),
		C.wallLow,
		{ CanCollide = false }
	)
	-- (the south band stops at the Mess Hall door)
	Build.box(
		parent,
		"Paint",
		Vector3.new(x0, 0, z1 - 0.1),
		Vector3.new(cr.x - mess, 6, z1),
		C.wallLow,
		{ CanCollide = false }
	)
	Build.box(
		parent,
		"Paint",
		Vector3.new(cr.x + mess, 0, z1 - 0.1),
		Vector3.new(x1 - 2, 6, z1),
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
				C.lamp,
				{ Material = Enum.Material.Neon }
			)
			Build.light(lamp, Color3.fromRGB(215, 228, 235), 50, 1.1)
		end
	end
	-- prison tables (steel, stools welded on) in the middle
	for i, tx in { cr.x - 18, cr.x - 10, cr.x + 10, cr.x + 18 } do
		Props.prisonTable(
			parent,
			Vector3.new(tx, 0, 0),
			(i % 2) * 0.3,
			if i == 2 then "chess" elseif i == 3 then "cards" else nil
		)
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

	-- TOP DOG (richest prisoner on the server) and LONGEST TUNNEL boards
	local function board(name: string, title: string, cf: CFrame, color: Color3): Frame
		local b = Build.part(parent, name, Vector3.new(20, 12, 0.5), cf, Color3.fromRGB(30, 32, 40))
		Build.part(parent, name .. "Frame", Vector3.new(21, 13, 0.3), cf * CFrame.new(0, 0, 0.2), color)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.LightInfluence = 0
		gui.Parent = b
		local frame = Instance.new("Frame")
		frame.Name = "List"
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(1, 1)
		frame.Parent = gui
		local t = Instance.new("TextLabel")
		t.Name = "Title"
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 0.2)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = color
		t.Text = title
		t.Parent = frame
		local body = Instance.new("TextLabel")
		body.Name = "Body"
		body.BackgroundTransparency = 1
		body.Position = UDim2.fromScale(0.04, 0.22)
		body.Size = UDim2.fromScale(0.92, 0.74)
		body.Font = Enum.Font.FredokaOne
		body.TextScaled = true
		body.TextColor3 = Color3.new(1, 1, 1)
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.Text = "..."
		body.Parent = frame
		return frame
	end
	boards.TopDog = board(
		"TopDogBoard",
		"🐶 TOP DOG",
		CFrame.new(cr.x - 23, 13, z0 + 0.3) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(255, 205, 60)
	)
	boards.Depth = board(
		"DepthBoard",
		"🏃 ESCAPE ARTISTS",
		CFrame.new(x0 + 0.3, 13, -30) * CFrame.Angles(0, -math.pi / 2, 0),
		Color3.fromRGB(120, 200, 255)
	)
	-- the weekly race (Services/TopDog): blocks broken since Monday, every server
	boards.Week = board(
		"WeekBoard",
		"🏆 THIS WEEK",
		CFrame.new(x0 + 0.3, 13, 30) * CFrame.Angles(0, -math.pi / 2, 0),
		Color3.fromRGB(255, 170, 60)
	)

	local shops: { [string]: BasePart } = {}
	-- counters face into the room (their keeper stands between counter and wall)
	shops.Workshop = station(
		parent,
		"Workshop",
		"TOOL CRIB",
		CFrame.new(cr.x + 20, 0, z0 + 10) * CFrame.Angles(0, math.pi, 0),
		"ToolCrib"
	)
	shops.Commissary =
		station(parent, "Commissary", "COMMISSARY", CFrame.new(cr.x + 20, 0, z1 - 10), "Commissary")
	-- STORE (Robux): passes and products with known contents
	shops.Store = station(
		parent,
		"Store",
		"VISITATION",
		CFrame.new(x0 + 10, 0, 24) * CFrame.Angles(0, -math.pi / 2, 0),
		"Visitation"
	)
	-- VIP LOUNGE (south-east corner): dark wood half walls with smoked glass and gold trim, a red
	-- carpet from a velvet rope, leather couches, a minibar, plants and a chandelier. The rope's
	-- invisible blocker (tag VIPDoor) only lets VIPs through (the client opens it for them).
	local vx0, vz0 = x1 - 28, z1 - 26
	local vx1, vz1 = x1 - 2, z1 - 0.1
	local doorX0, doorX1 = x1 - 14, x1 - 2
	local GOLD = Color3.fromRGB(212, 172, 64)
	local WOOD = Color3.fromRGB(58, 36, 26)
	local gold = { Material = Enum.Material.Metal, Reflectance = 0.15 }
	Build.box(
		parent,
		"VIPFloor",
		Vector3.new(vx0, 0, vz0),
		Vector3.new(vx1, 0.16, vz1),
		Color3.fromRGB(74, 46, 32),
		{
			Material = Enum.Material.WoodPlanks,
		}
	)
	-- red carpet from the rope to the couches, with gold edges
	local cx = (doorX0 + doorX1) / 2
	Build.box(
		parent,
		"VIPCarpet",
		Vector3.new(cx - 3, 0.16, vz0),
		Vector3.new(cx + 3, 0.2, vz1 - 6),
		Color3.fromRGB(128, 18, 30),
		{
			Material = Enum.Material.Fabric,
			CanCollide = false,
		}
	)
	for _, ex in { cx - 3.3, cx + 3 } do
		Build.box(
			parent,
			"VIPCarpetEdge",
			Vector3.new(ex, 0.16, vz0),
			Vector3.new(ex + 0.3, 0.22, vz1 - 6),
			GOLD,
			{
				Material = Enum.Material.Metal,
				CanCollide = false,
			}
		)
	end
	-- half walls (west + north up to the entrance), smoked glass above, gold rails and posts
	Build.box(parent, "VIPWall", Vector3.new(vx0 - 0.6, 0, vz0), Vector3.new(vx0, 3.5, vz1), WOOD, {
		Material = Enum.Material.Wood,
	})
	Build.box(parent, "VIPWall", Vector3.new(vx0 - 0.6, 0, vz0 - 0.6), Vector3.new(doorX0, 3.5, vz0), WOOD, {
		Material = Enum.Material.Wood,
	})
	local smoked = { Material = Enum.Material.Glass, Transparency = 0.55 }
	Build.box(
		parent,
		"VIPGlass",
		Vector3.new(vx0 - 0.4, 3.5, vz0),
		Vector3.new(vx0 - 0.2, 10, vz1),
		Color3.fromRGB(40, 34, 30),
		smoked
	)
	Build.box(
		parent,
		"VIPGlass",
		Vector3.new(vx0 - 0.4, 3.5, vz0 - 0.4),
		Vector3.new(doorX0, 10, vz0 - 0.2),
		Color3.fromRGB(40, 34, 30),
		smoked
	)
	Build.box(
		parent,
		"VIPRail",
		Vector3.new(vx0 - 0.7, 3.5, vz0 + 0.1),
		Vector3.new(vx0 + 0.1, 3.75, vz1),
		GOLD,
		gold
	)
	Build.box(
		parent,
		"VIPRail",
		Vector3.new(vx0 - 0.7, 3.5, vz0 - 0.7),
		Vector3.new(doorX0, 3.75, vz0 + 0.1),
		GOLD,
		gold
	)
	Build.box(
		parent,
		"VIPCap",
		Vector3.new(vx0 - 0.5, 10, vz0 + 0.1),
		Vector3.new(vx0 - 0.1, 10.25, vz1),
		GOLD,
		gold
	)
	Build.box(
		parent,
		"VIPCap",
		Vector3.new(vx0 - 0.5, 10, vz0 - 0.5),
		Vector3.new(doorX0, 10.25, vz0 + 0.1),
		GOLD,
		gold
	)
	for z = vz0 + 6, vz1 - 4, 8 do
		Build.part(parent, "VIPPost", Vector3.new(0.5, 10.4, 0.5), CFrame.new(vx0 - 0.3, 5.2, z), GOLD, gold)
	end
	for x = vx0 + 6, doorX0 - 4, 8 do
		Build.part(parent, "VIPPost", Vector3.new(0.5, 10.4, 0.5), CFrame.new(x, 5.2, vz0 - 0.3), GOLD, gold)
	end
	Build.part(
		parent,
		"VIPPost",
		Vector3.new(0.7, 10.6, 0.7),
		CFrame.new(vx0 - 0.3, 5.3, vz0 - 0.3),
		GOLD,
		gold
	)
	Build.part(
		parent,
		"VIPPost",
		Vector3.new(0.7, 10.6, 0.7),
		CFrame.new(doorX0 + 0.15, 5.3, vz0 - 0.3),
		GOLD,
		gold
	)
	-- the entrance: two gold stanchions with a velvet rope (VIPs see it unhooked)
	for _, sx in { cx - 3.5, cx + 3.5 } do
		Build.part(
			parent,
			"VIPStanchion",
			Vector3.new(0.35, 3.2, 0.35),
			CFrame.new(sx, 1.6, vz0 - 1.4),
			GOLD,
			gold
		)
		Build.part(
			parent,
			"VIPStanchionTop",
			Vector3.new(0.6, 0.6, 0.6),
			CFrame.new(sx, 3.4, vz0 - 1.4),
			GOLD,
			{
				Material = Enum.Material.Metal,
				Reflectance = 0.15,
				Shape = Enum.PartType.Ball,
			}
		)
		Build.part(
			parent,
			"VIPStanchionBase",
			Vector3.new(0.2, 1.2, 1.2),
			CFrame.new(sx, 0.1, vz0 - 1.4) * CFrame.Angles(0, 0, math.pi / 2),
			GOLD,
			{
				Material = Enum.Material.Metal,
				Shape = Enum.PartType.Cylinder,
			}
		)
	end
	local rope = Build.part(
		parent,
		"VIPRope",
		Vector3.new(7, 0.3, 0.3),
		CFrame.new(cx, 2.9, vz0 - 1.4),
		Color3.fromRGB(150, 20, 36),
		{
			Material = Enum.Material.Fabric,
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
		}
	)
	CollectionService:AddTag(rope, "VIPRope")
	local vipDoor = Build.box(
		parent,
		"VIPDoor",
		Vector3.new(doorX0, 0, vz0 - 2),
		Vector3.new(doorX1, 10, vz0 - 0.8),
		Color3.new(),
		{
			Transparency = 1,
		}
	)
	CollectionService:AddTag(vipDoor, "VIPDoor")
	-- the sign over the entrance: gold letters on black
	local vipSign = Build.part(
		parent,
		"VIPSign",
		Vector3.new(11, 2.4, 0.3),
		CFrame.new(cx, 11.8, vz0 - 0.4),
		Color3.fromRGB(18, 16, 16),
		{
			Material = Enum.Material.SmoothPlastic,
		}
	)
	Build.sign(
		vipSign,
		Enum.NormalId.Front,
		"★ VIP LOUNGE ★",
		Color3.fromRGB(255, 214, 110),
		Color3.fromRGB(70, 46, 10)
	)
	Build.box(
		parent,
		"VIPSignTrim",
		Vector3.new(cx - 5.6, 10.5, vz0 - 0.6),
		Vector3.new(cx + 5.6, 10.6, vz0 - 0.2),
		GOLD,
		gold
	)
	Build.box(
		parent,
		"VIPSignTrim",
		Vector3.new(cx - 5.6, 13, vz0 - 0.6),
		Vector3.new(cx + 5.6, 13.1, vz0 - 0.2),
		GOLD,
		gold
	)
	-- leather couches along the back wall
	for i = 0, 1 do
		local ccx = vx0 + 7 + i * 12
		local leather = Color3.fromRGB(70, 38, 28)
		Build.part(parent, "Couch", Vector3.new(9, 1.4, 3.4), CFrame.new(ccx, 0.86, z1 - 3), leather, {
			Material = Enum.Material.Leather,
		})
		Build.part(parent, "CouchBack", Vector3.new(9.2, 3, 1), CFrame.new(ccx, 2.06, z1 - 1.3), leather, {
			Material = Enum.Material.Leather,
		})
		for _, side in { -1, 1 } do
			Build.part(
				parent,
				"CouchArm",
				Vector3.new(0.9, 2.2, 3.4),
				CFrame.new(ccx + side * 4.95, 1.26, z1 - 3),
				leather,
				{
					Material = Enum.Material.Leather,
				}
			)
		end
		Build.part(
			parent,
			"Cushion",
			Vector3.new(1.6, 1.4, 0.5),
			CFrame.new(ccx + 2.6, 2.1, z1 - 2.2) * CFrame.Angles(-0.25, 0.2, 0),
			Color3.fromRGB(212, 172, 64),
			{
				Material = Enum.Material.Fabric,
			}
		)
	end
	-- coffee table: marble top on gold legs
	local tz = z1 - 9
	Build.part(
		parent,
		"VIPTableTop",
		Vector3.new(6, 0.3, 3),
		CFrame.new(vx0 + 13, 1.75, tz),
		Color3.fromRGB(236, 234, 228),
		{
			Material = Enum.Material.Marble,
		}
	)
	for _, lx in { -2.6, 2.6 } do
		for _, lz in { -1.1, 1.1 } do
			Build.part(
				parent,
				"VIPTableLeg",
				Vector3.new(0.25, 1.44, 0.25),
				CFrame.new(vx0 + 13 + lx, 0.88, tz + lz),
				GOLD,
				gold
			)
		end
	end
	Build.part(
		parent,
		"Champagne",
		Vector3.new(1.2, 0.5, 0.5),
		CFrame.new(vx0 + 12, 2.5, tz) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(30, 70, 40),
		{
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Glass,
		}
	)
	Build.part(
		parent,
		"Bucket",
		Vector3.new(0.9, 1, 1),
		CFrame.new(vx0 + 14.5, 2.4, tz) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(190, 192, 196),
		{
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Metal,
		}
	)
	-- minibar along the west wall with bottles
	Build.part(parent, "Minibar", Vector3.new(2.6, 3.4, 8), CFrame.new(vx0 + 1.6, 1.86, vz0 + 9), WOOD, {
		Material = Enum.Material.Wood,
	})
	Build.part(
		parent,
		"MinibarTop",
		Vector3.new(2.8, 0.2, 8.2),
		CFrame.new(vx0 + 1.6, 3.66, vz0 + 9),
		GOLD,
		gold
	)
	for k, c in
		{
			Color3.fromRGB(120, 60, 20),
			Color3.fromRGB(30, 90, 50),
			Color3.fromRGB(150, 30, 40),
			Color3.fromRGB(200, 200, 210),
			Color3.fromRGB(90, 40, 120),
		}
	do
		Build.part(
			parent,
			"Bottle",
			Vector3.new(1.1, 0.4, 0.4),
			CFrame.new(vx0 + 1.6, 4.32, vz0 + 6 + k * 1.1) * CFrame.Angles(0, 0, math.pi / 2),
			c,
			{
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Glass,
				Transparency = 0.15,
			}
		)
	end
	-- potted plants in the corners
	for _, pos in { Vector3.new(vx0 + 1.6, 0, vz0 + 2.2), Vector3.new(vx1 - 1.6, 0, z1 - 8) } do
		Build.part(
			parent,
			"Pot",
			Vector3.new(1.8, 1.6, 1.6),
			CFrame.new(pos + Vector3.new(0, 1.06, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(26, 24, 24),
			{
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Marble,
			}
		)
		Props.bush(parent, pos + Vector3.new(0, 3.1, 0), 2.6)
	end
	-- a painting on the back wall
	local painting = Build.part(
		parent,
		"Painting",
		Vector3.new(6, 4, 0.2),
		CFrame.new(vx0 + 13, 7.4, z1 - 0.3),
		GOLD,
		gold
	)
	local art = Build.sign(
		painting,
		Enum.NormalId.Front,
		"THE GREAT ESCAPE",
		Color3.fromRGB(255, 236, 200),
		Color3.fromRGB(40, 20, 10)
	)
	local canvas = art.Parent :: SurfaceGui
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.ZIndex = 0
	bg.BorderSizePixel = 0
	bg.BackgroundColor3 = Color3.new(1, 1, 1)
	bg.Parent = canvas
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(40, 60, 110), Color3.fromRGB(150, 70, 60))
	grad.Parent = bg
	local frameStroke = Instance.new("UIStroke")
	frameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	frameStroke.Color = GOLD
	frameStroke.Thickness = 8
	frameStroke.Parent = bg
	art.ZIndex = 2
	-- chandelier + warm light
	local chx, chz = vx0 + 13, (vz0 + vz1) / 2
	Build.part(
		parent,
		"ChandelierChain",
		Vector3.new(0.15, h - 13, 0.15),
		CFrame.new(chx, (h + 13) / 2, chz),
		GOLD,
		gold
	)
	Build.part(
		parent,
		"Chandelier",
		Vector3.new(0.3, 4, 4),
		CFrame.new(chx, 12.8, chz) * CFrame.Angles(0, 0, math.pi / 2),
		GOLD,
		{
			Material = Enum.Material.Metal,
			Reflectance = 0.15,
			Shape = Enum.PartType.Cylinder,
		}
	)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		Build.part(
			parent,
			"Bulb",
			Vector3.new(0.5, 0.5, 0.5),
			CFrame.new(chx + math.cos(a) * 1.8, 13.3, chz + math.sin(a) * 1.8),
			Color3.fromRGB(255, 232, 190),
			{
				Shape = Enum.PartType.Ball,
			}
		)
	end
	local glow = Build.part(
		parent,
		"ChandelierLight",
		Vector3.new(0.4, 0.4, 0.4),
		CFrame.new(chx, 12.2, chz),
		Color3.new(),
		{
			Transparency = 1,
			CanCollide = false,
		}
	)
	Build.light(glow, Color3.fromRGB(255, 196, 130), 30, 1.6)
	shops.Fence = station(parent, "Fence", "THE FENCE", CFrame.new(cr.x - 30, 0, z1 - 10), "Fence")
	return shops
end

-- ===== Yard =====

-- ===== Mess Hall (south of the Common Room; buffs for the night arrive with M4) =====

local function buildMessHall(parent: Instance, shops: { [string]: BasePart })
	local cr = World.CommonRoom
	-- (the +X side stays 4 studs clear of the cell row's bedrock wall: no z-fighting)
	local x0, x1 = cr.x - cr.sx / 2, cr.x + cr.sx / 2 - 4
	local z0 = cr.z + cr.sz / 2 + 4
	local z1 = z0 + 56
	local h = 22
	Build.box(
		parent,
		"MessFloor",
		Vector3.new(x0, -4, z0),
		Vector3.new(x1, 0, z1),
		Color3.fromRGB(190, 190, 180),
		{
			Material = Enum.Material.Marble,
		}
	)
	Build.box(parent, "MessCeiling", Vector3.new(x0, h, z0), Vector3.new(x1, h + 2, z1), C.ceiling)
	Build.box(parent, "Wall", Vector3.new(x0 - 4, 0, z0), Vector3.new(x0, h, z1 + 4), C.wall)
	Build.box(parent, "Wall", Vector3.new(x1, 0, z0), Vector3.new(x1 + 4, h, z1 + 4), C.wall)
	Build.box(parent, "Wall", Vector3.new(x0, 0, z1), Vector3.new(x1, h, z1 + 4), C.wall)
	Build.box(
		parent,
		"Paint",
		Vector3.new(x0, 0, z1 - 0.1),
		Vector3.new(x1, 6, z1),
		C.wallLow,
		{ CanCollide = false }
	)
	-- serving counter along the back wall with a cook
	local counterCf = CFrame.new(cr.x, 0, z1 - 8)
	Build.part(
		parent,
		"Serving",
		Vector3.new(40, 3.4, 3),
		counterCf * CFrame.new(0, 1.7, 0),
		Color3.fromRGB(170, 175, 180),
		{
			Material = Enum.Material.Metal,
		}
	)
	for i = -2, 2 do
		Build.part(
			parent,
			"Pot",
			Vector3.new(2.4, 1.6, 2.4),
			counterCf * CFrame.new(i * 7, 4.2, 0),
			Color3.fromRGB(90, 90, 95),
			{
				Material = Enum.Material.Metal,
				Shape = Enum.PartType.Cylinder,
				Orientation = Vector3.new(0, 0, 90),
			}
		)
	end
	local serving = parent:FindFirstChild("Serving") :: BasePart
	local mealPrompt = Build.prompt(serving, "Eat", "Mess Hall", Economy.ShopRange)
	mealPrompt.Name = "ShopPrompt"
	serving:SetAttribute("Shop", "MessHall")
	CollectionService:AddTag(serving, "Shop")
	shops.MessHall = serving
	-- LAUNDRY counter along the west wall
	shops.Laundry = station(
		parent,
		"Laundry",
		"LAUNDRY",
		CFrame.new(x0 + 8, 0, z0 + 30) * CFrame.Angles(0, -math.pi / 2, 0),
		"Laundry"
	)
	for i = 0, 2 do
		Build.part(
			parent,
			"Washer",
			Vector3.new(3, 3.4, 3),
			CFrame.new(x0 + 2, 1.7, z0 + 40 + i * 3.4),
			Color3.fromRGB(235, 235, 240),
			{
				Material = Enum.Material.Metal,
			}
		)
	end
	Build.npc(
		parent,
		"Cook",
		counterCf * CFrame.new(0, 0, 3.5),
		Color3.fromRGB(245, 245, 245),
		Color3.fromRGB(250, 250, 250)
	)
	local board = Build.part(
		parent,
		"Menu",
		Vector3.new(24, 6, 0.5),
		counterCf * CFrame.new(0, 11, 5.5),
		Color3.fromRGB(35, 38, 46)
	)
	Build.sign(board, Enum.NormalId.Front, "MEALS FOR THE NIGHT 🍲", Color3.fromRGB(255, 235, 120))
	-- long tables with benches
	for row = 0, 2 do
		for col = 0, 1 do
			local tx = cr.x - 24 + col * 48
			local tz = z0 + 10 + row * 12
			Props.messTable(parent, Vector3.new(tx, 0, tz), 30)
		end
	end
	for i = 0, 2 do
		local lamp = Build.part(
			parent,
			"Lamp",
			Vector3.new(6, 0.5, 6),
			CFrame.new(cr.x - 36 + i * 36, h - 0.25, z0 + 26),
			C.lamp,
			{ Material = Enum.Material.Neon }
		)
		Build.light(lamp, Color3.fromRGB(215, 228, 235), 45, 1)
	end
end

local function buildYard(parent: Instance, shops: { [string]: BasePart }): (BasePart, { BasePart })
	local y = World.Yard
	local x0, x1 = y.x - y.sx / 2, y.x + y.sx / 2
	local z0, z1 = y.z - y.sz / 2, y.z + y.sz / 2
	Build.box(parent, "YardGround", Vector3.new(x0, -4, z0), Vector3.new(x1, 0, z1), C.grass, {
		Material = Enum.Material.Pavement,
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
			Color3.fromRGB(70, 72, 66),
			{
				Material = Enum.Material.Pavement,
			}
		)
	end
	-- fences: posts + see-through mesh panels
	local fence = Color3.fromRGB(150, 155, 160)
	local posts: { Vector3 } = {}
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
			local taken = false
			for _, q in posts do
				if (q - p).Magnitude < 1.5 then
					taken = true
				end
			end
			if taken then
				continue
			end
			table.insert(posts, p)
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
	fenceLine(Vector3.new(x0, 0, z0), Vector3.new(x1 - 0.5, 0, z0))
	fenceLine(Vector3.new(x0, 0, z1), Vector3.new(x1 - 0.5, 0, z1))
	fenceLine(Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1))
	local crHalf = World.CommonRoom.sz / 2 + 4
	fenceLine(Vector3.new(x1, 0, z0), Vector3.new(x1, 0, -crHalf - 0.5))
	fenceLine(Vector3.new(x1, 0, crHalf + 0.5), Vector3.new(x1, 0, z1))
	-- guard tower in the far corner
	local tx, tz = x0 + 10, z0 + 10
	for _, d in { { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } } do
		Build.part(
			parent,
			"TowerLeg",
			Vector3.new(1, 22, 1),
			CFrame.new(tx + d[1], 11, tz + d[2]),
			DARK_STEEL,
			{
				Material = Enum.Material.Metal,
			}
		)
	end
	Build.part(
		parent,
		"TowerCabin",
		Vector3.new(10, 6, 10),
		CFrame.new(tx, 25, tz),
		Color3.fromRGB(104, 104, 100),
		{
			Material = Enum.Material.Concrete,
		}
	)
	Build.part(parent, "TowerRoof", Vector3.new(12, 1, 12), CFrame.new(tx, 28.5, tz), DARK_STEEL, {
		Material = Enum.Material.Metal,
	})
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

	-- BLACK MARKET: a dealer by a hole cut in the yard fence (stock rotates every day)
	shops.BlackMarket = station(
		parent,
		"BlackMarket",
		"BLACK MARKET",
		CFrame.new(x0 + 7, 0, z0 + 40) * CFrame.Angles(0, -math.pi / 2, 0),
		"FenceHole"
	)

	-- RUBBLE DUMP: a big skip next to the door from the Common Room
	local dumpCf = CFrame.new(x1 - 22, 0, -32)
	local dumpModel = Instance.new("Model")
	dumpModel.Name = "Dump"
	dumpModel.Parent = parent
	local dumpColor = Color3.fromRGB(56, 78, 60) -- a beat-up industrial dumpster
	Build.part(
		dumpModel,
		"SkipBottom",
		Vector3.new(15.4, 1, 9.4),
		dumpCf * CFrame.new(0, 0.5, 0),
		dumpColor,
		{
			Material = Enum.Material.Metal,
		}
	)
	for _, side in { { 0, -5, 16, 0.6 }, { 0, 5, 16, 0.6 }, { -8, 0, 0.6, 9.4 }, { 8, 0, 0.6, 9.4 } } do
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
	Build.sign(dumpSign, Enum.NormalId.Back, "RUBBLE", Color3.fromRGB(255, 220, 90))
	Build.sign(dumpSign, Enum.NormalId.Front, "RUBBLE", Color3.fromRGB(255, 220, 90))
	local dumpPrompt = Build.prompt(rubble, "Dump rubble", "Rubble Dump", Economy.DumpRange)
	dumpPrompt.Name = "DumpPrompt"
	CollectionService:AddTag(rubble, "Dump")

	-- PRISON GYM: one ridiculous thing to lift per Economy.Gym entry, in a row along the fence
	local stations: { BasePart } = {}
	local spacing = (x1 - x0 - 50) / math.max(1, #Economy.Gym - 1)
	for i, st in Economy.Gym do
		local cf = CFrame.new(x1 - 30 - (i - 1) * spacing, 0, z1 - 22)
		local m = Instance.new("Model")
		m.Name = "Gym" .. i
		m.Parent = parent
		local mat = Build.part(
			m,
			"Mat",
			Vector3.new(12, 0.3, 12),
			cf * CFrame.new(0, 0.15, 0),
			Color3.fromRGB(38, 38, 44),
			{
				Material = Enum.Material.Rubber,
			}
		)
		local prop = GymProps.build(st.id)
		prop:PivotTo(cf * CFrame.new(0, 0.3, 1.5))
		prop.Parent = m
		local board = Build.part(
			m,
			"Board",
			Vector3.new(10, 3.6, 0.4),
			cf * CFrame.new(0, 9.5, 6.2),
			Color3.fromRGB(44, 47, 52),
			{
				Material = Enum.Material.Metal,
			}
		)
		for _, dx in { -4.6, 4.6 } do
			Build.part(
				m,
				"Post",
				Vector3.new(0.4, 9.5, 0.3),
				cf * CFrame.new(dx, 4.75, 6.2),
				Color3.fromRGB(58, 62, 68)
			)
		end
		local need = if st.minStrength > 0
			then string.format("needs %s 💪", Format.number(st.minStrength))
			else "anyone"
		Build.sign(
			board,
			Enum.NormalId.Front,
			string.format(
				"%s %s\n+%s 💪 · %s",
				st.emoji,
				string.upper(st.name),
				Format.number(st.gain),
				need
			),
			Color3.fromRGB(235, 205, 90)
		)
		local prompt = Build.prompt(mat, "Lift", st.name, Economy.GymRange)
		prompt.Name = "LiftPrompt"
		mat:SetAttribute("Station", i)
		CollectionService:AddTag(mat, "GymStation")
		table.insert(stations, mat)
	end
	local gymSign = Build.part(
		parent,
		"GymSign",
		Vector3.new(26, 4, 0.5),
		CFrame.new((x0 + x1) / 2, 14, z1 - 2),
		C.orange,
		{
			Material = Enum.Material.Metal,
		}
	)
	Build.sign(gymSign, Enum.NormalId.Front, "YARD GYM", Color3.fromRGB(235, 205, 90))
	return rubble, stations
end

local function setupLighting()
	local day = Cycle.Look.Day
	Lighting.ClockTime = Cycle.DayClock
	Lighting.Brightness = day.brightness
	Lighting.Ambient = Build.rgb(day.ambient)
	Lighting.OutdoorAmbient = Build.rgb(day.outdoor)
	Lighting.EnvironmentDiffuseScale = 0.25
	Lighting.EnvironmentSpecularScale = 0.1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.6
	-- cold, desaturated prison grading
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ZoneTint"
	cc.Saturation = -0.35
	cc.Contrast = 0.14
	cc.Brightness = -0.02
	cc.TintColor = Color3.fromRGB(232, 238, 245)
	cc.Parent = Lighting
	-- grey haze and an overcast sky
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.38
	atm.Offset = 0.1
	atm.Haze = 2.2
	atm.Glare = 0
	atm.Color = Color3.fromRGB(150, 155, 162)
	atm.Decay = Color3.fromRGB(90, 95, 105)
	atm.Parent = Lighting
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.85
	clouds.Density = 0.65
	clouds.Color = Color3.fromRGB(150, 152, 158)
	clouds.Parent = workspace.Terrain
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 20
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
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
	local boards: { [string]: Frame } = {}
	local shops = buildCommonRoom(common, boards)
	buildMessHall(common, shops)
	local yard = Instance.new("Folder")
	yard.Name = "Yard"
	yard.Parent = root
	local dump, stations = buildYard(yard, shops)
	Facade.build(root)
	Dressing.dress(root, cells)
	setupLighting()
	return { cells = cells, boards = boards, shops = shops, dump = dump, stations = stations }
end

return WorldBuilder
