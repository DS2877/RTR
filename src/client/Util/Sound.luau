--!strict
-- Tiny sound helper: Sound.play("Deposit"). IDs live in Config/Assets (empty = silent).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)

local Sound = {}

local cache: { [string]: Sound } = {}
local last: { [string]: number } = {}

function Sound.play(name: string, volume: number?, speed: number?)
	local id = Assets.Sounds[name]
	if not id or id == "" then
		return
	end
	local t = os.clock()
	if last[name] and t - last[name] < 0.06 then
		return
	end
	last[name] = t
	local base = cache[name]
	if not base then
		base = Instance.new("Sound")
		base.SoundId = id
		base.Parent = SoundService
		cache[name] = base
	end
	local s = base:Clone()
	s.Volume = (volume or 0.6)
	s.PlaybackSpeed = (speed or 1) * (0.95 + math.random() * 0.1)
	s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
	task.delay(12, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

return Sound
