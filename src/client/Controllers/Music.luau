--!strict
-- Background music: the prison-yard radio. A shuffled playlist of licensed 90s boom bap / G-funk
-- tracks with a small "now playing" chip in the top-left corner (only once a track has really
-- loaded), crossfading to a chase track while you carry a stolen find. The 🎵 chip in the HUD mutes
-- it. Three tracks in a row that never load: the radio gives up (no chip, no retry loop).

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
local failures = 0 -- tracks in a row that never loaded
local dead = false -- gave up after 3 failures

-- where the chip sits (right of the HUD's 🎵 switch) and where it hides (fully off-screen left)
local CHIP_SHOWN = UDim2.fromOffset(56, 8)
local CHIP_HIDDEN = UDim2.fromOffset(-10, 8)

local function fade(s: Sound, volume: number)
	TweenService:Create(s, TweenInfo.new(1.2, Enum.EasingStyle.Sine), { Volume = volume }):Play()
end

local function refresh()
	fade(main, if enabled and not chasing then M.Volume * duck else 0)
	fade(chase, if enabled and chasing then M.ChaseVolume else 0)
end

-- slides the chip fully off-screen, then really hides it
local function hideChip()
	chipToken += 1
	local token = chipToken
	local c = chip
	if not c or not c.Visible then
		return
	end
	UI.tween(c, 0.5, { Position = CHIP_HIDDEN, AnchorPoint = Vector2.new(1, 0) }, Enum.EasingStyle.Quint)
	task.delay(0.55, function()
		if token == chipToken then
			c.Visible = false
		end
	end)
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
			AnchorPoint = Vector2.new(1, 0),
			Position = CHIP_HIDDEN,
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.fromRGB(14, 15, 19),
			BackgroundTransparency = 0.3,
			Visible = false,
			Parent = gui,
		}, {
			UI.corner(13),
			UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12) }),
			UI.new("UISizeConstraint", { MaxSize = Vector2.new(240, 26) }),
		})
		chipText = UI.new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			RichText = true,
			TextColor3 = Color3.fromRGB(200, 204, 214),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = "",
			Parent = chip,
		}, { UI.new("UISizeConstraint", { MaxSize = Vector2.new(218, 26) }) })
	end
	local c, t = chip :: Frame, chipText :: TextLabel
	if not enabled or dead then
		return
	end
	chipToken += 1
	local token = chipToken
	t.Text = string.format('📻  <font color="#FFB547"><b>%s</b></font>  ·  %s', title, artist)
	c.Visible = true
	c.AnchorPoint = Vector2.new(1, 0)
	c.Position = CHIP_HIDDEN
	UI.tween(c, 0.5, { Position = CHIP_SHOWN, AnchorPoint = Vector2.zero }, Enum.EasingStyle.Quint)
	task.delay(5, function()
		if token == chipToken then
			hideChip()
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
local trackToken = 0
local function nextTrack()
	if dead then
		return
	end
	startedAt = os.clock()
	index += 1
	if index > #order then
		reshuffle()
		index = 1
	end
	trackToken += 1
	local mine = trackToken
	local track = M.Playlist[order[index]]
	main.SoundId = track.id
	main.TimePosition = 0
	main:Play()
	-- the chip only once the track has really loaded (a broken id shows nothing)
	task.spawn(function()
		local waited = 0
		while not main.IsLoaded and waited < 20 and trackToken == mine do
			waited += task.wait(0.25)
		end
		if main.IsLoaded and trackToken == mine and not chasing then
			nowPlaying(track.title, track.artist)
		end
	end)
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
		if dead then
			return
		end
		if main.IsLoaded then
			failures = 0
		end
		if not main.IsLoaded and age > 20 then
			failures += 1
			if failures >= 3 then
				-- the radio is broken (assets blocked / removed): stop trying, hide the chip
				dead = true
				main:Stop()
				hideChip()
				return
			end
			nextTrack()
		elseif not main.IsPlaying or stuck >= 3 or (len > 0 and pos >= len - 0.15) then
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
	if not on then
		hideChip()
	end
	if main then
		refresh()
	end
end

return Music
