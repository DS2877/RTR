--!strict
-- ESCAPE (rebirth): when you break through the last layer of zone 10 the ESCAPE button appears.
-- Escaping plays the cinematic (searchlights, sprint over the wall), then you get caught and land
-- in a tougher prison: Rebirths + 1 (permanent multiplier). Your tunnel, Noodles, strength and
-- tools reset; your depth record, collection, defenses and decor items are kept. Every escape
-- earns FREEDOM POINTS for the LIFER'S LOCKER (Services/Locker): its perks are kept forever and
-- change what you start the next run with (Head Start, Muscle Memory).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Extras = require(Shared.Config.Extras)
local World = require(Shared.Config.World)
local Voxel = require(Shared.Voxel)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Stats = require(script.Parent.Stats)
local Dig = require(script.Parent.Dig)
local Cells = require(script.Parent.Cells)
local Breakout = require(script.Parent.Breakout)
local Raid = require(script.Parent.Raid)
local Gym = require(script.Parent.Gym)
local Locker = require(script.Parent.Locker)

local Escape = {}

Escape.onEscaped = nil :: ((player: Player) -> ())?

function Escape.prisonName(rebirths: number): string
	local p = Economy.Prisons[math.min(rebirths + 1, #Economy.Prisons)]
	local extra = rebirths + 1 - #Economy.Prisons
	return if extra > 0 then p.name .. " +" .. extra else p.name
end

function Escape.ready(player: Player)
	local s = State.get(player)
	if not s or s.escapeReady then
		return
	end
	s.escapeReady = true
	if typeof(player) == "Instance" then
		player:SetAttribute("CanEscape", true)
	end
	Net.fire(player, Remotes.Names.EscapeReady)
	Net.notice(player, "You see daylight! Tap ESCAPE!", "good")
end

-- Returns a reason when the escape is refused (also used by the smoke test).
function Escape.escape(player: Player): string?
	local s = State.get(player)
	if not s or not s.grid then
		return "no state"
	end
	if not s.escapeReady or Voxel.depth(s.grid) < World.TunnelDepth then
		return "not at the bottom"
	end
	-- a stolen find never rides along into the next prison
	Raid.returnCarry(player, "escaped")
	Gym.stop(player)
	local d = s.data
	-- Freedom Points first (the run's time ends now), then the reset
	Locker.onEscape(player)
	d.Rebirths += 1
	table.insert(d.Escapes, os.time())
	d.Noodles = 0
	d.Strength = Locker.strengthAfterEscape(s)
	for _, track in { "Tools", "Brushes", "Backpack", "FindSlots", "Vacuum", "Cart" } do
		(d.Levels :: any)[track] = 1
	end
	Locker.applyHeadStart(s)
	d.Bag, d.BagValue = 0, 0
	d.Finds, d.Stash = {}, {}
	-- placed decor goes back into your decor box
	for _, p in d.Placed do
		local item = Extras.Decor[p[1]]
		if item then
			d.Decor[item.id] = (d.Decor[item.id] or 0) + 1
		end
	end
	d.Placed = {}
	s.escapeReady = false
	if typeof(player) == "Instance" then
		player:SetAttribute("CanEscape", false)
		player:SetAttribute("Rebirths", d.Rebirths)
	end
	-- a new prison, a new rock: finds, gold and jackpots sit somewhere else
	d.Seed = Random.new():NextInteger(1, 2 ^ 31 - 1)
	Dig.resetTunnel(player)
	-- the rebirth is done (leaving mid-run never loses it): now run for it. THE BREAKOUT ends at
	-- the getaway car and brings you to your new cell (Services/Breakout).
	local name = Escape.prisonName(d.Rebirths)
	if not Breakout.begin(player, false, d.Rebirths, name) then
		-- no run (shouldn't happen): the points card shows now
		Locker.onBreakout(player, "")
		if typeof(player) == "Instance" then
			task.spawn(Cells.toCell, player)
			Net.fire(player, Remotes.Names.Escaped, d.Rebirths, name)
		end
	end
	Net.announce(
		string.format("🚨 %s broke through! THE BREAKOUT is on!", player.Name),
		{ 255, 120, 80 },
		"Announce"
	)
	Cells.updateSign(player)
	Stats.sync(player)
	Net.fire(player, Remotes.Names.Finds, d.Finds)
	if Escape.onEscaped then
		Escape.onEscaped(player)
	end
	return nil
end

function Escape.start()
	Dig.onBottom = Escape.ready
	local limit = RateLimit.new(0.2, 2)
	Net.on(Remotes.Names.Escape, function(player)
		if limit(player) then
			Escape.escape(player)
		end
	end)
end

-- On join: someone who already reached the bottom can escape right away.
function Escape.check(player: Player)
	local s = State.get(player)
	if s and s.grid and Voxel.depth(s.grid) >= World.TunnelDepth then
		Escape.ready(player)
	end
	if s and typeof(player) == "Instance" then
		player:SetAttribute("Rebirths", s.data.Rebirths)
	end
end

return Escape
