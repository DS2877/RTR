--!strict
-- Headless smoke test. CI runs this inside the real place on Roblox's servers via the Open Cloud
-- Luau Execution API (tools/ci/smoke.py), against a *saved* (not published) version of the build.
-- Place scripts don't auto-run there, so this boots the server services the same way
-- init.server.luau does, checks the built prison, then plays the whole M1 loop with a simulated
-- player: punch, break, vacuum, dump, buy, lift, chamber + zone, finds, sell, save.
-- Returns { passed, failed, failures } (CI fails the build when failed > 0).

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Services = Server:WaitForChild("Services")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

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

local function step(name: string, fn: () -> ()): boolean
	local ok, err = pcall(fn)
	check(name, ok, err)
	return ok
end

local function req(parent: Instance, name: string): any
	return (require :: any)(parent:WaitForChild(name))
end

local Remotes = req(Shared, "Remotes")
local Voxel = req(Shared, "Voxel")
local Tunnel = req(Shared, "Tunnel")
local Progression = req(Shared, "Progression")
local World = req(Config, "World")
local Economy = req(Config, "Economy")
local Assets = req(Config, "Assets")
local Cycle = req(Config, "Cycle")

local State = req(Server, "State")
local Net = req(Server, "Net")
local WorldBuilder = req(Services, "WorldBuilder")
local Data = req(Services, "Data")
local Cells = req(Services, "Cells")
local Dig = req(Services, "Dig")
local Loot = req(Services, "Loot")
local Shop = req(Services, "Shop")
local Gym = req(Services, "Gym")
local Admin = req(Services, "Admin")
local Stats = req(Services, "Stats")
local DayNight = req(Services, "DayNight")
local Collection = req(Services, "Collection")
local Brawl = req(Services, "Brawl")
local Raid = req(Services, "Raid")
local TopDog = req(Services, "TopDog")
local Product = req(Services, "Product")
local Escape = req(Services, "Escape")
local Rewards = req(Services, "Rewards")
local Guards = req(Services, "Guards")
local Hideout = req(Services, "Hideout")
local Events = req(Services, "Events")
local Market = req(Services, "Market")

local sent: { { name: string, args: { any } } } = {}
Net.sink = function(_player: any, name: string, args: { any })
	table.insert(sent, { name = name, args = args })
end
local function count(name: string): number
	local n = 0
	for _, m in sent do
		if m.name == name then
			n += 1
		end
	end
	return n
end

