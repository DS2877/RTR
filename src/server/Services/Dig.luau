--!strict
-- The digging server: owns every tunnel's grid, validates each punch (solid, exposed through the
-- given face, in reach of the HumanoidRootPart, attack rate, backpack space), applies brush damage,
-- breaks blocks, opens chambers and streams compact deltas to the clients that render that tunnel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Zones = require(Shared.Config.Zones)
local Voxel = require(Shared.Voxel)
local Progression = require(Shared.Progression)
local Tunnel = require(Shared.Tunnel)
local Remotes = require(Shared.Remotes)
local Products = require(Shared.Config.Products)
local PvP = require(Shared.Config.PvP)
local Format = require(Shared.Format)
local Pets = require(Shared.Pets)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Stats = require(script.Parent.Stats)
local Cells = require(script.Parent.Cells)
local Loot = require(script.Parent.Loot)
local VaultDoor = require(script.Parent.Parent.Util.VaultDoor)

local Dig = {}

local W, H, D, CS = World.TunnelWidth, World.TunnelHeight, World.TunnelDepth, World.ChunkSize

-- hooks other services plug into (set in init) so Dig doesn't require them
Dig.onPiles = nil :: ((player: Player) -> ())?
Dig.onFind = nil :: ((player: Player, id: string, firstTime: boolean) -> ())?

-- night digging: share of extra finds hidden in plain blocks (DayNight sets it)
Dig.nightBonus = 0
Dig.eventBonus = 0 -- GOLD RUSH (Services/Events)
-- per-player boosts (buffs) and event hooks, set in init
Dig.powerBoost = nil :: ((player: Player) -> number)?
Dig.findBoost = nil :: ((player: Player) -> number)?
Dig.onBroken = nil :: ((player: Player, broken: { number }, owner: Player) -> ())? -- owner = whose tunnel
Dig.onBottom = nil :: ((player: Player) -> ())?
Dig.speedBoost = nil :: ((player: Player) -> number)?
Dig.onZone = nil :: ((player: Player, zone: number) -> ())?
Dig.onCrit = nil :: ((player: Player) -> ())?
Dig.onDeeper = nil :: ((player: Player, layers: number) -> ())?
Dig.beforePunch = nil :: ((player: Player, s: State.PlayerState) -> boolean)? -- false = refused (in bed)
-- gold / jackpot broke (already paid out): missions
Dig.onGold = nil :: ((player: Player, kind: string, paid: number) -> ())?
Dig.onCombo = nil :: ((player: Player, hits: number) -> ())?
-- CREW (Services/Crew): the host whose tunnel `guest` may dig in (nil = not allowed)
Dig.crewHost = nil :: ((guest: Player, ownerId: number) -> Player?)?
-- CELLMATES (Services/Pets): XP for the equipped pets
Dig.onPetXp = nil :: ((player: Player, blocks: number) -> ())?
Dig.onBoss = nil :: ((player: Player, zone: number) -> ())? -- every player who hit a door that cracked

-- A pet perk of this player right now (Shared/Pets over the saved pets).
local function petBonus(s: State.PlayerState, perk: string): number
	local p = s.data.Pets
	return if p then Pets.bonus(p.Owned, p.Equipped, perk) else 0
end
Dig.petBonus = petBonus
Dig.onCaveIn = nil :: ((player: Player, blocks: number) -> ())?

-- multiplies punch power for everyone (events like BLACKOUT set it, M4)
Dig.globalBoost = 1

local function isInt(v: any, lo: number, hi: number): boolean
	return typeof(v) == "number" and v == v and v % 1 == 0 and v >= lo and v <= hi
end

-- ===== tunnels =====

function Dig.loadTunnel(player: Player)
	local s = State.get(player)
	if not s then
		return
	end
	s.grid = Voxel.deserialize(s.data.Tunnel, W, H, D, CS)
	s.damage = {}
	s.tunnelDirty = false
	-- (profiles from before RunDepth existed: the tunnel itself says how deep this run is)
	s.data.RunDepth = math.max(s.data.RunDepth or 0, Voxel.depth(s.grid))
