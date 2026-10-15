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

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Stats = require(script.Parent.Stats)
local Cells = require(script.Parent.Cells)

local Dig = {}

local W, H, D, CS = World.TunnelWidth, World.TunnelHeight, World.TunnelDepth, World.ChunkSize

-- hooks other services plug into (set in init) so Dig doesn't require them
Dig.onPiles = nil :: ((player: Player) -> ())?
Dig.onFind = nil :: ((player: Player, id: string, firstTime: boolean) -> ())?

-- night digging: share of extra finds hidden in plain blocks (DayNight sets it)
Dig.nightBonus = 0
-- per-player boosts (buffs) and event hooks, set in init
Dig.powerBoost = nil :: ((player: Player) -> number)?
Dig.findBoost = nil :: ((player: Player) -> number)?
Dig.onBroken = nil :: ((player: Player, broken: { number }) -> ())?
Dig.onBottom = nil :: ((player: Player) -> ())?
Dig.speedBoost = nil :: ((player: Player) -> number)?
Dig.onZone = nil :: ((player: Player, zone: number) -> ())?

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
end

function Dig.saveTunnel(s: State.PlayerState)
	if s.grid and s.tunnelDirty then
		s.data.Tunnel = Voxel.serialize(s.grid)
		s.tunnelDirty = false
	end
end

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
	if b.z1 + 1 > s.data.MaxDepth then
		s.data.MaxDepth = b.z1 + 1
	end
	reachZone(player, s, zone)
end

-- ===== punching =====

local punchLimit = RateLimit.new(1 / World.AttackInterval * 1.6, 6)

-- Returns a reason string when the punch is rejected (also used by the smoke test).
function Dig.punch(player: Player, x: any, y: any, z: any, face: any): string?
	local s = State.get(player)
	if not s or not s.grid or not s.frame then
		return "no tunnel"
	end
	if not (isInt(x, 0, W - 1) and isInt(y, 0, H - 1) and isInt(z, 0, D - 1) and isInt(face, 1, 6)) then
		return "bad args"
	end
	local now = os.clock()
	local speed = if Dig.speedBoost then Dig.speedBoost(player) else 0
	if now - s.lastPunch < World.AttackInterval * (1 - speed) * 0.8 or not punchLimit(player) then
		return "too fast"
	end
	local grid = s.grid
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
	local center = Tunnel.blockCenter(s.frame, x, y, z)
	if (center - root).Magnitude > World.Reach + World.ReachSlack then
		return "out of reach"
	end
	local cap = Stats.capacity(s)
	if s.data.Bag >= cap then
		Net.fire(player, Remotes.Names.Full, "bag")
		return "bag full"
	end
	if s.data.Bag + s.loose >= cap then
		Net.fire(player, Remotes.Names.Full, "loose")
		return "vacuum first"
	end
	s.lastPunch = now
	local data = s.data
	local power = Stats.power(s) * Dig.globalBoost * (if Dig.powerBoost then Dig.powerBoost(player) else 1)
	local targets = Progression.brushTargets(grid, x, y, z, face, data.Levels.Brushes, function(_, _, tz)
		return tz < maxZ
	end)
	data.Stats.Punches += 1
	Dig.applyHits(player, s, targets, power)
	return nil
end

-- Damages / breaks a list of blocks ({x, y, z}) of the player's own tunnel: rubble piles, finds,
-- chambers, zones, deltas. power = math.huge breaks everything (dynamite). Returns blocks broken.
function Dig.applyHits(player: Player, s: State.PlayerState, targets: { { number } }, power: number): number
	local grid = s.grid
	local data = s.data
	local slots = Progression.findSlots(data.Levels.FindSlots)
	local bonus = Dig.nightBonus + (if Dig.findBoost then Dig.findBoost(player) else 0)
	local broken: { number } = {}
	local damaged: { number } = {}
	local sum = Vector3.zero
	local rubble, value = 0, 0
	local slotsFull = false
	local deepest = -1
	for _, t in targets do
		local tx, ty, tz = t[1], t[2], t[3]
		local find = Progression.findAt(data.Seed, tx, ty, tz)
		if not Voxel.isSolid(grid, tx, ty, tz) then
			continue
		end
		if find and #data.Finds >= slots then
			slotsFull = true
		else
			local idx = Voxel.index(grid, tx, ty, tz)
			local maxHp = Progression.blockHp(tz)
			local hp = (s.damage[idx] or maxHp) - power
			if hp <= 0 then
				Voxel.dig(grid, tx, ty, tz)
				s.damage[idx] = nil
				table.insert(broken, idx)
				sum += Tunnel.blockCenter(s.frame, tx, ty, tz)
				rubble += 1
				value += Zones[Progression.zoneAt(tz)].rubble
				deepest = math.max(deepest, tz)
				if not find and bonus > 0 and #data.Finds < slots then
					local zone = Progression.zoneAt(tz)
					if math.random() < Zones[zone].oreChance * bonus then
						find = Progression.pickFind(zone, math.random())
					end
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
				s.damage[idx] = hp
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
		s.tunnelDirty = true
		addPile(s, sum / #broken, rubble, value)
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
		if deepest + 1 > data.MaxDepth then
			data.MaxDepth = deepest + 1
			Cells.updateSign(player)
		end
		reachZone(player, s, Progression.zoneAt(deepest))
		for _, viewer in watchersOf(player) do
			Net.fire(viewer, Remotes.Names.Delta, player.UserId, broken, damaged, player.UserId)
		end
		for zone in opened do
			openChamber(player, s, zone)
		end
		if Dig.onPiles then
			Dig.onPiles(player)
		end
		if Dig.onBroken then
			Dig.onBroken(player, broken)
		end
		if deepest >= D - 1 and Dig.onBottom then
			Dig.onBottom(player)
		end
	elseif #damaged > 0 then
		for _, viewer in watchersOf(player) do
			Net.fire(viewer, Remotes.Names.Delta, player.UserId, broken, damaged, player.UserId)
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
	s.data.MaxDepth = math.max(s.data.MaxDepth, depth)
	reachZone(player, s, Progression.zoneAt(math.max(0, depth - 1)))
	Dig.resync(player)
end

function Dig.resetTunnel(player: Player)
	local s = State.get(player)
	if not s then
		return
	end
	s.grid = Voxel.new(W, H, D, CS)
	s.damage = {}
	s.piles = {}
	s.loose = 0
	s.data.Tunnel = ""
	s.data.Zone = 1
	s.tunnelDirty = false
	Dig.resync(player)
	if Dig.onPiles then
		Dig.onPiles(player)
	end
	Cells.updateSign(player)
	Stats.sync(player)
end

function Dig.start()
	Net.on(Remotes.Names.Punch, function(player, x, y, z, face)
		Dig.punch(player, x, y, z, face)
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
			task.wait(0.5)
			updateWatching()
		end
	end)
	-- save tunnels into the profile now and then (ProfileStore writes the profile on its own)
	task.spawn(function()
		while true do
			task.wait(15)
			for _, s in State.all() do
				Dig.saveTunnel(s)
			end
		end
	end)
end

-- exposed for the smoke test
Dig._updateWatching = updateWatching

return Dig
