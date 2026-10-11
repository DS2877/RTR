--!strict
-- Headless smoke test. CI runs this inside the real place on Roblox's servers via the Open Cloud
-- Luau Execution API (tools/ci/smoke.py), against a *saved* (not published) version of the build.
-- Place scripts don't auto-run there and physics doesn't step, so this boots every server service
-- the same way init.server.luau does and then checks the built world: counts, which way every sign
-- faces, item/crown models, prompts, treadmill, guards' humanoid setup and spawn positions.
-- Returns { passed, failed, failures } (CI fails the build when failed > 0).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Services = Server:WaitForChild("Services")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local passed = 0
local failures: { string } = {}

local function check(name: string, ok: boolean, detail: any?)
	if ok then
		passed += 1
	else
		local line = name .. (if detail ~= nil then ": " .. tostring(detail) else "")
		table.insert(failures, line)
		warn("FAIL " .. line)
	end
end

local function step(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	check(name, ok, err)
	return ok
end

local function req(parent: Instance, name: string): any
	return (require :: any)(parent:WaitForChild(name))
end

local Remotes = req(Shared, "Remotes")
local Progression = req(Shared, "Progression")
local Vaults = req(Shared:WaitForChild("Config"), "Vaults")
local Mutations = req(Shared:WaitForChild("Config"), "Mutations")
local Economy = req(Shared:WaitForChild("Config"), "Economy")
local World = req(Shared:WaitForChild("Config"), "World")
local ItemModel = req(Server:WaitForChild("Util"), "ItemModel")

local WorldBuilder = req(Services, "WorldBuilder")
local Bases = req(Services, "Bases")
local Carry = req(Services, "Carry")
local VaultLoot = req(Services, "Vaults")
local Guards = req(Services, "Guards")
local Treadmill = req(Services, "Treadmill")
local Richest = req(Services, "Richest")
local Fuse = req(Services, "Fuse")
local Product = req(Services, "Product")
local Admin = req(Services, "Admin")

-- ===== boot (same order as init.server.luau) =====
local world: any = nil
step("Remotes.setup", Remotes.setup)
local built = step("WorldBuilder.build", function()
	world = WorldBuilder.build()
end)
if not built then
	return { passed = passed, failed = #failures, failures = failures }
end
step("Bases.start", function()
	Bases.start(world)
end)
step("Carry.startService", Carry.startService)
step("Vaults.start", function()
	VaultLoot.start(world)
end)
step("Guards.start", function()
	Guards.start(world)
end)
step("Treadmill.start", function()
	Treadmill.start(world)
end)
step("Richest.start", function()
	Richest.start(world)
end)
step("Fuse.start", function()
	Fuse.start(world)
end)
step("Product.start", Product.start)
step("Admin.start", Admin.start)

-- ===== helpers =====
local function faceNormal(part: BasePart, face: Enum.NormalId): Vector3
	return part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face))
end

-- World-space normals of every SurfaceGui with text on `part`.
local function textNormals(part: BasePart): { Vector3 }
	local out = {}
	for _, d in part:GetChildren() do
		if d:IsA("SurfaceGui") then
			table.insert(out, faceNormal(part, d.Face))
		end
	end
	return out
end

local function anyFaces(part: BasePart, dir: Vector3): boolean
	for _, n in textNormals(part) do
		if n:Dot(dir.Unit) > 0.9 then
			return true
		end
	end
	return false
end

-- Axis-aligned box of a part in base-local space (bases are only ever rotated about Y by 0/180°).
local function localBox(origin: CFrame, p: BasePart): (Vector3, Vector3)
	local c = origin:PointToObjectSpace(p.Position)
	local half = p.Size / 2
	return c - half, c + half
end

local function overlaps(origin: CFrame, a: BasePart, b: BasePart): boolean
	local amin, amax = localBox(origin, a)
	local bmin, bmax = localBox(origin, b)
	return amin.X < bmax.X and amax.X > bmin.X and amin.Z < bmax.Z and amax.Z > bmin.Z
end

