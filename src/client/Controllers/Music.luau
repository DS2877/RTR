--!strict
-- Background music: a looping playlist of licensed sneaky/funk tracks, crossfading to a chase
-- track while you carry a stolen find. The Music switch in the HUD mutes it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)

local Music = {}

local M = Assets.Music
local player = Players.LocalPlayer
local enabled = true
local chasing = false
local index = 0
local main: Sound
local chase: Sound

local function fade(s: Sound, volume: number)
	TweenService:Create(s, TweenInfo.new(1.2, Enum.EasingStyle.Sine), { Volume = volume }):Play()
end

local function refresh()
	fade(main, if enabled and not chasing then M.Volume else 0)
	fade(chase, if enabled and chasing then M.ChaseVolume else 0)
end

local function nextTrack()
	index = index % #M.Playlist + 1
	main.SoundId = M.Playlist[index]
	main.TimePosition = 0
	main:Play()
end

function Music.start()
	main = Instance.new("Sound")
	main.Name = "Music"
	main.Volume = 0
	main.Parent = SoundService
	chase = Instance.new("Sound")
	chase.Name = "ChaseMusic"
	chase.SoundId = M.Chase
	chase.Looped = true
	chase.Volume = 0
	chase.Parent = SoundService
	chase:Play()
	main.Ended:Connect(nextTrack)
	index = math.random(0, #M.Playlist - 1)
	nextTrack()
	refresh()
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		chasing = player:GetAttribute("Carrying") == true
		refresh()
	end)
end

function Music.setEnabled(on: boolean)
	enabled = on
	if main then
		refresh()
	end
end

return Music
