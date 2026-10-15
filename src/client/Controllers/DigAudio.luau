--!strict
-- How digging sounds (Config/Audio). Every punch: an air whoosh + a beefy fist + the zone's
-- material hit, a little higher with every crack stage so you hear the block about to give.
-- Breaks: the material's break + a debris layer (+ rebar / splash / steam / chime by zone), and
-- quick breaks in a row climb in pitch. Cubes landing tap in 3D, the vacuum hums and pops cubes in
-- with a rising pitch, other players' digging is heard where they are, and every zone has its own
-- ambience bed (the music ducks while you're in a tunnel).

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
	local m = DigAudio.material(z)
	Sound.play("Swing", 0.32, 1.05)
	Sound.play("Fist", 0.5, 0.9)
	if not breaks then
		Sound.play(m.hit, m.volume, m.pitch * (1 + stage * Audio.CrackPitchStep), 0.04)
	end
end

local streak = 0
local lastBreak = 0
-- Blocks broke (count) at depth z. Mine = 2D and louder; others' digging plays in 3D at `pos`.
function DigAudio.broken(z: number, count: number, mine: boolean, pos: Vector3?)
	local m = DigAudio.material(z)
	if mine then
		local now = os.clock()
		streak = if now - lastBreak < Audio.StreakWindow
			then math.min(streak + Audio.StreakStep, Audio.StreakMax)
			else 0
		lastBreak = now
		local up = 1 + streak
		Sound.play(m.breakBank, 0.85, m.pitch * up, 0.05)
		Sound.play("Debris", 0.45, up)
		if m.extra then
			Sound.play(m.extra, 0.4, 1)
		end
		if count >= 6 then
			Sound.play("BigBreak", math.min(0.9, 0.35 + count * 0.03), 0.9)
		end
	elseif pos then
		Sound.at(m.breakBank, pos, 0.6, m.pitch, 70)
	end
end

-- Another player's hit (heard where they stand).
function DigAudio.remoteHit(z: number, pos: Vector3)
	local m = DigAudio.material(z)
	Sound.at(m.hit, pos, m.volume * 0.7, m.pitch, 60)
end

-- A debris cube hit the floor (size ~0..2 studs).
function DigAudio.land(pos: Vector3, size: number)
	Sound.at("Land", pos, math.clamp(size * 0.18, 0.08, 0.35), 1.25 - size * 0.2, 50)
end

local sucks = 0
local lastSuck = 0
-- A cube vanished into the vacuum: pops climb in pitch while you keep sucking.
function DigAudio.suck()
	local now = os.clock()
	sucks = if now - lastSuck < 0.6 then math.min(sucks + 1, 16) else 0
	lastSuck = now
	Sound.play("Suck", 0.35, 0.9 + sucks * 0.035, 0.02)
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
