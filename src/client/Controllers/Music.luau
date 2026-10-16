--!strict
-- Background music: the prison-yard radio. A shuffled playlist of licensed 90s boom bap / G-funk
-- tracks with a small "now playing" chip in the top-left corner, crossfading to a chase track while
-- you carry a stolen find. The Music switch in the HUD mutes it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local UI = require(script.Parent.Parent.Util.UI)

local Music = {}

local M = Assets.Music
local player = Players.LocalPlayer
local enabled = true
local duck = 1
local chasing = false
local index = 0
local main: Sound
local chase: Sound
local order: { number } = {}
local chip: Frame? = nil
local chipText: TextLabel? = nil
local chipToken = 0

local function fade(s: Sound, volume: number)
	TweenService:Create(s, TweenInfo.new(1.2, Enum.EasingStyle.Sine), { Volume = volume }):Play()
end

local function refresh()
	fade(main, if enabled and not chasing then M.Volume * duck else 0)
	fade(chase, if enabled and chasing then M.ChaseVolume else 0)
end

-- a slim "now playing" chip that slides in for a few seconds when a track starts
local function nowPlaying(title: string, artist: string)
	if not chip then
		local gui = UI.new("ScreenGui", {
			Name = "NowPlaying",
			ResetOnSpawn = false,
			DisplayOrder = 2,
			Parent = player:WaitForChild("PlayerGui"),
		})
		chip = UI.new("Frame", {
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(-320, 10),
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.fromRGB(14, 15, 19),
			BackgroundTransparency = 0.3,
			Parent = gui,
		}, {
			UI.corner(13),
			UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12) }),
		})
		chipText = UI.new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			RichText = true,
			TextColor3 = Color3.fromRGB(200, 204, 214),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
			Parent = chip,
		})
	end
	local c, t = chip :: Frame, chipText :: TextLabel
	if not enabled then
		return
	end
	chipToken += 1
	local token = chipToken
	t.Text = string.format('📻  <font color="#FFB547"><b>%s</b></font>  ·  %s', title, artist)
	c.Size = UDim2.fromOffset(0, 26)
	c.Position = UDim2.fromOffset(-340, 10)
	UI.tween(c, 0.5, { Position = UDim2.fromOffset(12, 10) }, Enum.EasingStyle.Quint)
	task.delay(5, function()
		if token == chipToken then
			UI.tween(c, 0.5, { Position = UDim2.fromOffset(-340, 10) }, Enum.EasingStyle.Quint)
		end
	end)
end

-- shuffle the whole playlist, then play it through before reshuffling (never the same track twice
-- in a row across the seam)
local function reshuffle()
	local last = order[#order]
	order = {}
	for i = 1, #M.Playlist do
		order[i] = i
	end
	for i = #order, 2, -1 do
		local j = math.random(1, i)
		order[i], order[j] = order[j], order[i]
	end
	if #order > 1 and order[1] == last then
		order[1], order[2] = order[2], order[1]
	end
	index = 0
end

local startedAt = 0
local function nextTrack()
	startedAt = os.clock()
	index += 1
	if index > #order then
		reshuffle()
		index = 1
	end
	local track = M.Playlist[order[index]]
	main.SoundId = track.id
	main.TimePosition = 0
	main:Play()
	if not chasing then
		nowPlaying(track.title, track.artist)
	end
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
	-- watchdog: a track that never loads, gets stopped or stalls never fires Ended (that left the
	-- radio silent for good). Every 2 s: not playing / not loaded after 20 s / stuck -> next track.
	local acc, lastPos, stuck = 0, -1, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 2 then
			return
		end
		acc = 0
		if not chase.IsPlaying then
			chase:Play()
		end
		local age = os.clock() - startedAt
		if age < 4 then
			lastPos, stuck = -1, 0
			return
		end
		local pos = main.TimePosition
		stuck = if main.IsLoaded and main.IsPlaying and math.abs(pos - lastPos) < 0.05 then stuck + 1 else 0
		lastPos = pos
		local len = main.TimeLength
		if
			not main.IsPlaying
			or (not main.IsLoaded and age > 20)
			or stuck >= 3
			or (len > 0 and pos >= len - 0.15)
		then
			nextTrack()
		end
	end)
	reshuffle()
	nextTrack()
	refresh()
	-- the chase track: carrying a stolen find, or on THE BREAKOUT
	local function chase()
		chasing = player:GetAttribute("Carrying") == true or player:GetAttribute("Breakout") == true
		refresh()
	end
	player:GetAttributeChangedSignal("Carrying"):Connect(chase)
	player:GetAttributeChangedSignal("Breakout"):Connect(chase)
end

-- Quieter while you're in a tunnel (the zone ambience takes over): 1 = full volume.
function Music.setDuck(f: number)
	duck = f
	if main then
		refresh()
	end
end

function Music.setEnabled(on: boolean)
	enabled = on
	if main then
		refresh()
	end
end

return Music
