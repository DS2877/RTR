--!strict
-- Sound helper.
--   Sound.play("Punch")               one-shot (Config/Assets.Sounds or a Config/Audio bank)
--   Sound.at("HitRock", pos, 0.5)     one-shot in 3D at a world position
--   Sound.loop("Vacuum") -> handle    looping bed; handle.set(volume, speed) fades to it
-- Banks pick a random variation (never the same one twice in a row). Everything goes through an
-- SFX group with a gentle compressor so stacked hits stay punchy instead of clipping.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Audio = require(ReplicatedStorage.Shared.Config.Audio)

local Sound = {}

local group: SoundGroup? = nil
local function sfx(): SoundGroup
	if group and group.Parent then
		return group
	end
	local g = Instance.new("SoundGroup")
	g.Name = "SFX"
	g.Volume = 1
	local comp = Instance.new("CompressorSoundEffect")
	comp.Threshold = -14
	comp.Ratio = 3
	comp.Attack = 0.005
	comp.Release = 0.12
	comp.GainMakeup = 2
	comp.Parent = g
	g.Parent = SoundService
	group = g
	return g
end

local lastPick: { [string]: number } = {}
local function pick(name: string): string?
	local bank = Audio.Banks[name]
	if bank and #bank > 0 then
		local i = math.random(1, #bank)
		if #bank > 1 and i == lastPick[name] then
			i = i % #bank + 1
		end
		lastPick[name] = i
		return bank[i]
	end
	local id = Assets.Sounds[name]
	if id and id ~= "" then
		return id
	end
	return nil
end

local templates: { [string]: Sound } = {}
local function make(id: string): Sound
	local base = templates[id]
	if not base then
		base = Instance.new("Sound")
		base.SoundId = id
		base.SoundGroup = sfx()
		base.Parent = SoundService -- preloads
		templates[id] = base
	end
	return (base :: Sound):Clone()
end

local function cleanup(s: Sound, holder: Instance?)
	s.Ended:Once(function()
		(holder or s):Destroy()
	end)
	task.delay(10, function()
		if (holder or s).Parent then
			(holder or s):Destroy()
		end
	end)
end

local last: { [string]: number } = {}
local function throttled(name: string, gap: number): boolean
	local t = os.clock()
	if last[name] and t - last[name] < gap then
		return true
	end
	last[name] = t
	return false
end

-- speed: playback speed (pitch) before a small random spread; spread 0 = exact
function Sound.play(name: string, volume: number?, speed: number?, spread: number?)
	if throttled(name, 0.035) then
		return
	end
	local id = pick(name)
	if not id then
		return
	end
	local s = make(id)
	local r = spread or 0.05
	s.Volume = volume or 0.6
	s.PlaybackSpeed = (speed or 1) * (1 - r + math.random() * r * 2)
	s.Parent = SoundService
	s:Play()
	cleanup(s)
end

-- A one-shot in the world (other players' digging, cubes landing, doors).
function Sound.at(name: string, pos: Vector3, volume: number?, speed: number?, maxDistance: number?)
	if throttled(name .. "@", 0.02) then
		return
	end
	local id = pick(name)
	if not id then
		return
	end
	local holder = Instance.new("Attachment")
	holder.WorldPosition = pos
	holder.Parent = workspace.Terrain
	local s = make(id)
	s.Volume = volume or 0.6
	s.PlaybackSpeed = (speed or 1) * (0.95 + math.random() * 0.1)
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = maxDistance or 80
	s.Parent = holder
	s:Play()
	cleanup(s, holder)
end

export type Loop = {
	set: (volume: number, speed: number?, seconds: number?) -> (),
	stop: () -> (),
	sound: Sound,
}

-- A looping bed (Config/Audio.Loops name or an asset id), silent until set().
function Sound.loop(name: string): Loop
	local id = Audio.Loops[name] or name
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = sfx()
	s.Parent = SoundService
	local tween: Tween? = nil
	local playing = false
	local loop: Loop = {
		sound = s,
		set = function(volume: number, speed: number?, seconds: number?)
			if tween then
				tween:Cancel()
			end
			if volume > 0 and not playing then
				playing = true
				s:Play()
			end
			local props: { [string]: any } = { Volume = volume }
			if speed then
				props.PlaybackSpeed = speed
			end
			local tw = TweenService:Create(s, TweenInfo.new(seconds or 0.4, Enum.EasingStyle.Sine), props)
			tween = tw
			tw:Play()
			if volume <= 0 then
				tw.Completed:Once(function(state)
					if state == Enum.PlaybackState.Completed and s.Volume <= 0.001 then
						playing = false
						s:Pause()
					end
				end)
			end
		end,
		stop = function()
			s:Destroy()
		end,
	}
	return loop
end

return Sound
