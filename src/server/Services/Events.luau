--!strict
-- Server events (Config/Cycle.Events), random every EventMin..EventMax seconds or by admin:
--   BLACKOUT        all walls 2x weaker
--   RIOT            (night) the doors stay open
--   INSPECTION DAY  (day) be in your own cell with an empty backpack when it ends: bonus Noodles
--   TREASURE RACE   a mega find at the same depth in every tunnel: the first to dig to it wins

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cycle = require(Shared.Config.Cycle)
local World = require(Shared.Config.World)
local Zones = require(Shared.Config.Zones)
local Finds = require(Shared.Config.Finds)
local Voxel = require(Shared.Voxel)
local Progression = require(Shared.Progression)
local Tunnel = require(Shared.Tunnel)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local Dig = require(script.Parent.Dig)
local Loot = require(script.Parent.Loot)

local Events = {}

Events.phase = function(): string
	return "Day"
end
Events.onRiot = nil :: ((on: boolean) -> ())?

local current: string? = nil
local endsAt = 0
local treasure: { [any]: number } = {} -- player -> block index of their treasure

function Events.current(): string?
	return current
end

function Events.riot(): boolean
	return current == "RIOT"
end

local function finish()
	local id = current
	if not id then
		return
	end
	current = nil
	Dig.globalBoost = 1
	if id == "RIOT" and Events.onRiot then
		Events.onRiot(false)
	end
	ReplicatedStorage:SetAttribute("Event", "")
	Remotes.get(Remotes.Names.Event):FireAllClients("", 0)
	if id == "INSPECTION" then
		local blocks = Cycle.InspectionDayBlocks
		for player, s in State.all() do
			local pos = State.root(player)
			if pos and s.cell and Tunnel.cellAt(pos) == s.cell and s.data.Bag == 0 then
				local amount = blocks * Zones[math.clamp(s.data.Zone, 1, #Zones)].rubble
				Loot.addNoodles(player, amount)
				Net.notice(player, "Tidy cell bonus! +" .. Format.noodles(amount), "cash")
			end
		end
	elseif id == "TREASURE" then
		for player in treasure do
			Net.fire(player, Remotes.Names.Treasure, nil)
		end
		treasure = {}
	end
end

-- The treasure block in this player's tunnel: the first solid block at depth >= target.
local function placeTreasure(player: Player, s: State.PlayerState, depth: number)
	local g = s.grid
	if not g then
		return
	end
	local mid = World.TunnelWidth // 2
	for z = depth, Progression.diggableDepth() - 1 do
		if not Progression.chamberAt(mid, 1, z) and Voxel.isSolid(g, mid, 1, z) then
			treasure[player] = Voxel.index(g, mid, 1, z)
			Net.fire(player, Remotes.Names.Treasure, mid, 1, z)
			return
		end
	end
end

-- Starts an event now. Returns false if the id is unknown or another event runs.
function Events.trigger(id: string): boolean
	local cfg = Cycle.Events[id]
	if not cfg or current then
		return false
	end
	current = id
	endsAt = os.clock() + cfg.seconds
	ReplicatedStorage:SetAttribute("Event", id)
	ReplicatedStorage:SetAttribute("EventEnds", workspace:GetServerTimeNow() + cfg.seconds)
	Remotes.get(Remotes.Names.Event):FireAllClients(id, cfg.seconds)
	Net.announce(cfg.name .. "! " .. cfg.text, { 255, 120, 60 }, "Siren")
	if id == "BLACKOUT" then
		Dig.globalBoost = 2
	elseif id == "RIOT" then
		if Events.onRiot then
			Events.onRiot(true)
		end
	elseif id == "TREASURE" then
		-- a few layers past the median depth of everyone here
		local depths = {}
		for _, s in State.all() do
			table.insert(depths, s.data.MaxDepth)
		end
		table.sort(depths)
		local median = depths[math.max(1, #depths // 2)] or 0
		local target = math.clamp(median + 6, 3, Progression.diggableDepth() - 1)
		for player, s in State.all() do
			placeTreasure(player, s, target)
		end
	end
	return true
end

function Events.stop()
	finish()
end

-- Dig hook: did someone break their treasure?
function Events.onBroken(player: Player, broken: { number })
	local idx = treasure[player]
	if current ~= "TREASURE" or not idx or not table.find(broken, idx) then
		return
	end
	local s = State.get(player)
	if not s then
		return
	end
	local zone = math.clamp(s.data.Zone, 1, #Zones)
	local amount = Cycle.TreasureBlocks * Zones[zone].rubble
	Loot.addNoodles(player, amount)
	-- the best find of your zone, straight into your Stash (known prize: shown in the event text)
	local best: string? = nil
	local bestValue = -1
	for _, f in Finds.ByZone[zone] or {} do
		if f.value > bestValue then
			best, bestValue = f.id, f.value
		end
	end
	if best then
		table.insert(s.data.Stash, best)
		s.data.Found[best] = true
		Net.fire(player, Remotes.Names.Stash, s.data.Stash)
	end
	Net.announce(
		string.format("%s won the TREASURE RACE! +%s", player.Name, Format.noodles(amount)),
		{ 255, 215, 60 },
		"Zone"
	)
	finish()
end

function Events.startService()
	Dig.onBroken = Events.onBroken
	task.spawn(function()
		local nextAt = os.clock() + math.random(Cycle.EventMin, Cycle.EventMax)
		while true do
			task.wait(1)
			if current and os.clock() >= endsAt then
				finish()
			end
			if not current and os.clock() >= nextAt then
				nextAt = os.clock() + math.random(Cycle.EventMin, Cycle.EventMax)
				local phase = Events.phase()
				local pool = if phase == "Night"
					then { "BLACKOUT", "RIOT", "TREASURE" }
					else { "BLACKOUT", "INSPECTION", "TREASURE" }
				Events.trigger(pool[math.random(1, #pool)])
			end
		end
	end)
end

-- (smoke test) the block index of this player's treasure, if any
function Events.treasureOf(player: Player): number?
	return treasure[player]
end

function Events.onLeaving(player: Player)
	treasure[player] = nil
end

return Events