end

function Dig.saveTunnel(s: State.PlayerState)
	if s.grid and s.tunnelDirty then
		s.data.Tunnel = Voxel.serialize(s.grid)
		s.tunnelDirty = false
	end
end

local lastJackpotNews = -math.huge -- os.clock() of the last server-wide jackpot message

local function damageList(s: State.PlayerState): { number }
	local out = {}
	for idx, hp in s.damage do
		local _, _, z = Voxel.unindex(s.grid, idx)
		table.insert(out, idx)
		table.insert(out, Progression.crackStage(hp, Progression.blockHp(z)))
	end
	return out
end

-- Everyone currently rendering `owner`'s tunnel.
local function watchersOf(owner: Player): { Player }
	local out = {}
	for p, vs in State.all() do
		if vs.watching[owner.UserId] then
			table.insert(out, p)
		end
	end
	return out
end

local function sendSnapshot(viewer: Player, owner: Player)
	local os_ = State.get(owner)
	if not os_ or not os_.cell or not os_.grid then
		return
	end
	Net.fire(
		viewer,
		Remotes.Names.Snapshot,
		owner.UserId,
		os_.cell,
		os_.data.Seed,
		Voxel.serialize(os_.grid),
		damageList(os_)
	)
end

-- Re-sends a tunnel to everyone watching it (after an admin reset or a big change).
function Dig.resync(owner: Player)
	for _, viewer in watchersOf(owner) do
		sendSnapshot(viewer, owner)
	end
end

-- Subscribes clients to the tunnels near them (snapshot on enter, Drop on leave).
local SUB_MARGIN = 30 -- blocks
local UNSUB_MARGIN = 42

local function updateWatching()
	for viewer, vs in State.all() do
		if vs.ready then
			local pos = State.root(viewer)
			for owner, os_ in State.all() do
				if os_.cell and os_.frame and os_.grid then
					local watching = vs.watching[owner.UserId] == true
					local near = owner == viewer
						or (
							pos ~= nil
							and Tunnel.inside(os_.frame, pos, if watching then UNSUB_MARGIN else SUB_MARGIN)
						)
					if near and not watching then
						vs.watching[owner.UserId] = true
						sendSnapshot(viewer, owner)
					elseif watching and not near then
						vs.watching[owner.UserId] = nil
						Net.fire(viewer, Remotes.Names.Drop, owner.UserId)
					end
				end
			end
		end
	end
end

-- An owner left: everyone stops rendering their tunnel.
function Dig.forget(owner: Player)
	local os_ = State.get(owner)
	if os_ then
		Dig.clearDoors(os_) -- (defined further down)
	end
	for viewer, vs in State.all() do
		if vs.watching[owner.UserId] then
			vs.watching[owner.UserId] = nil
			if viewer ~= owner then
				Net.fire(viewer, Remotes.Names.Drop, owner.UserId)
			end
		end
	end
end

-- ===== piles (loose rubble waiting for the vacuum) =====

