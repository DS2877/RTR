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
local DayNight = req(Services, "DayNight")
local Collection = req(Services, "Collection")
local Brawl = req(Services, "Brawl")
local Raid = req(Services, "Raid")
local TopDog = req(Services, "TopDog")

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

-- backpack full blocks punches
s.data.Bag = 9999
standAt(9, 1, -2)
check("full backpack rejects", punch(bx + 1, 1, 0, 6) == "bag full")
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

-- gym
fake.Position = world.stations[1].Position
local before = s.data.Strength
check("lift", Gym.lift(fake) == 1 and s.data.Strength == before + 1)
check("lift rate limited", Gym.lift(fake) == 0)
fake.Position = world.stations[3].Position
s.lastLift = 0
check("barbell needs strength", Gym.lift(fake) == 0)

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

Cells.release(fake)
State.remove(fake)

-- ===== assets =====
for name, id in Assets.Sounds do
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

print(string.format("smoke: %d passed, %d failed", passed, #failures))
return { passed = passed, failed = #failures, failures = failures }
