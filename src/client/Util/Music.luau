--!strict
-- Background music: a looping playlist of licensed heist/funk tracks, crossfading to a chase
-- track while you carry loot. Music.setEnabled(false) mutes it (the 🎵 button) for this session.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)

local Music = {}

local M = Assets.Music
local enabled = true
local chasing = false
local playlistIndex = 0
local main: Sound
local chase: Sound

local function fade(s: Sound, volume: number, seconds: number)
	TweenService:Create(s, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Volume = volume }):Play()
end

local function targetMain(): number
	return if enabled and not chasing then M.Volume else 0
end

local function targetChase(): number
	return if enabled and chasing then M.ChaseVolume else 0
end

local function nextTrack()
	if #M.Playlist == 0 then
		return
	end
	playlistIndex = playlistIndex % #M.Playlist + 1
	main.SoundId = M.Playlist[playlistIndex]
	main.TimePosition = 0
	main:Play()
end

function Music.start()
	local group = Instance.new("SoundGroup")
	group.Name = "Music"
	group.Parent = SoundService
	main = Instance.new("Sound")
	main.Name = "MainMusic"
	main.Volume = 0
	main.SoundGroup = group
	main.Parent = SoundService
	chase = Instance.new("Sound")
	chase.Name = "ChaseMusic"
	chase.SoundId = M.Chase
	chase.Looped = true
	chase.Volume = 0
	chase.SoundGroup = group
	chase.Parent = SoundService
	main.Ended:Connect(nextTrack)
	playlistIndex = math.random(0, math.max(0, #M.Playlist - 1))
	nextTrack()
	fade(main, targetMain(), 3)
end

function Music.setChase(on: boolean)
	if on == chasing or not main then
		return
	end
	chasing = on
	if on then
		chase.TimePosition = 0
		chase:Play()
	end
	fade(main, targetMain(), 0.6)
	fade(chase, targetChase(), 0.6)
	if not on then
		task.delay(0.7, function()
			if not chasing then
				chase:Stop()
			end
		end)
	end
end

function Music.setEnabled(on: boolean)
	enabled = on
	if main then
		fade(main, targetMain(), 0.4)
		fade(chase, targetChase(), 0.4)
	end
end

function Music.isEnabled(): boolean
	return enabled
end

return Music