local function addPile(s: State.PlayerState, pos: Vector3, rubble: number, value: number)
	for _, p in s.piles do
		if (p.pos - pos).Magnitude <= World.PileMergeRadius then
			p.rubble += rubble
			p.value += value
			s.loose += rubble
			return
		end
	end
	if #s.piles >= World.MaxPiles then
		local p = s.piles[#s.piles]
		p.rubble += rubble
		p.value += value
		s.loose += rubble
		return
	end
	s.pileSeq += 1
	table.insert(s.piles, { id = s.pileSeq, pos = pos, rubble = rubble, value = value })
	s.loose += rubble
end

-- ===== chambers & zones =====

local function reachZone(player: Player, s: State.PlayerState, zone: number)
	if zone <= s.data.Zone then
		return
	end
	s.data.Zone = zone
	Net.fire(player, Remotes.Names.Zone, zone)
	if Dig.onZone then
		Dig.onZone(player, zone)
	end
	Net.announce(
		string.format("%s reached the %s!", player.Name, Zones[zone].name),
		{ 255, 215, 60 },
		"Announce"
	)
	Cells.updateSign(player)
end

local function openChamber(player: Player, s: State.PlayerState, zone: number)
	local b = Progression.chamberBox(zone)
	if not b then
		return
	end
	for z = b.z0, b.z1 do
		for y = b.y0, b.y1 do
			for x = b.x0, b.x1 do
				Voxel.dig(s.grid, x, y, z)
				s.damage[Voxel.index(s.grid, x, y, z)] = nil
			end
		end
	end
	s.tunnelDirty = true
	for _, viewer in watchersOf(player) do
		Net.fire(viewer, Remotes.Names.Chamber, player.UserId, zone)
	end
	local c = Zones[zone].chamber
	if c then
		Net.notice(player, "You broke into the " .. string.upper(c.name) .. "!", "good")
	end
	s.data.RunDepth = math.max(s.data.RunDepth, b.z1 + 1)
	if b.z1 + 1 > s.data.MaxDepth then
		s.data.MaxDepth = b.z1 + 1
	end
	reachZone(player, s, zone)
end

-- ===== vault doors =====

local doorFolder: Folder? = nil
local function doorParent(): Folder
	if not doorFolder or not doorFolder.Parent then
		local f = Instance.new("Folder")
		f.Name = "VaultDoors"
		f.Parent = workspace
		doorFolder = f
	end
	return doorFolder :: Folder
end

-- The door in front of `zone`'s chamber in `owner`'s tunnel (brought out the first time).
local function bossAppear(owner: Player, ts: State.PlayerState, zone: number): any
	local b = ts.bosses[zone]
	if b then
		return b
	end
	local max = Progression.bossHp(zone)
	local c = Zones[zone] and Zones[zone].chamber
	if max <= 0 or not c or not ts.frame then
		return nil
	end
	local door = VaultDoor.build(doorParent(), ts.frame, zone)
	if door then
		VaultDoor.setHp(door, max, max)
		door.model:SetAttribute("Owner", owner.UserId)
	end
	b = { hp = max, max = max, door = door, hitters = {} }
	ts.bosses[zone] = b
	for _, viewer in watchersOf(owner) do
		Net.fire(viewer, Remotes.Names.Boss, "appear", owner.UserId, zone, max, max)
	end
	Net.notice(owner, "🔒 A VAULT DOOR seals the " .. string.upper(c.name) .. "! Punch it open!", "info")
	return b
end

-- One punch on the door (any block of the sealed chamber counts).
local function bossHit(player: Player, owner: Player, ts: State.PlayerState, zone: number, power: number)
	local b = bossAppear(owner, ts, zone)
	if not b then
		return
	end
	local dealt = math.min(power, math.max(0, b.hp))
	b.hp -= power
	b.hitters[player] = (b.hitters[player] or 0) + dealt
	if b.door then
		VaultDoor.setHp(b.door, b.hp, b.max)
	end
	for _, viewer in watchersOf(owner) do
		Net.fire(viewer, Remotes.Names.Boss, "hit", owner.UserId, zone, b.hp, b.max, player.UserId)
	end
	if b.hp > 0 then
		return
	end
	-- cracked, the chamber opens. The tunnel's owner gets the full reward; crew guests who helped
	-- get their share of the damage (so extra hitters never multiply the payout)
	ts.bosses[zone] = nil
	local reward = Progression.bossReward(zone)
	if not b.hitters[owner] then
		b.hitters[owner] = 0
	end
	for hitter, dealt in b.hitters do
		local hs = State.get(hitter)
		local share = if hitter == owner then 1 else math.clamp(dealt / math.max(1, b.max), 0, 1)
		if hs and share >= 0.05 then
			local pay = math.floor(reward * share * Loot.multiplier(hs) + 0.5)
			Loot.addNoodles(hitter, pay)
			Net.fire(hitter, Remotes.Names.Boss, "reward", owner.UserId, zone, pay)
			if Dig.onBoss then
				Dig.onBoss(hitter, zone)
			end
		end
	end
	for _, viewer in watchersOf(owner) do
		Net.fire(viewer, Remotes.Names.Boss, "dead", owner.UserId, zone, 0, b.max, player.UserId)
	end
	if zone >= 5 then
		local c = Zones[zone].chamber
		Net.announce(
			string.format(
				"💥 %s cracked the vault door of the %s!",
				player.Name,
				if c then c.name else "deep"
			),
			{ 255, 200, 90 },
			"Announce"
		)
	end
	local model = b.door and b.door.model
	if model then
		task.delay(1.6, function()
			model:Destroy()
		end)
	end
	openChamber(owner, ts, zone)
end

-- Removes every door of a tunnel (reset, escape, leaving).
local function clearDoors(ts: State.PlayerState)
	for _, b in ts.bosses do
		if b.door then
			b.door.model:Destroy()
		end
	end
	ts.bosses = {}
end
Dig.clearDoors = clearDoors

-- ===== combo =====

-- The chain's multiplier right now (1 once it ran out: vacuuming pauses the clock).
local function comboAlive(s: State.PlayerState, now: number): boolean
	-- vacuuming pauses the clock, but only for a while (holding VACUUM forever never keeps it)
	if s.vacuuming and now - s.vacuumAt <= World.ComboVacuumPause then
		return true
	end
	return now - s.comboLast <= World.ComboWindow
end

local function comboMult(s: State.PlayerState): number
	if not comboAlive(s, os.clock()) then
		return 1
	end
	return Progression.comboMult(s.comboHits)
end

-- One more punch in the chain (a new chain if the last one ran out).
local function comboHit(player: Player, s: State.PlayerState, now: number)
	if not comboAlive(s, now) then
		s.comboHits, s.comboBonus = 0, 0
	end
	s.comboHits += 1
	s.comboLast = now
	local stats = s.data.Stats
	if s.comboHits > stats.BestCombo then
		stats.BestCombo = s.comboHits
	end
	if Dig.onCombo then
		Dig.onCombo(player, s.comboHits)
	end
end

local function sendCombo(player: Player, s: State.PlayerState)
	local tier = Progression.comboTier(s.comboHits)
	local bonus = s.comboBonus * Loot.multiplier(s)
	Net.fire(player, Remotes.Names.Combo, s.comboHits, tier, math.floor(bonus + 0.5))
end

-- ===== punching =====

local punchLimit = RateLimit.new(1 / World.AttackInterval * 1.6, 6)

-- Returns a reason string when the punch is rejected (also used by the smoke test).
-- ownerId = whose tunnel (nil / your own UserId = yours; a CREW host's when you dig with them).
-- The tunnel (grid, depth, chambers) is the owner's; the punch, rubble, finds, gold and combo are
-- yours.
function Dig.punch(player: Player, x: any, y: any, z: any, face: any, ownerId: any): string?
	local s = State.get(player)
	if not s then
		return "no tunnel"
	end
	if not (isInt(x, 0, W - 1) and isInt(y, 0, H - 1) and isInt(z, 0, D - 1) and isInt(face, 1, 6)) then
		return "bad args"
	end
	local host: Player? = nil
	local ts = s
	if ownerId ~= nil and ownerId ~= player.UserId then
		if typeof(ownerId) ~= "number" or ownerId ~= ownerId then
			return "bad args"
		end
		host = if Dig.crewHost then Dig.crewHost(player, ownerId) else nil
		local hs = host and State.get(host)
		if not hs then
			return "not your crew"
		end
		ts = hs
	end
	if not ts.grid or not ts.frame then
		return "no tunnel"
	end
	local now = os.clock()
	local speed = if Dig.speedBoost then Dig.speedBoost(player) else 0
	if now - s.lastPunch < World.AttackInterval * (1 - speed) * 0.8 or not punchLimit(player) then
		return "too fast"
	end
	local grid = ts.grid
	if not Voxel.isSolid(grid, x, y, z) then
		return "not solid"
	end
	local n = Voxel.Faces[face]
	if not Voxel.isOpen(grid, x + n[1], y + n[2], z + n[3]) then
		return "not exposed"
	end
	local maxZ = Progression.diggableDepth()
	if z >= maxZ then
		Net.notice(player, "Too hard for now: new zones open soon!", "info")
		return "locked zone"
	end
	local root = State.root(player)
	if not root then
		return "no character"
	end
	local center = Tunnel.blockCenter(ts.frame, x, y, z)
	if (center - root).Magnitude > World.Reach + World.ReachSlack then
		return "out of reach"
	end
	-- (after every other check: a refused punch must not roll the cover up; a crew guest's punch
	-- in the host's tunnel leaves the guest's own cover alone)
	if s.hidden then
		return "in bed"
	end
	if host == nil and Dig.beforePunch and not Dig.beforePunch(player, s) then
		return "in bed"
	end
	-- a full backpack never stops you: the rubble just stays on the floor (worth nothing until
	-- you come back with room), and the HUD warns you
	if s.data.Bag >= Stats.capacity(s) and now - s.fullNoticeAt > 20 then
		s.fullNoticeAt = now
		Net.fire(player, Remotes.Names.Full, "bag")
	end
	s.lastPunch = now
	comboHit(player, s, now)
	local data = s.data
	s.lastHit = { x, y, z, (host or player).UserId }
	local power = Stats.power(s)
		* Dig.globalBoost
		* (if Dig.powerBoost then Dig.powerBoost(player) else 1)
		* (1 + petBonus(s, "power"))
	-- CRIT: a lucky punch hits much harder (the client pops "CRIT!" on the block)
	if math.random() < World.CritChance then
		power *= World.CritMult
		Net.fire(player, Remotes.Names.Crit, x, y, z, (host or player).UserId)
		if Dig.onCrit then
			Dig.onCrit(player)
		end
	end
	-- a sealed chamber: the punch hits its vault door (one hit, whatever the brush)
	local sealed = Progression.chamberAt(x, y, z)
	if sealed then
		data.Stats.Punches += 1
		bossHit(player, host or player, ts, sealed, power)
		sendCombo(player, s)
		return nil
	end
	local targets = Progression.brushTargets(grid, x, y, z, face, data.Levels.Brushes, function(tx, ty, tz)
		return tz < maxZ and not Progression.chamberAt(tx, ty, tz)
	end)
	data.Stats.Punches += 1
	local broken = Dig.applyHits(player, s, targets, power, host)
	sendCombo(player, s)
	-- CAVE-IN: sometimes the rock around the hole gives way too
	if broken > 0 and math.random() < Progression.caveInChance(broken) then
		Dig.caveIn(player, s, x, y, z, host)
	end
	return nil
end

-- CAVE-IN: the exposed rock within CaveInRadius of (x, y, z) comes down at once (at most
-- CaveInMax blocks, nearest first; never chambers or locked zones). Returns blocks broken.
function Dig.caveIn(
	player: Player,
	s: State.PlayerState,
	x: number,
	y: number,
	z: number,
	host: Player?
): number
	local owner = host or player
	local ts = if host then State.get(host) else s
	if not ts or not ts.grid then
		return 0
	end
	local grid = ts.grid
	local r = World.CaveInRadius
	local maxZ = Progression.diggableDepth()
	local list: { { number } } = {}
	for dz = -r, r do
		for dy = -r, r do
			for dx = -r, r do
				local d2 = dx * dx + dy * dy + dz * dz
				local tx, ty, tz = x + dx, y + dy, z + dz
				if
					d2 > 0
					and d2 <= r * r + 1
					and Voxel.inBounds(grid, tx, ty, tz)
					and tz < maxZ
					and not Progression.chamberAt(tx, ty, tz)
					and Voxel.isExposed(grid, tx, ty, tz)
				then
					table.insert(list, { tx, ty, tz, d2 })
				end
			end
		end
	end
	if #list < 3 then
		return 0 -- a pebble, not a cave-in
	end
	table.sort(list, function(a, b)
		return a[4] < b[4]
	end)
	while #list > World.CaveInMax do
		table.remove(list)
	end
	for _, viewer in watchersOf(owner) do
		Net.fire(viewer, Remotes.Names.CaveIn, owner.UserId, x, y, z, #list, player.UserId)
	end
	local n = Dig.applyHits(player, s, list, math.huge, host)
	s.data.Stats.CaveIns += 1
	if Dig.onCaveIn then
		Dig.onCaveIn(player, n)
	end
	return n
end

-- Damages / breaks a list of blocks ({x, y, z}) of a tunnel: the player's own, or a CREW host's
-- (`host`). The tunnel side (grid, depth, zone, chambers, deltas) is the owner's; rubble piles,
-- finds, gold and the combo are the puncher's. power = math.huge breaks everything (dynamite).
-- Returns blocks broken.
function Dig.applyHits(
	player: Player,
	s: State.PlayerState,
	targets: { { number } },
	power: number,
	host: Player?
): number
	local owner = host or player
	local ts = if host then State.get(host) else s
	if not ts or not ts.grid then
		return 0
	end
	local grid = ts.grid
	local data = s.data
	local seed = ts.data.Seed
	local slots = Progression.findSlots(data.Levels.FindSlots)
	local bonus = Dig.nightBonus
		+ Dig.eventBonus
		+ (if Dig.findBoost then Dig.findBoost(player) else 0)
		+ petBonus(s, "finds")
	local broken: { number } = {}
	local damaged: { number } = {}
	local sum = Vector3.zero
	local rubble, value = 0, 0
	local slotsFull = false
	local deepest = -1
	local golds: { { any } } = {}
	for _, t in targets do
		local tx, ty, tz = t[1], t[2], t[3]
		local find = Progression.findAt(seed, tx, ty, tz)
		-- (a sealed chamber only opens through its vault door)
		if not Voxel.isSolid(grid, tx, ty, tz) or Progression.chamberAt(tx, ty, tz) then
			continue
		end
		do
			local idx = Voxel.index(grid, tx, ty, tz)
			local maxHp = Progression.blockHp(tz)
			local hp = (ts.damage[idx] or maxHp) - power
			if hp <= 0 then
				Voxel.dig(grid, tx, ty, tz)
				ts.damage[idx] = nil
				table.insert(broken, idx)
				sum += Tunnel.blockCenter(ts.frame, tx, ty, tz)
				rubble += 1
				value += Zones[Progression.zoneAt(tz)].rubble
				deepest = math.max(deepest, tz)
				local gold = if find then nil else Progression.goldAt(seed, tx, ty, tz)
				if gold then
					table.insert(golds, { tx, ty, tz, gold })
				end
				if not find and not gold and bonus > 0 and #data.Finds < slots then
					local zone = Progression.zoneAt(tz)
					if math.random() < Zones[zone].oreChance * bonus then
						find = Progression.pickFind(zone, math.random())
					end
				end
				if find and #data.Finds >= slots then
					-- slots full: it goes to your Stash chest if there's room, else it's lost
					slotsFull = true
					if #data.Stash < PvP.StashSize then
						local firstTime = not data.Found[find]
						table.insert(data.Stash, find)
						data.Found[find] = true
						data.Stats.FindsDug += 1
						Net.fire(player, Remotes.Names.Stash, data.Stash)
						Net.notice(player, "Find slots full: sent to your Stash chest 📦", "info")
						if Dig.onFind then
							Dig.onFind(player, find, firstTime)
						end
					else
						Net.notice(player, "Find slots AND Stash full: that find crumbled to dust!", "bad")
					end
					find = nil
				end
				if find then
					local firstTime = not data.Found[find]
					table.insert(data.Finds, find)
					data.Found[find] = true
					data.Stats.FindsDug += 1
					Net.fire(player, Remotes.Names.Found, find)
					if Dig.onFind then
						Dig.onFind(player, find, firstTime)
					end
				end
			else
				ts.damage[idx] = hp
				table.insert(damaged, idx)
				table.insert(damaged, Progression.crackStage(hp, maxHp))
			end
		end
	end
	if slotsFull then
		Net.fire(player, Remotes.Names.Full, "slots")
	end
	if #broken > 0 then
		data.Stats.Blocks += #broken
		ts.tunnelDirty = true
		-- the combo multiplies what this rubble is worth (the extra shows in the combo counter)
		local mult = comboMult(s)
		s.comboBonus += value * (mult - 1)
		addPile(s, sum / #broken, rubble, value * mult)
		-- chambers: breaking a block next to a sealed chamber opens the whole room
		local opened: { [number]: boolean } = {}
		for _, idx in broken do
			local bx, by, bz = Voxel.unindex(grid, idx)
			for _, f in Voxel.Faces do
				local cx, cy, cz = bx + f[1], by + f[2], bz + f[3]
				local zone = Progression.chamberAt(cx, cy, cz)
				if zone and not opened[zone] and Voxel.isSolid(grid, cx, cy, cz) then
					opened[zone] = true
				end
			end
		end
		local td = ts.data
		-- deeper than ever in this run (jobs count it again after an escape); MaxDepth is the record
		if deepest + 1 > td.RunDepth then
			if Dig.onDeeper then
				Dig.onDeeper(owner, deepest + 1 - td.RunDepth)
			end
			td.RunDepth = deepest + 1
			td.MaxDepth = math.max(td.MaxDepth, td.RunDepth)
			Cells.updateSign(owner)
		end
		reachZone(owner, ts, Progression.zoneAt(deepest))
		for _, viewer in watchersOf(owner) do
			Net.fire(viewer, Remotes.Names.Delta, owner.UserId, broken, damaged, player.UserId)
		end
		for zone in opened do
			bossAppear(owner, ts, zone)
		end
		if Dig.onPiles then
			Dig.onPiles(player)
		end
		if Dig.onBroken then
			Dig.onBroken(player, broken, owner)
		end
		if Dig.onPetXp then
			Dig.onPetXp(player, #broken)
		end
		if deepest >= D - 1 and Dig.onBottom then
			Dig.onBottom(owner)
		end
		-- GOLD: paid on the spot (after the delta, so the block is gone when the coins fly)
		for _, g in golds do
			local gx, gy, gz, kind = g[1], g[2], g[3], g[4]
			local worth = Progression.goldBlocks(kind) * Zones[Progression.zoneAt(gz)].rubble
			local paid = math.floor(worth * Loot.multiplier(s) * (1 + petBonus(s, "gold")) + 0.5)
			Loot.addNoodles(player, paid)
			if Dig.onGold then
				Dig.onGold(player, kind, paid)
			end
			if kind == "jackpot" then
				data.Stats.Jackpots += 1
				-- (server-wide at most once a minute: deep diggers would spam it)
				if os.clock() - lastJackpotNews >= 60 then
					lastJackpotNews = os.clock()
					Net.announce(
						string.format(
							"💎 %s hit a JACKPOT VEIN! +%s Noodles",
							player.Name,
							Format.number(paid)
						),
						{ 120, 230, 255 },
						"Rare"
					)
				end
			else
				data.Stats.Gold += 1
			end
			for _, viewer in watchersOf(owner) do
				Net.fire(viewer, Remotes.Names.Gold, owner.UserId, gx, gy, gz, kind, paid, player.UserId)
			end
		end
	elseif #damaged > 0 then
		for _, viewer in watchersOf(owner) do
			Net.fire(viewer, Remotes.Names.Delta, owner.UserId, broken, damaged, player.UserId)
		end
	end
	Stats.sync(player)
	return #broken
end

-- DYNAMITE: blows up a sphere of blocks around the aimed block (needs a stick).
function Dig.dynamite(player: Player, x: any, y: any, z: any): string?
	local s = State.get(player)
	if not s or not s.grid or not s.frame then
		return "no tunnel"
	end
	if not (isInt(x, 0, W - 1) and isInt(y, 0, H - 1) and isInt(z, 0, D - 1)) then
		return "bad args"
	end
	if s.data.Dynamite <= 0 then
		return "no dynamite"
	end
	local root = State.root(player)
	if
		not root
		or (Tunnel.blockCenter(s.frame, x, y, z) - root).Magnitude > World.Reach + World.ReachSlack + 4
	then
		return "out of reach"
	end
	if not Voxel.isExposed(s.grid, x, y, z) then
		return "not exposed"
	end
	if Dig.beforePunch and not Dig.beforePunch(player, s) then
		return "in bed"
	end
	s.data.Dynamite -= 1
	local r = Products.DynamiteRadius
	local maxZ = Progression.diggableDepth()
	local targets = {}
	for dz = -r, r do
		for dy = -r, r do
			for dx = -r, r do
				if dx * dx + dy * dy + dz * dz <= r * r + 1 then
					local tx, ty, tz = x + dx, y + dy, z + dz
					if
						Voxel.inBounds(s.grid, tx, ty, tz)
						and tz < maxZ
						and not Progression.chamberAt(tx, ty, tz)
					then
						table.insert(targets, { tx, ty, tz })
					end
				end
			end
		end
	end
	for _, viewer in watchersOf(player) do
		Net.fire(viewer, Remotes.Names.Boom, player.UserId, x, y, z)
	end
	Dig.applyHits(player, s, targets, math.huge)
	if typeof(player) == "Instance" then
		player:SetAttribute("Dynamite", s.data.Dynamite)
	end
	return nil
end

-- Admin / stress: dig a box without rewards (inclusive coordinates, clamped to the grid).
function Dig.digBox(player: Player, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number)
	local s = State.get(player)
	if not s or not s.grid then
		return
	end
	for z = math.max(0, z0), math.min(D - 1, z1) do
		for y = math.max(0, y0), math.min(H - 1, y1) do
			for x = math.max(0, x0), math.min(W - 1, x1) do
				Voxel.dig(s.grid, x, y, z)
			end
		end
	end
	s.damage = {}
	s.tunnelDirty = true
	local depth = Voxel.depth(s.grid)
	s.data.RunDepth = math.max(s.data.RunDepth, depth)
	s.data.MaxDepth = math.max(s.data.MaxDepth, depth)
	reachZone(player, s, Progression.zoneAt(math.max(0, depth - 1)))
	Dig.resync(player)
end

function Dig.resetTunnel(player: Player)
	local s = State.get(player)
	if not s then
		return
	end
	clearDoors(s)
	s.grid = Voxel.new(W, H, D, CS)
	s.damage = {}
	s.piles = {}
	s.loose = 0
	s.data.Tunnel = ""
	s.data.Zone = 1
	s.data.RunDepth = 0
	s.tunnelDirty = false
	Dig.resync(player)
	if Dig.onPiles then
		Dig.onPiles(player)
	end
	Cells.updateSign(player)
	Stats.sync(player)
end

function Dig.start()
	Net.on(Remotes.Names.Punch, function(player, x, y, z, face, ownerId)
		Dig.punch(player, x, y, z, face, ownerId)
	end)
	local boomLimit = RateLimit.new(0.5, 2)
	Net.on(Remotes.Names.Dynamite, function(player, x, y, z)
		if boomLimit(player) then
			Dig.dynamite(player, x, y, z)
		end
	end)
	local readyLimit = RateLimit.new(0.2, 2)
	Net.on(Remotes.Names.Ready, function(player)
		local s = State.get(player)
		if s and readyLimit(player) then
			s.ready = true
			s.watching = {}
			updateWatching()
		end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				task.wait(0.5)
				updateWatching()
			end)
			if not ok then
				warn("[Dig] loop:", err)
				task.wait(1)
			end
		end
	end)
	-- save tunnels into the profile now and then (ProfileStore writes the profile on its own)
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				task.wait(15)
				for _, s in State.all() do
					Dig.saveTunnel(s)
				end
			end)
			if not ok then
				warn("[Dig] loop:", err)
				task.wait(1)
			end
		end
	end)
end

-- exposed for the smoke test and the pets
Dig._updateWatching = updateWatching
Dig.watchersOf = watchersOf

return Dig
