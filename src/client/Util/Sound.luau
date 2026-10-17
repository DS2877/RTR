--!strict
-- Sound helper.
--   Sound.play("Punch")               one-shot (Config/Assets.Sounds or a Config/Audio bank)
--   Sound.at("HitRock", pos, 0.5)     one-shot in 3D at a world position
--   Sound.loop("Vacuum") -> handle    looping bed; handle.set(volume, speed) fades to it
-- Banks pick a random variation (never the same one twice in a row). Every clip is loudness-
-- normalised (Config/Audio Clips / Single / LoopTune gain) and skips its leading silence, so the
-- volume a call site passes means the same for every sound. Everything goes through an SFX group
-- with a light safety compressor (no makeup gain) so stacked hits don't clip.

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
	comp.Threshold = -8
	comp.Ratio = 3
	comp.Attack = 0.003
	comp.Release = 0.15
	comp.GainMakeup = 0
	comp.Parent = g
	g.Parent = SoundService
	group = g
	return g
end

local NO_TUNE: Audio.Clip = { gain = 1, start = 0 }

local lastPick: { [string]: number } = {}
-- (id, its gain + start trim) for a bank or an Assets.Sounds name
local function pick(name: string): (string?, Audio.Clip)
	local bank = Audio.Banks[name]
	if bank and #bank > 0 then
		local i = math.random(1, #bank)
		if #bank > 1 and i == lastPick[name] then
			i = i % #bank + 1
		end
		lastPick[name] = i
		local id = bank[i]
		return id, Audio.Clips[id] or NO_TUNE
	end
	local id = Assets.Sounds[name]
	if id and id ~= "" then
		return id, Audio.Single[name] or NO_TUNE
	end
	return nil, NO_TUNE
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
local function throttled(key: string, gap: number): boolean
	local t = os.clock()
	if last[key] and t - last[key] < gap then
		return true
	end
	last[key] = t
	return false
end

local function gapFor(name: string): number
	return Audio.MinGap[name] or Audio.DefaultGap
end

local function start(s: Sound, tune: Audio.Clip, volume: number?)
	s.Volume = math.clamp((volume or 0.6) * tune.gain, 0, 10)
	if tune.start > 0 then
		s.TimePosition = tune.start
	end
	s:Play()
end

-- speed: playback speed (pitch) before a small random spread; spread 0 = exact
function Sound.play(name: string, volume: number?, speed: number?, spread: number?)
	if throttled(name, gapFor(name)) then
		return
	end
	local id, tune = pick(name)
	if not id then
		return
	end
	local s = make(id)
	local r = spread or Audio.Spread
	s.PlaybackSpeed = (speed or 1) * (1 - r + math.random() * r * 2)
	s.Parent = SoundService
	start(s, tune, volume)
	cleanup(s)
end

-- A one-shot in the world (other players' digging, cubes landing, doors).
function Sound.at(name: string, pos: Vector3, volume: number?, speed: number?, maxDistance: number?)
	if throttled(name .. "@", math.max(0.02, gapFor(name))) then
		return
	end
	local id, tune = pick(name)
	if not id then
		return
	end
	local holder = Instance.new("Attachment")
	holder.WorldPosition = pos
	holder.Parent = workspace.Terrain
	local s = make(id)
	local r = Audio.Spread
	s.PlaybackSpeed = (speed or 1) * (1 - r + math.random() * r * 2)
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = maxDistance or 80
	s.Parent = holder
	start(s, tune, volume)
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
	local tune = Audio.LoopTune[name]
	if not tune then
		-- an Assets.Sounds id used as a bed (the breakout siren): tune by its name
		for soundName, soundId in Assets.Sounds do
			if soundId == id then
				tune = Audio.LoopTune[soundName]
			end
		end
	end
	local gain = if tune then tune.gain else 1
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = sfx()
	if tune and tune.to then
		-- loop only the steady part (pcall: playback regions are a newer Sound feature)
		local from, to = tune.from or 0, tune.to
		pcall(function()
			s.PlaybackRegionsEnabled = true
			s.LoopRegion = NumberRange.new(from, to)
		end)
		s.TimePosition = from
	end
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
			local props: { [string]: any } = { Volume = math.clamp(volume * gain, 0, 10) }
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
