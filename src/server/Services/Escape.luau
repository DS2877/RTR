--!strict
-- ESCAPE (rebirth): when you break through the last layer of zone 10 the ESCAPE button appears.
-- Escaping plays the cinematic (searchlights, sprint over the wall), then you get caught and land
-- in a tougher prison: Rebirths + 1 (permanent multiplier). Your tunnel, Noodles, strength and
-- tools reset; your depth record, collection, defenses and decor items are kept.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local World = require(Shared.Config.World)
local Voxel = require(Shared.Voxel)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Stats = require(script.Parent.Stats)
local Dig = require(script.Parent.Dig)
local Cells = require(script.Parent.Cells)

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
	local d = s.data
	d.Rebirths += 1
	table.insert(d.Escapes, os.time())
	d.Noodles = 0
	d.Strength = Economy.StartingStrength
	for _, track in { "Tools", "Brushes", "Backpack", "FindSlots", "Vacuum" } do
		(d.Levels :: any)[track] = 1
	end
	d.Bag, d.BagValue = 0, 0
	d.Finds, d.Stash = {}, {}
	-- placed decor goes back into your decor box
	for _, p in d.Placed do
		local kind = tostring(p[1])
		d.Decor[kind] = (d.Decor[kind] or 0) + 1
	end
	d.Placed = {}
	s.escapeReady = false
	if typeof(player) == "Instance" then
		player:SetAttribute("CanEscape", false)
		player:SetAttribute("Rebirths", d.Rebirths)
	end
	Dig.resetTunnel(player)
	local name = Escape.prisonName(d.Rebirths)
	Net.fire(player, Remotes.Names.Escaped, d.Rebirths, name)
	Net.announce(
		string.format("%s ESCAPED! ...and got caught. Welcome to %s!", player.Name, name),
		{ 255, 215, 60 },
		"Zone"
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
