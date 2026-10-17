--!strict
-- How digging sounds (Config/Audio). One clean layer per event so fast digging stays readable:
-- every punch = the zone's material hit (a little higher with every crack stage, so you hear the
-- block about to give) over a quiet fist thud; the punch that breaks it = a fist thud now, then
-- the material's break when the server confirms (+ the zone's extra layer, an occasional debris
-- trickle, a slab drop for big multi-breaks). Quick breaks in a row climb in pitch a little.
-- Cubes landing tap in 3D (throttled), the vacuum hums and pops cubes in with a rising pitch,
-- other players' digging is heard where they are, and every zone has its own ambience bed (the
-- music ducks while you're in a tunnel).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Audio = require(Shared.Config.Audio)
local Zones = require(Shared.Config.Zones)
local Progression = require(Shared.Progression)

local Sound = require(script.Parent.Parent.Util.Sound)

local DigAudio = {}

local player = Players.LocalPlayer

type MaterialSound = { hit: string, pitch: number, breakBank: string, extra: string?, volume: number }

function DigAudio.material(z: number): MaterialSound
	local zone = Zones[Progression.zoneAt(math.max(0, z))]
	local spec = Audio.Zone[zone.id]
	return Audio.Materials[spec and spec.material or "Concrete"] or Audio.Materials.Concrete
end

-- Your punch landed on block (.., z) at crack stage `stage` (0 = fresh); `breaks` = it will give.
function DigAudio.punch(z: number, stage: number, breaks: boolean)
	if breaks then
		-- the break itself comes with the server's answer; a thud now so the tap never feels dead
		Sound.play("Fist", 0.4, 0.95, 0.03)
		return
	end
	local m = DigAudio.material(z)
	local crack = math.min(stage * Audio.CrackPitchStep, Audio.CrackPitchMax)
	Sound.play(m.hit, m.volume, m.pitch * (1 + crack), 0.03)
	if Audio.FistUnderHit > 0 then
		Sound.play("Fist", Audio.FistUnderHit, 0.95, 0.03)
	end
end

local streak = 0
local lastBreak = 0
local breaks = 0
-- Blocks broke (count) at depth z. Mine = 2D and louder; others' digging plays in 3D at `pos`.
function DigAudio.broken(z: number, count: number, mine: boolean, pos: Vector3?)
	local m = DigAudio.material(z)
	if mine then
		local now = os.clock()
		streak = if now - lastBreak < Audio.StreakWindow
			then math.min(streak + Audio.StreakStep, Audio.StreakMax)
			else 0
		lastBreak = now
		breaks += 1
		local up = 1 + streak
		Sound.play(m.breakBank, 0.8, m.pitch * up, 0.03)
		if m.extra then
			Sound.play(m.extra, 0.3, 1, 0.03)
		end
		if count >= 6 then
			Sound.play("BigBreak", math.min(0.7, 0.3 + count * 0.025), 0.95)
		elseif count >= 3 or breaks % Audio.DebrisEvery == 0 then
			Sound.play("Debris", 0.25, 1)
		end
	elseif pos then
		Sound.at(m.breakBank, pos, 0.5, m.pitch, 70)
	end
end

-- Another player's hit (heard where they stand).
function DigAudio.remoteHit(z: number, pos: Vector3)
	local m = DigAudio.material(z)
	Sound.at(m.hit, pos, m.volume * 0.6, m.pitch, 60)
end

-- A debris cube hit the floor (size ~0..2 studs). Throttled hard in Sound (Audio.MinGap.Land).
function DigAudio.land(pos: Vector3, size: number)
	Sound.at("Land", pos, math.clamp(size * 0.1, 0.05, 0.18), 1.05 - math.clamp(size, 0, 2) * 0.05, 40)
end

local sucks = 0
local lastSuck = 0
-- A cube vanished into the vacuum: pops climb gently in pitch while you keep sucking.
function DigAudio.suck()
	local now = os.clock()
	sucks = if now - lastSuck < 0.6 then math.min(sucks + 1, 10) else 0
	lastSuck = now
	Sound.play("Suck", 0.25, 0.95 + sucks * 0.02, 0.02)
end

local vacuum: Sound.Loop? = nil
local vacuumOn = false
local vacuumLevel = -1
-- The vacuum's motor while you hold VACUUM (intensity 0..1 = how much it's pulling right now).
function DigAudio.vacuum(on: boolean, intensity: number)
	local v = vacuum
	if not v then
		v = Sound.loop("Vacuum")
		vacuum = v
	end
	assert(v, "vacuum loop")
	local level = if on then math.floor(intensity * 4 + 0.5) else -1
	if on ~= vacuumOn or level ~= vacuumLevel then
		local k = math.max(0, level) / 4
		v.set(if on then Audio.VacuumVolume * (0.7 + 0.3 * k) else 0, 0.9 + 0.25 * k, 0.25)
	end
	vacuumOn = on
	vacuumLevel = level
end

-- ===== ambience =====

local beds: { [string]: Sound.Loop } = {}
local current: string? = nil
local function setAmbience(name: string?)
	if name == current then
		return
	end
	if current and beds[current] then
		beds[current].set(0, nil, 1.5)
	end
	current = name
	if name then
		local b = beds[name]
		if not b then
			b = Sound.loop(name)
			beds[name] = b
		end
		b.set(Audio.AmbienceVolume, nil, 1.5)
	end
end

function DigAudio.start(where: () -> (boolean, number), duck: (number) -> ())
	local acc = 0
	local ducked = false
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		local inTunnel, zone = where()
		local z = Zones[zone]
		local spec = if inTunnel and z then Audio.Zone[z.id] else nil
		setAmbience(if spec then spec.ambience else nil)
		if inTunnel ~= ducked then
			ducked = inTunnel
			duck(if inTunnel then Audio.MusicDuckInTunnel else 1)
		end
	end)
	player.CharacterAdded:Connect(function()
		if vacuum then
			vacuum.set(0)
		end
	end)
end

return DigAudio
