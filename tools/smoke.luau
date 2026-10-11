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
local Events = req(Services, "Events")
local State = req(Server, "State")
local Net = req(Server, "Net")
local Data = req(Services, "Data")
local Wallet = req(Services, "Wallet")
local Assets = req(Shared:WaitForChild("Config"), "Assets")
local Cosmetics = req(Shared:WaitForChild("Config"), "Cosmetics")
local Cosmetic = req(Services, "Cosmetic")
local Pickups = req(Services, "Pickups")
local Social = req(Services, "Social")

-- ===== boot (same order as init.server.luau) =====
local world: any = nil
step("Remotes.setup", Remotes.setup)
step("Events.startService", Events.startService)
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
step("Cosmetic.start", function()
	Cosmetic.start(world)
end)
step("Pickups.start", function()
	Pickups.start(world)
end)
step("Social.start", Social.start)

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
	if p:IsA("Part") and p.Shape == Enum.PartType.Cylinder then
		-- upright podium: the cylinder's length (X) is its height
		half = Vector3.new(p.Size.Y / 2, p.Size.X / 2, p.Size.Z / 2)
	end
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
	check(id .. " belt doesn't push (AFK treadmill)", belt.AssemblyLinearVelocity.Magnitude < 0.01)
	check(id .. " runner on belt counts", Treadmill.onBelt(base, belt.Position + Vector3.new(0, 3.3, 0)))
	check(id .. " 30 pedestal rings", #base.rings == 30, #base.rings)
	check(
		id .. " beside belt doesn't count",
		not Treadmill.onBelt(base, belt.Position + origin.RightVector * 9)
	)
	-- laser off, beam hidden
	check(id .. " laser starts open", base.laser.CanCollide == false and base.laser.Transparency == 1)
	local barriers = 0
	for _, part in model:GetChildren() do
		if part.Name == "Barrier" and part:IsA("BasePart") and part.CanCollide and part.Size.Y >= 40 then
			barriers += 1
		end
	end
	check(id .. " invisible barriers over the low walls", barriers == 5, barriers)
	-- the Upgrade prompt (7 studs) must not reach a player standing on the treadmill
	local nearest = belt.CFrame:PointToWorldSpace(
		Vector3.new(
			math.clamp(belt.CFrame:PointToObjectSpace(tread.Position).X, -belt.Size.X / 2, belt.Size.X / 2),
			3,
			math.clamp(belt.CFrame:PointToObjectSpace(tread.Position).Z, -belt.Size.Z / 2, belt.Size.Z / 2)
		)
	)
	check(id .. " treadmill prompt out of reach from the belt", (nearest - tread.Position).Magnitude > 7.5)
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
	check(id .. " arch sign faces the way in (toward home)", anyFaces(sign, Vector3.new(-1, 0, 0)))
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

-- ===== Rich Street: zones one after another, a clear running path through all of them =====
for i, vault in world.vaults do
	local id = "zone " .. Vaults[vault.index].id
	if i > 1 then
		local prev = world.vaults[i - 1]
		check(
			id .. " follows the previous zone",
			math.abs((vault.origin.Position.X - prev.origin.Position.X) - World.VaultSpacing) < 0.01
		)
	end
	check(id .. " has its rich person", vault.model:FindFirstChild("RichPerson") ~= nil)
	local blocked = nil
	for _, d in vault.model:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide and d.Name ~= "Floor" and d.Name ~= "Path" then
			local l = vault.origin:PointToObjectSpace(d.Position)
			-- the part's real half-extent across the corridor and downward (rotation aware)
			local function halfAlong(axis: Vector3): number
				local c = d.CFrame
				return math.abs(c.RightVector:Dot(axis)) * d.Size.X / 2
					+ math.abs(c.UpVector:Dot(axis)) * d.Size.Y / 2
					+ math.abs(c.LookVector:Dot(axis)) * d.Size.Z / 2
			end
			local across = halfAlong(vault.origin.RightVector)
			local bottom = d.Position.Y - halfAlong(Vector3.yAxis)
			if math.abs(l.X) - across < World.PathHalfWidth and bottom < 7 then
				blocked = d:GetFullName()
			end
		end
	end
	check(id .. " running path is clear", blocked == nil, blocked)
	local sides = { [1] = 0, [-1] = 0 }
	for _, ped in vault.pedestals do
		local side = math.sign(vault.origin:PointToObjectSpace(ped.Position).X)
		sides[side] = (sides[side] or 0) + 1
	end
	check(id .. " stands on both sides of the path", sides[1] == 3 and sides[-1] == 3)
end
check("trails shop with a prompt", world.trailsPrompt ~= nil and world.trailsPrompt:IsA("ProximityPrompt"))
for _, base in world.bases do
	check("base " .. base.id .. " SAFE ZONE on the floor", base.model:FindFirstChild("SafeZone") ~= nil)
end
check("street pickups placed", #Pickups.all() >= 30, #Pickups.all())
local season = Cosmetic.seasonActive()
check("Halloween decor matches the season", (root:FindFirstChild("Halloween") ~= nil) == season)
check(
	"friend boost math",
	Social.boostFor(0) == 0 and Social.boostFor(2) == 0.2 and Social.boostFor(9) == 0.3
)
for _, vault in world.vaults do
	local decor = vault.model:FindFirstChild("Decor")
	check("vault " .. vault.index .. " has themed decor", decor ~= nil and #decor:GetChildren() >= 8)
end

-- ===== every sound / music / animation id is a real, licensed asset =====
local MarketplaceService = game:GetService("MarketplaceService")
local function assetOk(name: string, url: string)
	local id = tonumber(string.match(url, "%d+"))
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id :: number)
	end)
	if ok and info then
		print(
			string.format(
				"asset %s = %s by %s",
				name,
				tostring(info.Name),
				tostring(info.Creator and info.Creator.Name)
			)
		)
	end
	check("asset " .. name .. " exists", ok and info ~= nil, if ok then nil else info)
end
for name, url in Assets.Sounds do
	assetOk(name, url)
end
for i, url in Assets.Music.Playlist do
	assetOk("Music" .. i, url)
end
assetOk("Chase", Assets.Music.Chase)
for name, url in Assets.Animations do
	assetOk(name, url)
end

-- ===== gameplay simulation with two simulated players =====
-- Real Player objects can't be created headlessly, so these are stand-ins with the same fields
-- the services use. Messages to them land in `inbox` (Net.sink). Physics doesn't run, so we move
-- characters by hand; the services' own loops (income, deposit, guards, treadmill) do the rest.
local inbox: { [any]: { { name: string, args: { any } } } } = {}
local announcements: { string } = {}
Net.sink = function(p: any, name: string, args: { any })
	if p == nil then
		table.insert(announcements, tostring(args[1]))
		return
	end
	inbox[p] = inbox[p] or {}
	table.insert(inbox[p], { name = name, args = args })
end
local function got(p: any, name: string, contains: string?): boolean
	for _, m in inbox[p] or {} do
		if m.name == name and (not contains or string.find(tostring(m.args[1]), contains, 1, true)) then
			return true
		end
	end
	return false
end
local function announced(contains: string): boolean
	for _, a in announcements do
		if string.find(a, contains, 1, true) then
			return true
		end
	end
	return false
end

local fakeId = 0
local function fakePlayer(name: string): any
	fakeId += 1
	local attrs: { [string]: any } = {}
	local character = Instance.new("Model")
	character.Name = name
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Anchored = true
	hrp.CFrame = CFrame.new(0, 300 + fakeId * 10, 0)
	hrp.Parent = character
	local h = Instance.new("Part")
	h.Name = "Head"
	h.Size = Vector3.new(1.2, 1.2, 1.2)
	h.Anchored = true
	h.CFrame = hrp.CFrame * CFrame.new(0, 1.6, 0)
	h.Parent = character
	Instance.new("Humanoid").Parent = character
	character.PrimaryPart = hrp
	character.Parent = workspace
	return {
		Name = name,
		DisplayName = name,
		UserId = -1000 - fakeId,
		Character = character,
		Parent = game:GetService("Players"),
		attrs = attrs,
		SetAttribute = function(_, k: string, v: any)
			attrs[k] = v
		end,
		GetAttribute = function(_, k: string): any
			return attrs[k]
		end,
		FindFirstChild = function(): any
			return nil
		end,
	}
end
local function moveTo(p: any, pos: Vector3)
	p.Character:PivotTo(CFrame.new(pos))
end
local function stateOf(p: any): any
	return State.get(p)
end

local A: any, B: any = nil, nil
local sim = step("gameplay: two players join", function()
	A, B = fakePlayer("Alice"), fakePlayer("Bob")
	State.add(A, Data.fresh())
	State.add(B, Data.fresh())
	assert(Bases.assign(A) and Bases.assign(B), "no base assigned")
	local a, b = stateOf(A), stateOf(B)
	assert(a.base ~= b.base, "same base twice")
	assert(string.find(a.base.signLabel.Text, "ALICE"), "sign says " .. a.base.signLabel.Text)
end)

if sim and A and B then
	local a, b = stateOf(A), stateOf(B)
	local inBase = function(st: any): Vector3
		return (st.base.origin * CFrame.new(0, 3, -40)).Position
	end

	step("starter item lands on a pedestal with Steal + Sell prompts", function()
		local slot = Bases.addItem(A, Economy.StarterItem, "None")
		assert(slot == "1", "slot " .. tostring(slot))
		local found = false
		for _, m in a.base.model:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("Slot") == "1" then
				local core = m.PrimaryPart :: BasePart
				assert(core:FindFirstChild("Steal") and core:FindFirstChild("Sell"), "prompts missing")
				found = true
			end
		end
		assert(found, "item model not on the pedestal")
	end)

	step("income ticks into the collect pad", function()
		moveTo(A, Vector3.new(0, 400, 0))
		task.wait(2.3)
		assert(a.data.Pending >= 9, "pending " .. a.data.Pending)
		assert((A.attrs.CashPerSec or 0) >= 5, "CashPerSec " .. tostring(A.attrs.CashPerSec))
	end)

	step("standing on the collect pad collects", function()
		local before = a.data.Cash
		moveTo(A, a.base.collectPad.Position + Vector3.new(0, 3, 0))
		task.wait(1.3)
		assert(a.data.Cash > before, "cash did not grow")
		assert(a.data.Pending < 10, "pending not emptied " .. a.data.Pending)
		assert(A.attrs.Collected == 1, "Collected attr " .. tostring(A.attrs.Collected))
		assert(got(A, Remotes.Names.CashFX), "no CashFX")
	end)

	step("upgrades: not enough cash -> cash offer; with cash -> level up", function()
		a.data.Cash = 0
		Bases.upgradePlot(A)
		assert(a.data.PlotLevel == 1, "upgraded without cash")
		assert(got(A, Remotes.Names.Offer, "cash"), "no cash offer")
		Wallet.add(A, 1e6)
		Bases.upgradePlot(A)
		Bases.upgradeTreadmill(A)
		assert(
			a.data.PlotLevel == 2 and a.data.Treadmill == 2,
			"levels " .. a.data.PlotLevel .. "/" .. a.data.Treadmill
		)
		assert(
			a.base.rings[8].Transparency == 0 and a.base.rings[9].Transparency == 1,
			"rings not lit for 8 pedestals"
		)
	end)

	step("treadmill: standing still earns speed and walk speed", function()
		local before = a.data.Speed
		moveTo(A, a.base.belt.Position + Vector3.new(0, 3.3, 0))
		task.wait(1.2)
		assert(a.data.Speed > before, "no speed points")
		local hum = A.Character:FindFirstChildOfClass("Humanoid")
		assert(hum.WalkSpeed > Economy.Speed.Base, "walk speed " .. hum.WalkSpeed)
		assert(got(A, Remotes.Names.SpeedTick), "no +speed popup")
	end)

	local vault1 = world.vaults[1]
	local function stealFromVault(p: any): boolean
		local ped = vault1.pedestals[1]
		moveTo(p, ped.Position + Vector3.new(0, 3, -6))
		for _ = 1, 30 do
			if VaultLoot.lootAt(1, 1) then
				break
			end
			task.wait(0.5)
		end
		return VaultLoot.stealAt(1, 1, p)
	end

	step("steal from a vault: carry, loot on head, slower, pedestal empty", function()
		moveTo(A, Vector3.new(0, 400, 0))
		local speed = A.Character:FindFirstChildOfClass("Humanoid").WalkSpeed
		assert(stealFromVault(A), "steal failed")
		assert(a.carry ~= nil and A.attrs.Carrying ~= nil, "not carrying")
		assert(A.Character:FindFirstChild("CarriedLoot"), "no loot model on the head")
		assert(VaultLoot.lootAt(1, 1) == nil, "pedestal still full")
		assert(A.Character:FindFirstChildOfClass("Humanoid").WalkSpeed < speed, "carrying isn't slower")
	end)

	step("a guard catches the carrier: loot back on the pedestal, stun, CAUGHT", function()
		local guard = nil
		for _, g in Guards.all() do
			if g.vault == 1 then
				guard = g
			end
		end
		assert(guard, "no guard at vault 1")
		task.wait(0.3)
		assert(guard.model:GetAttribute("Chasing") == true, "guard didn't notice the thief")
		assert(got(A, Remotes.Names.Alarm), "no alarm for the thief")
		moveTo(A, guard.root.Position + Vector3.new(1, 0, 0))
		task.wait(0.4)
		assert(a.carry == nil, "still carrying after being caught")
		assert(got(A, Remotes.Names.Caught), "no CAUGHT message")
		assert(VaultLoot.lootAt(1, 1) ~= nil, "loot not back on the pedestal")
		assert(A.Character:FindFirstChildOfClass("Humanoid").WalkSpeed == 0, "not stunned")
		task.wait(1.7)
		assert(A.Character:FindFirstChildOfClass("Humanoid").WalkSpeed > 0, "stun never ended")
	end)

	step("steal again and run home: deposit, STOLEN card, steal counted", function()
		assert(stealFromVault(A), "second steal failed")
		local slots = 0
		for _ in a.data.Slots do
			slots += 1
		end
		moveTo(A, inBase(a))
		task.wait(0.5)
		assert(a.carry == nil, "still carrying at home")
		local after = 0
		for _ in a.data.Slots do
			after += 1
		end
		assert(after == slots + 1, "plot " .. slots .. " -> " .. after)
		assert(a.data.Stats.Steals == 1 and A.attrs.Steals == 1, "steal not counted")
		assert(got(A, Remotes.Names.Deposited), "no STOLEN card")
	end)

	step("the STOLEN card names the vault", function()
		local title = nil
		for _, m in inbox[A] or {} do
			if m.name == Remotes.Names.Deposited then
				title = m.args[5]
			end
		end
		assert(title and string.find(title, "YOU STOLE FROM", 1, true), "title " .. tostring(title))
	end)

	step("upgrade signs show the next level and price", function()
		local found = false
		for _, sg in a.base.plotSign:GetChildren() do
			local l = sg:IsA("SurfaceGui") and sg:FindFirstChildOfClass("TextLabel")
			if l and string.find(l.Text, "Lv 2", 1, true) and string.find(l.Text, "$", 1, true) then
				found = true
			end
		end
		assert(found, "plot sign doesn't show Lv 2 -> 3 and a price")
	end)

	step("GUARD STRIKE: sleeping guards catch nobody", function()
		Events.start("GuardStrike", 30)
		assert(workspace:GetAttribute("EventId") == "GuardStrike", "event attribute not set")
		assert(announced("GUARD STRIKE"), "event not announced")
		assert(stealFromVault(A), "steal failed")
		local guard = nil
		for _, g in Guards.all() do
			if g.vault == 1 then
				guard = g
			end
		end
		moveTo(A, guard.root.Position + Vector3.new(1, 0, 0))
		task.wait(0.4)
		assert(a.carry ~= nil, "a sleeping guard caught the thief")
		assert(guard.model:GetAttribute("Asleep") == true, "guard not asleep")
		Carry.drop(A)
		assert(a.carry == nil, "drop failed")
		Events.stop()
	end)

	step("CASH FRENZY doubles income; GOLD RUSH restocks the vaults", function()
		local base = Bases.incomePerSecond(A)
		Events.start("CashFrenzy", 30)
		assert(
			math.abs(Bases.incomePerSecond(A) - base * Economy.Events.CashFrenzyMult) < 0.01,
			"frenzy not 2x"
		)
		Events.stop()
		Events.start("GoldRush", 30)
		task.wait(0.1)
		assert(VaultLoot.lootAt(1, 1) ~= nil, "vault not restocked")
		Events.stop()
	end)

	step("player steal: thief carries, victim warned, item hidden until home", function()
		moveTo(B, inBase(a))
		Bases.onSteal(B, A, "1")
		assert(b.carry ~= nil, "Bob isn't carrying")
		assert(B.attrs.CarryVictim == A.UserId, "CarryVictim not set (no GO GET THEM arrow)")
		assert(got(A, Remotes.Names.Notice, "is stealing"), "victim not warned")
		assert(Bases.isHidden(A, "1"), "item still visible on the plot")
		assert(a.data.Slots["1"] ~= nil, "item left the victim before the thief got home")
		Carry.caught(B, "Alice")
		assert(not Bases.isHidden(A, "1"), "slapped item not back")
		task.wait(1.7) -- the slap stun
		Bases.onSteal(B, A, "1")
		assert(b.carry ~= nil, "Bob couldn't steal again after the stun")
		moveTo(B, inBase(b))
		task.wait(0.5)
		assert(a.data.Slots["1"] == nil, "victim still has the item")
		assert(b.data.Stats.PlayerSteals == 1, "player steal not counted")
		assert(got(A, Remotes.Names.Notice, "stole your"), "victim not told")
	end)

	step("THE RICHEST: crown, beam, can't lock; robbing pays a bounty", function()
		Wallet.add(A, 1e9)
		Bases.addItem(A, "GoldBar", "None")
		Richest.evaluate()
		assert(a.isRichest and workspace:GetAttribute("RichestUserId") == A.UserId, "Alice not crowned")
		assert(A.Character:FindFirstChild("Crown"), "no crown")
		assert(a.base.beam.Transparency < 1, "no beam")
		assert(announced("THE RICHEST"), "crown not announced")
		Bases.lock(A)
		assert((a.base.model:GetAttribute("LockedUntil") or 0) == 0, "the richest locked their base")
		local slot = nil
		for k, it in a.data.Slots do
			if it.Id == "GoldBar" then
				slot = k
			end
		end
		local cash = b.data.Cash
		local robbed = b.data.Stats.RobbedRichest
		local bounty = Richest.bounty(A)
		assert(bounty >= Economy.Richest.MinBounty, "bounty " .. bounty)
		moveTo(B, inBase(a))
		Bases.onSteal(B, A, slot)
		moveTo(B, inBase(b))
		task.wait(0.5)
		-- the bounty is priced before the stolen item leaves the richest's plot
		assert(b.data.Cash >= cash + bounty, "bounty not paid: " .. (b.data.Cash - cash) .. " < " .. bounty)
		assert(b.data.Stats.RobbedRichest == robbed + 1, "robbery not counted")
		assert(announced("ROBBED THE RICHEST"), "robbery not announced")
	end)

	step("lock: intruders are teleported out and kept out", function()
		Richest.evaluate()
		if b.isRichest then
			Wallet.add(A, 1e12)
			Richest.evaluate()
		end
		Bases.lock(B)
		assert((b.base.model:GetAttribute("LockedUntil") or 0) > 0, "Bob's lock failed")
		assert(b.base.laser.CanCollide, "laser not solid")
		assert(b.base.model:FindFirstChild("LaserBarrier").CanCollide, "no blocker above the laser")
		moveTo(A, inBase(b))
		task.wait(1.2)
		assert(not Bases.contains(b.base, A.Character.PrimaryPart.Position), "intruder still inside")
		Bases.unlock(b.base)
	end)

	step("sell + fuse", function()
		local cash = a.data.Cash
		local slot = Bases.addItem(A, "Radio", "None")
		Bases.sell(A, slot)
		assert(a.data.Slots[slot] == nil and a.data.Cash > cash, "sell failed")
		for _ = 1, 3 do
			Bases.addItem(A, "Compass", "None")
		end
		Fuse.fuse(A, "Compass", "None")
		local gold, plain = 0, 0
		for _, it in a.data.Slots do
			if it.Id == "Compass" then
				if it.Mut == "Gold" then
					gold += 1
				elseif it.Mut == "None" then
					plain += 1
				end
			end
		end
		assert(gold == 1 and plain == 0, "fuse gave " .. gold .. " gold / " .. plain .. " plain")
	end)

	step("street pickup: cash (+ candy in season), then it respawns later", function()
		local pick = nil
		for _, p in Pickups.all() do
			if p.active then
				pick = p
				break
			end
		end
		assert(pick, "no active pickup")
		local cash, candy = a.data.Cash, a.data.Candy
		moveTo(A, pick.part.Position)
		task.wait(0.4)
		assert(a.data.Cash > cash, "no cash from the pickup")
		assert(not pick.active and pick.part.Transparency == 1, "pickup still there")
		assert(got(A, Remotes.Names.Pickup), "no pickup popup")
		if season then
			assert(a.data.Candy > candy, "no candy during Halloween")
		end
		moveTo(A, Vector3.new(0, 400, 0))
	end)

	step("trails: can't afford -> refused; buy, equip, take off; pass trail needs the pass", function()
		a.data.Cash = 0
		assert(not Cosmetic.buy(A, "Sparkle"), "bought without cash")
		Wallet.add(A, 1e4)
		assert(Cosmetic.buy(A, "Sparkle"), "buy failed")
		assert(a.data.Trails.Sparkle and a.data.Trail == "Sparkle", "not owned/equipped")
		assert(A.Character.PrimaryPart:FindFirstChild("RTR_Trail"), "no trail on the character")
		assert(A.attrs.TrailsOwned == "Sparkle", "TrailsOwned attr " .. tostring(A.attrs.TrailsOwned))
		assert(Cosmetic.equip(A, ""), "unequip failed")
		assert(A.Character.PrimaryPart:FindFirstChild("RTR_Trail") == nil, "trail still on")
		assert(
			not Cosmetic.buy(A, "Rainbow") and not Cosmetic.equip(A, "Rainbow"),
			"pass trail without the pass"
		)
		a.passes.RainbowTrail = true
		assert(Cosmetic.equip(A, "Rainbow"), "pass owner can't equip Rainbow")
		a.passes.RainbowTrail = nil
		if season then
			Cosmetic.addCandy(A, Cosmetics.trail("Pumpkin").price)
			assert(Cosmetic.buy(A, "Pumpkin"), "candy trail failed")
		end
	end)

	step("Auto Collect pass: cash goes straight to the wallet", function()
		moveTo(A, Vector3.new(0, 400, 0))
		a.passes.AutoCollect = true
		local cash = a.data.Cash
		task.wait(1.2)
		assert(a.data.Cash > cash and a.data.Pending < 1, "auto collect didn't run")
		a.passes.AutoCollect = nil
	end)

	step("a thief leaving mid-steal: item stays with the owner; base is freed", function()
		Bases.addItem(B, "Radio", "None")
		local slot = nil
		for k, it in b.data.Slots do
			if it.Id == "Radio" then
				slot = k
			end
		end
		moveTo(A, inBase(b))
		Bases.onSteal(A, B, slot)
		assert(a.carry ~= nil, "Alice isn't carrying")
		Carry.onLeaving(A)
		Richest.onLeaving(A)
		Bases.release(A)
		State.remove(A)
		assert(not Bases.isHidden(B, slot) and b.data.Slots[slot] ~= nil, "Bob lost his item")
		local free = false
		for _, base in world.bases do
			if Bases.ownerOf(base) == nil and base.signLabel.Text == "FREE BASE" then
				free = true
			end
		end
		assert(free, "Alice's base not freed")
		Carry.onLeaving(B)
		Bases.release(B)
		State.remove(B)
	end)
end
Net.sink = nil

print(string.format("SMOKE: %d passed, %d failed", passed, #failures))
return { passed = passed, failed = #failures, failures = failures }
