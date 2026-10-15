--!strict
-- Background music: a looping playlist of licensed sneaky/funk tracks, crossfading to a chase
-- track while you carry a stolen find. The 🎵 button (lower left) mutes it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)

local Client = script.Parent.Parent
local UI = require(Client.Util.UI)

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
	local gui = UI.new(
		"ScreenGui",
		{ Name = "MusicButton", ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui") }
	)
	local b: TextButton = UI.new("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -10),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Color3.fromRGB(60, 60, 75),
		Text = "🎵",
		TextScaled = true,
		Parent = gui,
	}, { UI.corner(22), UI.stroke(Color3.fromRGB(20, 20, 28), 3) })
	UI.scaleObject(b)
	b.Activated:Connect(function()
		enabled = not enabled
		b.Text = if enabled then "🎵" else "🔇"
		refresh()
	end)
end

return Music
