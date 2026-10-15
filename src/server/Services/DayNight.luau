--!strict
-- Server-wide day/night cycle (Config/Cycle). Day: cell doors open. LIGHTS OUT: siren + PA with a
-- countdown. Night: everyone outside their own cell/tunnel is walked back in, doors lock, digging
-- gives bonus finds. Phase + end time are ReplicatedStorage attributes ("Phase", "PhaseEnds").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cycle = require(Shared.Config.Cycle)
local World = require(Shared.Config.World)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local Cells = require(script.Parent.Cells)
local Dig = require(script.Parent.Dig)

local DayNight = {}

local world: any = nil
local phase = "Day"
local endsAt = 0
local forced: string? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

function DayNight.phase(): string
	return phase
end

-- Is a position inside this cell's room or its tunnel?
function DayNight.inOwnCell(s: State.PlayerState, pos: Vector3): boolean
	local frame = s.frame
	if not frame then
		return false
	end
	local p = frame:PointToObjectSpace(pos)
	local halfW = World.TunnelWidth * World.BlockSize / 2
	if math.abs(p.X) <= halfW and p.Z >= -1 and p.Z <= World.CellDepth - 2 then
		return true -- the cell room (local +Z is toward the corridor)
	end
	return p.Z < 0 and math.abs(p.X) <= halfW
end

local function setDoors(locked: boolean)
	for _, cell in world.cells do
		local door = cell.door :: Model?
		local block = cell.doorBlock :: BasePart?
		if door then
			-- bars slide across the doorway when locked
			door:PivotTo(if locked then cell.doorClosed else cell.doorOpen)
		end
		if block then
			block.CanCollide = locked
		end
	end
end

local function sendEveryoneHome()
	for player, s in State.all() do
		local pos = State.root(player)
		if pos and not DayNight.inOwnCell(s, pos) then
			Cells.toCell(player)
			Net.notice(player, "The guards walked you back to your cell.", "info")
		end
	end
end

local function setPhase(p: string, seconds: number)
	phase = p
	endsAt = now() + seconds
	ReplicatedStorage:SetAttribute("Phase", p)
	ReplicatedStorage:SetAttribute("PhaseEnds", endsAt)
	Dig.nightBonus = if p == "Night" then Cycle.NightFindBonus else 0
	if p == "LightsOut" then
		Net.announce(
			"LIGHTS OUT in " .. Cycle.LightsOutWarning .. " seconds! Back to your cells!",
			{ 255, 90, 90 },
			"Siren"
		)
	elseif p == "Night" then
		sendEveryoneHome()
		setDoors(true)
		Net.announce("Doors locked. Night digging gives +25% finds!", { 140, 170, 255 }, nil)
	else
		setDoors(false)
		Net.announce("Good morning! Cell doors are open.", { 255, 220, 120 }, "Announce")
	end
end

-- Admin: jump to "day" or "night" right now (the cycle continues from there).
function DayNight.force(p: string)
	forced = p
end

function DayNight.start(w: any)
	world = w
	setPhase("Day", Cycle.DaySeconds)
	task.spawn(function()
		while true do
			task.wait(0.25)
			if forced then
				local f = forced
				forced = nil
				if f == "night" then
					setPhase("Night", Cycle.NightSeconds)
				else
					setPhase("Day", Cycle.DaySeconds)
				end
			elseif now() >= endsAt then
				if phase == "Day" then
					setPhase("LightsOut", Cycle.LightsOutWarning)
				elseif phase == "LightsOut" then
					setPhase("Night", Cycle.NightSeconds)
				else
					setPhase("Day", Cycle.DaySeconds)
				end
			elseif phase == "Night" then
				-- nobody wanders the halls at night
				sendEveryoneHome()
			end
		end
	end)
end

return DayNight
