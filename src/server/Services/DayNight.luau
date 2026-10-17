--!strict
-- The prison schedule (Config/Cycle.Schedule) that runs the server:
--   ROLL CALL (RollCall): doors open; whoever is in their own cell when it ends is counted (bonus).
--   YARD TIME (Day): doors open, shops, fights and raids.
--   LIGHTS OUT (LightsOut): siren + PA countdown.
--   LOCKDOWN (Night): everyone is walked back to their cell, doors lock, digging gives bonus finds.
-- Phase + start + end are ReplicatedStorage attributes ("Phase", "PhaseStart", "PhaseEnds"); the
-- clients drive the sky (prison time) and the schedule widget from them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cycle = require(Shared.Config.Cycle)
local Tunnel = require(Shared.Tunnel)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local Cells = require(script.Parent.Cells)
local Dig = require(script.Parent.Dig)
local Breakout = require(script.Parent.Breakout)

local DayNight = {}

local world: any = nil
local phase = "Day"
local endsAt = 0
local forced: string? = nil

DayNight.onDay = nil :: (() -> ())?
DayNight.onPhase = nil :: ((phase: string) -> ())?
DayNight.onCounted = nil :: ((player: Player) -> ())? -- in your cell when roll call ended
DayNight.riot = function(): boolean
	return false
end

local function now(): number
	return workspace:GetServerTimeNow()
end

function DayNight.phase(): string
	return phase
end

-- Is a position inside this player's cell room or tunnel?
function DayNight.inOwnCell(s: State.PlayerState, pos: Vector3): boolean
	return s.cell ~= nil and Tunnel.cellAt(pos) == s.cell
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
		if pos and not DayNight.inOwnCell(s, pos) and not Breakout.running(player) then
			Cells.toCell(player)
			Net.notice(player, "The guards walked you back to your cell.", "info")
		end
	end
end

local SECONDS = {
	RollCall = Cycle.RollCallSeconds,
	Day = Cycle.DaySeconds,
	LightsOut = Cycle.LightsOutWarning,
	Night = Cycle.NightSeconds,
}
local NEXT = { RollCall = "Day", Day = "LightsOut", LightsOut = "Night", Night = "RollCall" }

local function countHeads()
	for player, s in State.all() do
		local pos = State.root(player)
		if pos and DayNight.inOwnCell(s, pos) then
			if DayNight.onCounted then
				DayNight.onCounted(player)
			end
		elseif pos and typeof(player) == "Instance" then
			Net.notice(player, "You missed roll call. The guard wrote 'probably fine'.", "info")
		end
	end
end

local function setPhase(p: string, seconds: number?)
	if phase == "RollCall" and p ~= "RollCall" then
		countHeads()
	end
	phase = p
	local t = now()
	endsAt = t + (seconds or SECONDS[p] or Cycle.DaySeconds)
	ReplicatedStorage:SetAttribute("Phase", p)
	ReplicatedStorage:SetAttribute("PhaseStart", t)
	ReplicatedStorage:SetAttribute("PhaseEnds", endsAt)
	Dig.nightBonus = if p == "Night" then Cycle.NightFindBonus else 0
	if DayNight.onPhase then
		DayNight.onPhase(p)
	end
	if p == "LightsOut" then
		Net.announce(
			"LIGHTS OUT in " .. Cycle.LightsOutWarning .. " seconds! Back to your cells!",
			{ 255, 90, 90 },
			"Siren"
		)
	elseif p == "Night" then
		if not DayNight.riot() then
			sendEveryoneHome()
			setDoors(true)
		end
		Net.announce(
			string.format(
				"LOCKDOWN. Doors locked. Night digging: +%d%% finds!",
				math.floor(Cycle.NightFindBonus * 100 + 0.5)
			),
			{ 140, 170, 255 },
			nil
		)
	elseif p == "RollCall" then
		setDoors(false)
		Net.announce("ROLL CALL! Stay in your cell to be counted.", { 255, 220, 120 }, "Announce")
	else
		setDoors(false)
		Net.announce("YARD TIME! Doors open. Watch your Stash!", { 255, 220, 120 }, "Announce")
		if DayNight.onDay then
			DayNight.onDay()
		end
	end
end

-- RIOT event: doors open now (on) / lock again if it's still night (off).
function DayNight.setRiot(on: boolean)
	if on then
		setDoors(false)
	elseif phase == "Night" then
		sendEveryoneHome()
		setDoors(true)
	end
end

-- Admin: jump to "day" or "night" right now (the cycle continues from there).
function DayNight.force(p: string)
	forced = p
end

function DayNight.start(w: any)
	world = w
	setPhase("Day")
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				task.wait(0.25)
				if forced then
					local f = forced
					forced = nil
					setPhase(if f == "night" then "Night" elseif f == "rollcall" then "RollCall" else "Day")
				elseif now() >= endsAt then
					setPhase(NEXT[phase] or "Day")
				elseif phase == "Night" and not DayNight.riot() then
					-- nobody wanders the halls at night
					sendEveryoneHome()
				end
			end)
			if not ok then
				warn("[DayNight] loop:", err)
				task.wait(1)
			end
		end
	end)
end

return DayNight