-- ===== boot (same order as init.server.luau) =====
local world: any = nil
step("Remotes.setup", Remotes.setup)
if not step("WorldBuilder.build", function()
	world = WorldBuilder.build()
end) then
	return { passed = passed, failed = #failures, failures = failures }
end
step("Cells.start", function()
	Cells.start(world)
end)
step("Hideout.start", function()
	Hideout.start(world)
end)
Dig.beforePunch = Hideout.beforePunch
step("Dig.start", Dig.start)
step("Loot.start", function()
	Loot.start(world)
end)
step("Shop.start", function()
	Shop.start(world)
end)
step("Gym.start", function()
	Gym.start(world)
end)
step("Admin.start", Admin.start)
step("DayNight.start", function()
	DayNight.start(world)
end)
step("Brawl.start", function()
	Brawl.start(world)
end)
step("Raid.start", function()
	Raid.start(world)
end)
step("TopDog.start", function()
	TopDog.start(world)
end)
step("Product.start", Product.start)
step("Escape.start", Escape.start)
step("Rewards.start", Rewards.start)
step("Guards.start", Guards.start)
step("Events.startService", Events.startService)
step("Market.start", function()
	Market.start(world)
end)
DayNight.riot = Events.riot
Events.onRiot = DayNight.setRiot
Events.phase = DayNight.phase
Dig.powerBoost = Market.powerBoost
Dig.findBoost = Market.findBoost
Dig.speedBoost = Market.speedBoost
Loot.magnet = Market.magnet
Dig.onPiles = Loot.sendPiles
Dig.onFind = Collection.onFound
local function isDay(): boolean
	return DayNight.phase() == "Day"
end
Brawl.isDay = isDay
Raid.isDay = isDay
Brawl.onCarrierHit = function(thief)
	Raid.returnCarry(thief, "hit")
end

-- ===== world checks =====
check("12 cells", #world.cells == World.CellCount, #world.cells)
check("3 shops", world.shops.Workshop and world.shops.Commissary and world.shops.Fence and true or false)
for name, counter in world.shops do
	check("shop prompt " .. name, counter:FindFirstChild("ShopPrompt") ~= nil)
end
check("dump prompt", world.dump:FindFirstChild("DumpPrompt") ~= nil)
check("gym stations", #world.stations == #Economy.Gym, #world.stations)
for i, cell in world.cells do
	local frame: CFrame = cell.frame
	-- spawn is inside the cell, in front of the back wall, facing it
	local local_ = frame:PointToObjectSpace(cell.spawn.Position)
	check("cell " .. i .. " spawn in front of the wall", local_.Z > 2 and math.abs(local_.X) < 18, local_)
	check("cell " .. i .. " spawn faces the wall", cell.spawn.LookVector:Dot(frame.LookVector) > 0.9)
	-- tunnels of different cells never overlap
	for j, other in world.cells do
		if j > i then
			local a, b = frame.Position, other.frame.Position
			local sameRow = Tunnel.row(i) == Tunnel.row(j)
			check(
				string.format("tunnels %d/%d apart", i, j),
				(sameRow and math.abs(a.X - b.X) >= World.TunnelWidth * World.BlockSize)
					or (not sameRow and frame.LookVector:Dot(other.frame.LookVector) < -0.9)
			)
		end
	end
end
-- bedrock surrounds the volumes: something solid under the far end of tunnel 1
do
	local far = Tunnel.blockCenter(world.cells[1].frame, 9, 0, World.TunnelDepth - 1)
	local hit = workspace:Raycast(far, Vector3.new(0, -6, 0))
	check("bedrock floor under the tunnel end", hit ~= nil)
end

-- ===== z-fighting: visible faces of two parts lying in the same plane, facing the same way =====
do
	type Face = {
		axis: number,
		sign: number,
		d: number,
		u0: number,
		u1: number,
		v0: number,
		v1: number,
		name: string,
	}
	local faces: { [string]: { Face } } = {}
	local function axisAligned(cf: CFrame): boolean
		for _, v in { cf.RightVector, cf.UpVector, cf.LookVector } do
			local a = math.max(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
			if a < 0.999 then
				return false
			end
		end
		return true
	end
	local function addBox(name: string, lo: Vector3, hi: Vector3)
		local l = { lo.X, lo.Y, lo.Z }
		local h = { hi.X, hi.Y, hi.Z }
		for axis = 1, 3 do
			local u = if axis == 1 then 2 else 1
			local v = if axis == 3 then 2 else 3
			for _, sign in { -1, 1 } do
				local d = if sign < 0 then l[axis] else h[axis]
				-- bottoms resting on the floor are never seen
				if axis == 2 and sign < 0 and d <= 0.05 then
					continue
				end
				local key = axis .. ":" .. sign .. ":" .. math.floor(d * 20 + 0.5)
				local list = faces[key]
				if not list then
					list = {}
					faces[key] = list
				end
				table.insert(list, {
					axis = axis,
					sign = sign,
					d = d,
					u0 = l[u],
					u1 = h[u],
					v0 = l[v],
					v1 = h[v],
					name = name,
				})
			end
		end
	end
	for _, d in workspace:GetDescendants() do
		if
			d:IsA("Part")
			and d.Shape == Enum.PartType.Block
			and d.Transparency < 0.95
			and axisAligned(d.CFrame)
			and not d:FindFirstAncestorOfClass("Tool")
		then
			local half = d.CFrame:VectorToWorldSpace(d.Size / 2)
			half = Vector3.new(math.abs(half.X), math.abs(half.Y), math.abs(half.Z))
			addBox(d:GetFullName(), d.Position - half, d.Position + half)
		end
	end
	-- the client's voxel back wall of every cell (one slab per cell)
	for i, c in world.cells do
		local f: CFrame = c.frame
		local a = f:PointToWorldSpace(Vector3.new(-World.TunnelWidth, 0, 0))
		local b = f:PointToWorldSpace(
			Vector3.new(World.TunnelWidth, World.TunnelHeight * World.BlockSize, -World.BlockSize)
		)
		addBox("VoxelWall" .. i, a:Min(b), a:Max(b))
	end
	local hits: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, list in faces do
		for i = 1, #list do
			for j = i + 1, #list do
				local a, b = list[i], list[j]
				local du = math.min(a.u1, b.u1) - math.max(a.u0, b.u0)
				local dv = math.min(a.v1, b.v1) - math.max(a.v0, b.v0)
				if du > 0.05 and dv > 0.05 and math.abs(a.d - b.d) < 0.03 then
					local short = function(n: string): string
						return (string.gsub(n, "^Workspace%.", ""))
					end
					local line = short(a.name) .. " <> " .. short(b.name)
					if not seen[line] then
						seen[line] = true
						if du * dv > 0.1 then
							table.insert(
								hits,
								string.format("%s (%.1fx%.1f, axis %d at %.2f)", line, du, dv, a.axis, a.d)
							)
						end
					end
				end
			end
		end
	end
	table.sort(hits)
	print(string.format("zfight: %d overlapping face pairs", #hits))
	for k = 1, math.min(#hits, 400) do
		print("zfight " .. hits[k])
	end
	check("no z-fighting faces", #hits == 0, hits[1])
end

-- ===== world dump (CI uploads it as an artifact; tools/view renders it so we can SEE the prison) =====
local worldDump = ""
do
	local lines: { string } = {}
	local function f(n: number): string
		return string.format("%.2f", n)
	end
	local index: { [Instance]: number } = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "Terrain" then
			local cf = d.CFrame
			local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
			local shape = if d:IsA("Part")
				then d.Shape.Name
				elseif d:IsA("WedgePart") then "Wedge"
				elseif d:IsA("SpawnLocation") then "Block"
				else "Block"
			local c = d.Color
			table.insert(
				lines,
				table.concat({
					"P",
					d.Name,
					shape,
					f(cf.X),
					f(cf.Y),
					f(cf.Z),
					f(r00),
					f(r01),
					f(r02),
					f(r10),
					f(r11),
					f(r12),
					f(r20),
					f(r21),
					f(r22),
					f(d.Size.X),
					f(d.Size.Y),
					f(d.Size.Z),
					tostring(math.floor(c.R * 255 + 0.5)),
					tostring(math.floor(c.G * 255 + 0.5)),
					tostring(math.floor(c.B * 255 + 0.5)),
					d.Material.Name,
					f(d.Transparency),
				}, "|")
			)
			index[d] = #lines
		end
	end
	for _, d in workspace:GetDescendants() do
		local holder = d.Parent
		if
			(d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight"))
			and holder
			and holder:IsA("BasePart")
		then
			local p = holder.Position
			local c = d.Color
			table.insert(
				lines,
				table.concat({
					"L",
					d.ClassName,
					f(p.X),
					f(p.Y),
					f(p.Z),
					tostring(math.floor(c.R * 255)),
					tostring(math.floor(c.G * 255)),
					tostring(math.floor(c.B * 255)),
					f((d :: any).Range),
					f((d :: any).Brightness),
				}, "|")
			)
		elseif d:IsA("SurfaceGui") and holder and index[holder] then
			local label = d:FindFirstChildWhichIsA("TextLabel", true)
			if label and label.Text ~= "" then
				local tc = label.TextColor3
				table.insert(
					lines,
					table.concat({
						"T",
						tostring(index[holder]),
						d.Face.Name,
						(string.gsub(label.Text, "[|\n]", " ")),
						tostring(math.floor(tc.R * 255)),
						tostring(math.floor(tc.G * 255)),
						tostring(math.floor(tc.B * 255)),
					}, "|")
				)
			end
		end
	end
	worldDump = table.concat(lines, "\n")
	print(string.format("world dump: %d lines, %d bytes", #lines, #worldDump))
end

-- ===== simulated player =====
local fake: any = { UserId = -4242, Name = "SmokeTester", Position = Vector3.zero }
local s = State.add(fake, Data.fresh())
local cell = Cells.assign(fake)
check("cell assigned", cell == 1, cell)
Dig.loadTunnel(fake)
s.ready = true
Dig._updateWatching()
check("snapshot sent to the owner", count("Snapshot") >= 1, count("Snapshot"))

local frame: CFrame = s.frame
local function standAt(x: number, y: number, z: number)
	fake.Position = Tunnel.blockCenter(frame, x, y, z)
end
local function punch(x: number, y: number, z: number, face: number): string?
	s.lastPunch = 0
	task.wait(0.22)
	return Dig.punch(fake, x, y, z, face)
end

-- in front of the back wall (z = -2 is inside the cell)
standAt(9, 1, -2)
check("bad args rejected", punch(9.5, 1, 0, 6) == "bad args")
check("buried block rejected", punch(9, 1, 1, 6) == "not solid" or punch(9, 1, 1, 6) == "not exposed")
standAt(9, 1, -12)
check("out of reach rejected", punch(9, 1, 0, 6) == "out of reach")
standAt(9, 1, -2)
local hits = Progression.hitsToBreak(Progression.blockHp(0), Progression.punchPower(s.data.Strength, 1, 0))
-- pick a block with no find inside for the plain break test
local bx = 9
for x = 4, 14 do
	if not Progression.findAt(s.data.Seed, x, 1, 0) then
		bx = x
		break
	end
end
for _ = 1, hits - 1 do
	punch(bx, 1, 0, 6)
end
check(
	"block damaged, not broken",
	Voxel.isSolid(s.grid, bx, 1, 0) and s.damage[Voxel.index(s.grid, bx, 1, 0)] ~= nil
)
check("punch accepted", punch(bx, 1, 0, 6) == nil)
check("block broken after " .. hits .. " hits", Voxel.isDug(s.grid, bx, 1, 0))
check("delta sent", count("Delta") >= hits, count("Delta"))
check("rubble pile", s.loose == 1 and #s.piles == 1, s.loose)
check("block behind is exposed now", Voxel.isExposed(s.grid, bx, 1, 1))

-- vacuum
fake.Position = s.piles[1].pos
check("vacuum moves rubble", Loot.vacuum(fake) == 1 and s.data.Bag == 1 and s.loose == 0, s.data.Bag)

-- a full backpack warns but never blocks digging
s.data.Bag = 9999
standAt(9, 1, -2)
local fullBefore = count("Full")
check("full backpack still digs", punch(bx + 1, 1, 0, 6) == nil and count("Full") > fullBefore)
s.data.Bag = 1
s.data.BagValue = 1

-- dump
fake.Position = world.dump.Position
local pay = Loot.dump(fake)
check("dump pays noodles", pay == 1 and s.data.Noodles == 1 and s.data.Bag == 0, pay)

-- shop
s.data.Noodles = 1000
fake.Position = world.shops.Workshop.Position
check("buy spoon", Shop.buy(fake, "Tools") == 2 and s.data.Levels.Tools == 2)
check("commissary item refused at the workshop", Shop.buy(fake, "Backpack") == nil)
fake.Position = world.shops.Commissary.Position
check("buy backpack", Shop.buy(fake, "Backpack") == 2)
s.data.Noodles = 0
check("too poor", select(2, Shop.buy(fake, "Backpack")) == "poor")

-- night: flush the backpack down your own toilet for less
do
	local myCell = world.cells[s.cell]
	fake.Position = myCell.toilet.Position
	s.data.Bag, s.data.BagValue = 5, 100
	local oldCan = Loot.canFlush
	Loot.canFlush = function()
		return false
	end
	check("no flushing by day", Loot.flush(fake) == 0 and s.data.Bag == 5)
	Loot.canFlush = function()
		return true
	end
	local pay = Loot.flush(fake)
	check("flush at night", pay > 0 and pay < 100 * 2 and s.data.Bag == 0, pay)
	Loot.canFlush = oldCan
	s.data.Noodles = 0
	check("toilet has a flush prompt", myCell.toilet:FindFirstChild("FlushPrompt") ~= nil)
end

-- gym: hoist the toilet, rep with the needle in the gold center / at the edge
fake.Position = world.stations[1].Position
local before = s.data.Strength
check("no rep without lifting", select(2, Gym.lift(fake)) == "")
check("start lifting", Gym.begin(fake, 1) == nil and Gym.lifting(fake) ~= nil)
local l = Gym.lifting(fake)
local speed = Economy.Gym[1].meter
local gain, q = Gym.lift(fake, l.start + 0.5 / speed) -- needle exactly in the middle
check("perfect rep", q == "perfect" and gain == 2 and s.data.Strength == before + 2, q)
check("rep rate limited", select(2, Gym.lift(fake, l.start + 0.5 / speed)) == "")
s.lastLift = 0
local g2, q2 = Gym.lift(fake, l.start + 0.001) -- needle at the edge
check("missed rep", q2 == "miss" and g2 == 0, q2)
s.lastLift = 0
local center = Progression.liftCenter(1, l.reps)
local g3, q3 = Gym.lift(fake, l.start + center / speed) -- the green zone moved: hit it there
check("perfect at the moved zone", q3 == "perfect" and g3 > 0, { q3, center })
Gym.stop(fake)
check("put it down", Gym.lifting(fake) == nil)
fake.Position = world.stations[3].Position
check("vending machine needs strength", Gym.begin(fake, 3) == "weak")
check("gym props built", world.stations[1].Parent:FindFirstChild("Toilet") ~= nil)

-- finds: break a find block on the face
s.data.Strength = 1e6
local found: { number }? = nil
for y = 0, World.TunnelHeight - 1 do
	for x = 0, World.TunnelWidth - 1 do
		if not found and Progression.findAt(s.data.Seed, x, y, 0) and Voxel.isSolid(s.grid, x, y, 0) then
			found = { x, y }
		end
	end
end
if found then
	standAt(found[1], math.max(0, found[2] - 1), -2)
	punch(found[1], found[2], 0, 6)
	check("find dug up", #s.data.Finds == 1 and count("Found") == 1, #s.data.Finds)
	fake.Position = world.shops.Fence.Position
	local got = Loot.sell(fake, 0)
	check("fence buys finds", got > 0 and #s.data.Finds == 0 and s.data.Noodles == got, got)
else
	check("a find on the back wall (seed " .. s.data.Seed .. ")", true)
end

-- chamber + zone 2 (admin path, then break the last layer)
step("admin zone 2", function()
	Admin.run(fake, "zone", 2)
end)
local start2 = Progression.zoneStart(2)
local mid = World.TunnelWidth // 2
check("admin path dug", Voxel.isDug(s.grid, mid, 1, start2 - 2))
s.data.Bag, s.loose, s.piles = 0, 0, {}
standAt(mid, 1, start2 - 3)
local reason = punch(mid, 1, start2 - 1, 6)
check("break into zone 2", reason == nil and Voxel.isDug(s.grid, mid, 1, start2 - 1), reason)
local box = Progression.chamberBox(2)
check("chamber opened", box ~= nil and Voxel.isDug(s.grid, box.x0 + 1, 1, box.z0 + 1))
check("zone 2 reached", s.data.Zone == 2 and count("Zone") >= 1, s.data.Zone)
check("chamber event", count("Chamber") >= 1)

-- collection shelf
step("collection render", function()
	Collection.render(fake)
end)
check(
	"collection shelf filled",
	#world.cells[1].shelf:GetChildren() > Economy.OpenZones,
	#world.cells[1].shelf:GetChildren()
)
local all: { [string]: boolean } = {}
for _, f in req(Config, "Finds").ByZone[1] do
	all[f.id] = true
end
check("a full zone set gives a bonus", Progression.collectionMultiplier(all) > 1)

-- day / night
check("starts by day", ReplicatedStorage:GetAttribute("Phase") == "Day")
check("doors open by day", world.cells[1].doorBlock.CanCollide == false)
DayNight.force("night")
task.wait(0.6)
check(
	"night phase",
	ReplicatedStorage:GetAttribute("Phase") == "Night",
	ReplicatedStorage:GetAttribute("Phase")
)
check("doors locked at night", world.cells[1].doorBlock.CanCollide == true)
check("night find bonus", Dig.nightBonus > 0)
check("cell counts as home", DayNight.inOwnCell(s, world.cells[1].spawn.Position))
check("tunnel counts as home", DayNight.inOwnCell(s, Tunnel.blockCenter(frame, 9, 1, 30)))
check("corridor is not home", not DayNight.inOwnCell(s, Vector3.new(0, 3, 0)))
DayNight.force("day")
task.wait(0.6)
check(
	"day again",
	ReplicatedStorage:GetAttribute("Phase") == "Day" and world.cells[1].doorBlock.CanCollide == false
)
check("mess hall built", workspace.Prison.CommonRoom:FindFirstChild("MessFloor") ~= nil)
-- roll call: whoever stands in their own cell when it ends is counted
do
	local counted = false
	DayNight.onCounted = function(p)
		if p == fake then
			counted = true
		end
	end
	fake.Position = world.cells[1].spawn.Position
	DayNight.force("rollcall")
	task.wait(0.6)
	check("roll call phase", ReplicatedStorage:GetAttribute("Phase") == "RollCall")
	check("doors open at roll call", world.cells[1].doorBlock.CanCollide == false)
	DayNight.force("day")
	task.wait(0.6)
	check("counted at roll call", counted)
	DayNight.onCounted = nil
end
-- patrolling guards: a line for every situation
do
	local Patrol = req(Services, "Patrol")
	Patrol.phase = DayNight.phase
	local ok, kind = pcall(Patrol.situation, Vector3.new(0, 3, 0), "Day")
	check("guard situation", ok and typeof(kind) == "string", kind)
	s.data.Bag = 1000
	local kind2 = Patrol.situation(fake.Position, "Day")
	check("guard notices the full backpack", kind2 == "Bag" or kind2 == "Digging", kind2)
	s.data.Bag = 0
end

-- ===== M3: PvP with a second simulated player =====
local raider: any = { UserId = -5151, Name = "SmokeRaider", Position = Vector3.zero }
local r = State.add(raider, Data.fresh())
check("second cell", Cells.assign(raider) == 2)
Dig.loadTunnel(raider)
local yard = Vector3.new(World.Yard.x, 3, World.Yard.z)
local function brawl(a: any, b: any): string?
	local as = State.get(a)
	as.lastBrawl = 0
	return Brawl.punch(a, b.UserId)
end
fake.Position = yard
raider.Position = yard + Vector3.new(4, 0, 0)
check("yard is not safe", not Brawl.isSafe(yard))
check("cells are safe", Brawl.isSafe(world.cells[1].spawn.Position))
check("shops are safe", Brawl.isSafe(world.shops.Workshop.Position))
check("punch a player", brawl(fake, raider) == nil and r.stamina < 100, r.stamina)
check("stronger hits harder", Brawl.damage(1000, 10) > Brawl.damage(10, 1000))
check("can't punch yourself", brawl(fake, fake) == "no victim")
raider.Position = yard + Vector3.new(30, 0, 0)
check("out of reach", brawl(fake, raider) == "out of reach")
raider.Position = world.shops.Workshop.Position
fake.Position = world.shops.Workshop.Position + Vector3.new(0, 0, 4)
check("safe zone", brawl(fake, raider) == "safe zone")
fake.Position = yard
-- knockout drops rubble + a find
raider.Position = yard + Vector3.new(4, 0, 0)
r.data.Bag, r.data.BagValue = 20, 40
r.data.Finds = { "OldCoin" }
r.stamina = 1
check("knockout", brawl(fake, raider) == nil and r.data.Bag == 14 and #r.data.Finds == 0, r.data.Bag)
check("drop on the floor", #Brawl.drops() == 1 and Brawl.drops()[1].rubble == 6)
check("protected after knockout", brawl(fake, raider) == "protected")
s.data.Bag, s.data.BagValue, s.data.Finds = 0, 0, {}
fake.Position = raider.Position
raider.Position = yard + Vector3.new(40, 0, 0)
task.wait(0.6)
check("pick up the drop", s.data.Bag == 6 and #s.data.Finds == 1 and #Brawl.drops() == 0, s.data.Bag)
DayNight.force("night")
task.wait(0.6)
r.protectedUntil = 0
check("no brawls at night", brawl(fake, raider) == "night")
DayNight.force("day")
task.wait(0.6)

-- raids: the raider steals from cell 1's Stash
fake.Position = world.cells[1].stash.Position
s.data.Finds = { "OldCoin", "SecretNote" }
check("stash put", Raid.stashCmd(fake, "put") == 2 and #s.data.Stash == 2)
check("stash take", Raid.stashCmd(fake, "take") == 2 and #s.data.Finds == 2)
Raid.stashCmd(fake, "put")
raider.Position = world.cells[1].stash.Position
check("lock needs the hold", Raid.steal(raider, 1) == "lock")
check("can't rob yourself", Raid.steal(fake, 1, true) == "own stash")
check("steal", Raid.steal(raider, 1, true) == nil and r.carrying ~= nil and #s.data.Stash == 1)
check("took the most valuable", r.carrying and r.carrying.id == "SecretNote")
check("one at a time", Raid.steal(raider, 1, true) == "already carrying")
raider.Position = world.cells[2].spawn.Position
task.wait(0.6)
check(
	"heist delivered",
	r.carrying == nil and table.find(r.data.Finds, "SecretNote") ~= nil and r.data.Stats.Steals == 1
)
-- hit the thief = it goes back
raider.Position = world.cells[1].stash.Position
Raid.steal(raider, 1, true)
fake.Position = yard
raider.Position = yard + Vector3.new(3, 0, 0)
r.protectedUntil = 0
brawl(fake, raider)
check("hit thief drops it", r.carrying == nil and #s.data.Stash == 1, #s.data.Stash)
-- night takes it back too
raider.Position = world.cells[1].stash.Position
Raid.steal(raider, 1, true)
DayNight.force("night")
task.wait(0.6)
check("guards return it at night", r.carrying == nil and #s.data.Stash == 1)
check("no raids at night", Raid.steal(raider, 1, true) == "night")
DayNight.force("day")
task.wait(0.6)
step("top dog update", TopDog.update)
Cells.release(raider)
State.remove(raider)

-- locked zones can't be dug
local locked = Progression.diggableDepth()
check("diggable depth", locked == Progression.zoneStart(Economy.OpenZones + 1))

-- save round trip
s.tunnelDirty = true
Dig.saveTunnel(s)
local back = Voxel.deserialize(
	s.data.Tunnel,
	World.TunnelWidth,
	World.TunnelHeight,
	World.TunnelDepth,
	World.ChunkSize
)
check("tunnel save round trip", back.count == s.grid.count and back.count > 0, back.count)
check("save is small", #s.data.Tunnel < 20000, #s.data.Tunnel)

-- reset tunnel
Admin.run(fake, "resettunnel")
check("tunnel reset", s.grid.count == 0 and s.data.Zone == 1)

-- stress layout fits the budget on the server copy too
Admin.stress(fake)
check("stress dig", s.grid.count > 4000, s.grid.count)

-- ===== M4 =====
check("all zones open", Progression.diggableDepth() == World.TunnelDepth)
check(
	"every shop counter has a prompt",
	world.shops.Store and world.shops.Laundry and world.shops.MessHall and world.shops.BlackMarket and true
		or false
)
for name, counter in world.shops do
	check("prompt " .. name, counter:FindFirstChild("ShopPrompt") ~= nil)
end
check("VIP door", #game:GetService("CollectionService"):GetTagged("VIPDoor") == 1)
-- developer products
local before4 = s.data.Noodles
check(
	"grant noodle crate",
	Product.grant(fake, "NoodlesSmall") and s.data.Noodles == before4 + Product.packAmount(s, "NoodlesSmall")
)
s.data.Bag, s.data.BagValue = 10, 50
s.piles = { { id = 99, pos = Vector3.zero, rubble = 3, value = 9 } }
s.loose = 3
local n4 = s.data.Noodles
check(
	"instant empty",
	Product.grant(fake, "InstantEmpty") and s.data.Bag == 0 and s.loose == 0 and s.data.Noodles > n4
)
check("grant dynamite", Product.grant(fake, "Dynamite") and s.data.Dynamite == 1)
-- dynamite in the stress tunnel (stand at its front)
s.data.Bag, s.loose, s.piles = 0, 0, {}
standAt(9, 1, 2)
local beforeCount = s.grid.count
local boomAt: { number }? = nil
for z = 0, 30 do
	if not boomAt and Voxel.isExposed(s.grid, 5, 1, z) then
		boomAt = { 5, 1, z }
	end
end
if boomAt then
	standAt(6, 1, boomAt[3])
	check(
		"dynamite",
		Dig.dynamite(fake, boomAt[1], boomAt[2], boomAt[3]) == nil and s.grid.count > beforeCount + 20,
		s.grid.count - beforeCount
	)
	check(
		"dynamite used up",
		s.data.Dynamite == 0 and Dig.dynamite(fake, boomAt[1], boomAt[2], boomAt[3]) == "no dynamite"
	)
end
-- daily reward + cellmate
local today = Rewards.today()
check("daily reward", Rewards.daily(fake, today) > 0 and s.data.Daily.Streak == 1)
check("daily only once", Rewards.daily(fake, today) == 0)
check("daily streak", Rewards.daily(fake, today + 1) > 0 and s.data.Daily.Streak == 2)
s.data.Bag = 0
local dug = Rewards.cellmate(fake, 3600)
check("cellmate digs while away", dug > 0 and s.data.Bag == dug and s.data.Bag <= Stats.capacity(s), dug)
check("cellmate capped by the backpack", Rewards.cellmate(fake, 999999) <= Stats.capacity(s))
-- guard inspection: hide = safe, caught = unsold finds gone
s.data.Finds = { "OldCoin" }
check("every cell has a cover", world.cells[1].model:FindFirstChild("Cover") ~= nil)
check("inspection starts", Guards.inspect(fake))
check("hide = bed + cover", Guards.hide(fake) and s.hidden and s.coverDown)
check("no punching from bed", Hideout.beforePunch(fake, s) == false)
task.wait(Cycle.InspectWarning + 0.4)
check("hidden = finds kept", #s.data.Finds == 1)
-- in bed but the hole showing: caught
Hideout.setCover(fake, false)
Guards.inspect(fake)
task.wait(Cycle.InspectWarning + 0.4)
check("hole showing = caught", #s.data.Finds == 0)
Hideout.setHidden(fake, false)
s.data.Finds = { "OldCoin" }
Hideout.setCover(fake, true)
check("punching rolls the cover up", Hideout.beforePunch(fake, s) == true and not s.coverDown)
s.data.Finds = {}
local snitchVictim: any = { UserId = -6262, Name = "SmokeSnitched", Position = Vector3.zero }
local sv = State.add(snitchVictim, Data.fresh())
s.data.Noodles = 1e9
check("snitch", Guards.snitch(fake, snitchVictim.UserId) == nil and sv.snitched)
check("snitch once", Guards.snitch(fake, snitchVictim.UserId) == "already")
State.remove(snitchVictim)
-- events
Events.stop()
check("blackout", Events.trigger("BLACKOUT") and Dig.globalBoost == 2)
Events.stop()
check("blackout ends", Dig.globalBoost == 1)
check("riot", Events.trigger("RIOT") and Events.riot())
Events.stop()
check("treasure race", Events.trigger("TREASURE") and Events.treasureOf(fake) ~= nil)
local tidx = Events.treasureOf(fake)
if tidx then
	local tx, ty, tz = Voxel.unindex(s.grid, tidx)
	local n5 = s.data.Noodles
	Dig.applyHits(fake, s, { { tx, ty, tz } }, math.huge)
	check("treasure won", s.data.Noodles > n5 and Events.current() == nil and #s.data.Stash >= 1)
end
-- Mess Hall, Laundry, Decor, Black Market
fake.Position = world.shops.MessHall.Position
check("eat stew", Market.buy(fake, "MessHall", "Stew") == nil and Market.powerBoost(fake) > 1.2)
fake.Position = world.shops.Laundry.Position
check("buy uniform", Market.buy(fake, "Laundry", "Stripes") == nil and s.data.Uniform == "Stripes")
fake.Position = world.shops.Workshop.Position
check("buy decor", Market.buy(fake, "Decor", "Lamp") == nil and s.data.Decor.Lamp == 1)
standAt(9, 1, 3)
check("place decor", Market.place(fake, "Lamp") == nil and #s.data.Placed == 1 and s.data.Decor.Lamp == 0)
check("decor rendered", workspace.Prison.Decor:FindFirstChild("Cell1") ~= nil)
fake.Position = world.shops.BlackMarket.Position
local stock = Progression.marketStock(os.time() // 86400)
check("black market", Market.buy(fake, "BlackMarket", stock[1]) == nil)
check("black market sells only today's stock", Market.buy(fake, "BlackMarket", "Nope") == "not sold")
Market.morning()
check(
	"meals end in the morning",
	Market.powerBoost(fake) < 1.2 or s.buffs.Shake ~= nil or s.buffs.Gloves ~= nil
)
-- ESCAPE (rebirth)
check("no escape before the bottom", Escape.escape(fake) == "not at the bottom")
Admin.run(fake, "bottom")
check("escape ready", s.escapeReady)
check("escape", Escape.escape(fake) == nil and s.data.Rebirths == 1 and s.grid.count == 0)
check("escape keeps the record", s.data.MaxDepth >= World.TunnelDepth - 1)
check("escape keeps the collection", next(s.data.Found) ~= nil)
check("escape resets tools", s.data.Levels.Tools == 1 and s.data.Noodles == 0)
check("decor back in the box", #s.data.Placed == 0 and s.data.Decor.Lamp == 1)
check("rebirth multiplier", Progression.punchPower(10, 1, 1) > Progression.punchPower(10, 1, 0))

Cells.release(fake)
State.remove(fake)

-- ===== assets =====
local allSounds: { [string]: string } = table.clone(Assets.Sounds)
for i, id in Assets.Music.Playlist do
	allSounds["Music" .. i] = id
end
allSounds.Chase = Assets.Music.Chase
local Audio = req(Config, "Audio")
for bank, list in Audio.Banks do
	for i, id in list do
		allSounds[bank .. i] = id
	end
end
for name, id in Audio.Loops do
	allSounds["Loop" .. name] = id
end
for name, m in Audio.Materials do
	check("audio material " .. name, Audio.Banks[m.hit] ~= nil and Audio.Banks[m.breakBank] ~= nil)
end
for name, id in allSounds do
	local num = tonumber(string.match(id, "%d+"))
	if num then
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(num, Enum.InfoType.Asset)
		end)
		check(
			"sound " .. name .. " exists",
			ok and info ~= nil and (info :: any).AssetTypeId == 3,
			if ok then nil else info
		)
	end
end

for _, list in
	{
		Assets.Animations.PunchR15,
		Assets.Animations.PunchR6,
		{ Assets.Animations.LiftR15, Assets.Animations.LiftR6 },
	}
do
	for _, id in list do
		local num = tonumber(string.match(id, "%d+"))
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(num, Enum.InfoType.Asset)
		end)
		check(
			"animation " .. id .. " exists",
			ok and info ~= nil and (info :: any).AssetTypeId == 24,
			if ok and info then (info :: any).AssetTypeId else info
		)
	end
end

print(string.format("smoke: %d passed, %d failed", passed, #failures))
return { passed = passed, failed = #failures, failures = failures, world = worldDump }