-- ===== world counts =====
check("8 bases", #world.bases == World.BaseCount, #world.bases)
check("8 vaults", #world.vaults == #Vaults, #world.vaults)

-- ===== bases =====
for _, base in world.bases do
	local id = "base " .. base.id
	local origin: CFrame = base.origin
	local toPlaza = -origin.LookVector
	local model: Model = base.model
	check(id .. " has 30 pedestals", #base.pedestals == 30, #base.pedestals)
	local sign = model:FindFirstChild("Sign") :: BasePart
	check(id .. " entrance sign faces the plaza", anyFaces(sign, toPlaza))
	check(id .. " sign faces the plaza side (z)", (toPlaza.Z > 0) == (origin.Position.Z < 0))
	local spawnPos = base.spawnCFrame.Position
	check(id .. " spawn is inside the base", Bases.contains(base, spawnPos))
	check(id .. " spawn looks at the entrance", base.spawnCFrame.LookVector:Dot(toPlaza) > 0.9)
	-- the plot sign stands just inside the front wall: it must be readable from inside the base
	local plot: BasePart = base.plotSign
	check(id .. " plot sign readable from inside", anyFaces(plot, origin.LookVector))
	local tread: BasePart = base.treadSign
	check(id .. " treadmill sign readable from entrance", anyFaces(tread, toPlaza))
	local screen = model:FindFirstChild("TreadScreen") :: BasePart
	check(id .. " treadmill screen faces the runner", anyFaces(screen, toPlaza))
	check(
		id .. " has Upgrade prompts",
		plot:FindFirstChild("Upgrade") ~= nil and tread:FindFirstChild("Upgrade") ~= nil
	)
	-- treadmill: pushes toward the entrance, and a runner on it counts
	local belt: BasePart = base.belt
	local v = belt.AssemblyLinearVelocity
	check(id .. " belt speed", math.abs(v.Magnitude - Economy.Treadmill.BeltSpeed) < 0.01, v)
	check(id .. " belt pushes toward the entrance", v.Magnitude > 0 and v.Unit:Dot(toPlaza) > 0.99, v)
	check(id .. " runner on belt counts", Treadmill.onBelt(base, belt.Position + Vector3.new(0, 3.3, 0)))
	check(
		id .. " beside belt doesn't count",
		not Treadmill.onBelt(base, belt.Position + origin.RightVector * 9)
	)
	-- laser off, beam hidden
	check(id .. " laser starts open", base.laser.CanCollide == false and base.laser.Transparency == 1)
	check(id .. " crown beam hidden", base.beam.Transparency == 1)
	-- everything inside, nothing on top of a pedestal
	for _, part in { base.collectPad, plot, tread, belt } do
		check(id .. " " .. part.Name .. " inside base", Bases.contains(base, part.Position))
		for i, ped in base.pedestals do
			if overlaps(origin, ped, part) then
				check(id .. " pedestal " .. i .. " clear of " .. part.Name, false)
			end
		end
	end
	for i, ped in base.pedestals do
		if not Bases.contains(base, ped.Position) then
			check(id .. " pedestal " .. i .. " inside base", false)
		end
	end
end
check(
	"base 1 and 5 face opposite ways",
	world.bases[1].origin.LookVector:Dot(world.bases[5].origin.LookVector) < -0.9
)

-- ===== vaults =====
local guardsWanted = 0
for _, vault in world.vaults do
	local def = Vaults[vault.index]
	guardsWanted += def.guards
	local id = "vault " .. def.id
	local sign = vault.model:FindFirstChild("Sign") :: BasePart
	local toStreet = Vector3.new(0, 0, -math.sign(vault.center.Z))
	check(id .. " sign faces the street", anyFaces(sign, toStreet))
	check(id .. " 6 pedestals", #vault.pedestals == 6, #vault.pedestals)
	local loot = 0
	for _, m in vault.model:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("ItemId") then
			loot += 1
			local core = m.PrimaryPart
			local prompt = core and core:FindFirstChild("Steal")
			check(id .. " loot has a STEAL prompt", prompt ~= nil and prompt:IsA("ProximityPrompt"))
		end
	end
	check(id .. " 6 loot items spawned", loot == 6, loot)
end

-- ===== plaza boards =====
local root = workspace:FindFirstChild("World") :: Folder
local gate = root:FindFirstChild("GateSign") :: BasePart
local towardStreet = Vector3.new(1, 0, 0)
for _, sg in gate:GetChildren() do
	if sg:IsA("SurfaceGui") then
		local label = sg:FindFirstChildOfClass("TextLabel") :: TextLabel
		local n = faceNormal(gate, sg.Face)
		if string.find(label.Text, "RICH STREET") then
			check("RICH STREET text faces home", n:Dot(towardStreet) < -0.9)
		elseif string.find(label.Text, "HOME") then
			check("HOME text faces the street", n:Dot(towardStreet) > 0.9)
		end
	end
end
local reign = root:FindFirstChild("ReignBoard") :: BasePart
check("reign board faces the plaza", anyFaces(reign, towardStreet))
local fuseSign = root:FindFirstChild("FuseSign") :: BasePart
check("fuse sign faces the plaza", anyFaces(fuseSign, towardStreet))
check("wanted title set", world.wanted.Title[1].Text ~= "", world.wanted.Title[1].Text)

-- ===== guards =====
local guardFolder = workspace:FindFirstChild("Guards")
local guardCount = 0
if guardFolder then
	for _, g in guardFolder:GetChildren() do
		guardCount += 1
		local h = g:FindFirstChildOfClass("Humanoid")
		local r = g:FindFirstChild("HumanoidRootPart") :: BasePart?
		check("guard humanoid is R15 (rigless)", h ~= nil and h.RigType == Enum.HumanoidRigType.R15)
		check("guard root unanchored", r ~= nil and not r.Anchored)
		if h and r then
			local legL = g:FindFirstChild("LegL") :: BasePart
			local feet = legL.Position.Y - legL.Size.Y / 2
			local rootBottom = r.Position.Y - r.Size.Y / 2
			check(
				"guard legs reach HipHeight",
				math.abs((rootBottom - feet) - h.HipHeight) < 0.3,
				rootBottom - feet
			)
		end
	end
end
check("guard count", guardCount == guardsWanted, guardCount)

-- ===== item models =====
local head = Instance.new("Part")
head.Name = "Head"
head.Size = Vector3.new(1.2, 1.2, 1.2)
head.Anchored = true
head.CFrame = CFrame.new(0, 500, 0)
head.Parent = workspace
for id, info in Progression.allItems() do
	for _, mut in Mutations.Order do
		local ok, err = pcall(function()
			local m = ItemModel.build(id, mut)
			assert(m.PrimaryPart, "no PrimaryPart")
			local _, size = m:GetBoundingBox()
			assert(size.Magnitude < 9, "too big " .. tostring(size))
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					assert(not d.CanCollide and d.Massless, d.Name .. " collides or has mass")
				end
			end
			if info.shape == "tall" then
				assert(size.Y > 3, "tall item is short " .. tostring(size))
			end
			m:Destroy()
		end)
		check("item " .. id .. " " .. mut, ok, err)
	end
end
step("carried loot welds above a head", function()
	local m = ItemModel.build("GoldBar", "Gold", { label = false })
	ItemModel.weldTo(m, head, CFrame.new(0, 3.2, 0))
	m.Parent = workspace
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			assert(not d.Anchored, "anchored part in carried loot")
		end
	end
	assert((m.PrimaryPart :: BasePart).Position.Y > head.Position.Y + 2, "loot not above the head")
	m:Destroy()
end)
step("crown sits on the head with gems on top", function()
	local crown = Richest.attachCrown(head, workspace)
	local band = crown.PrimaryPart :: BasePart
	assert(band.Position.Y > head.Position.Y + 0.6, "band not above the head")
	assert(band.CFrame.RightVector:Dot(Vector3.yAxis) > 0.99, "band is not upright")
	for _, d in crown:GetChildren() do
		if d.Name == "Gem" and d:IsA("BasePart") then
			assert(d.Position.Y > band.Position.Y + 0.6, "gem below the spike tips")
		end
	end
	crown:Destroy()
end)
head:Destroy()

-- ===== balance sanity =====
check("starter item exists", Progression.item(Economy.StarterItem) ~= nil)
check("vault 1 guards are outrunnable at start", Progression.speedToOutrun(1) < Economy.Speed.Base)

print(string.format("SMOKE: %d passed, %d failed", passed, #failures))
return { passed = passed, failed = #failures, failures = failures }
