--!strict
-- Real Roblox R15 characters for NPCs (guards, the rich people), built from a HumanoidDescription
-- with body colors, and Roblox's own idle/walk/run animations played from the server (they
-- replicate to everyone). Returns nil if the rig can't be created; callers fall back to their
-- part-built models so the game never breaks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)

local Rig = {}

export type Colors = { head: Color3, torso: Color3, arms: Color3, legs: Color3 }

local templates: { [string]: Model } = {}
local failed = false

function Rig.build(key: string, colors: Colors): Model?
	local cached = templates[key]
	if cached then
		return cached:Clone()
	end
	if failed then
		return nil
	end
	local ok, result = pcall(function()
		local d = Instance.new("HumanoidDescription")
		d.HeadColor = colors.head
		d.TorsoColor = colors.torso
		d.LeftArmColor = colors.arms
		d.RightArmColor = colors.arms
		d.LeftLegColor = colors.legs
		d.RightLegColor = colors.legs
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	if not ok or not result then
		failed = true -- don't retry for every NPC
		warn("R15 rig unavailable, using part models: " .. tostring(result))
		return nil
	end
	local model = result :: Model
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		if not humanoid:FindFirstChildOfClass("Animator") then
			Instance.new("Animator").Parent = humanoid
		end
	end
	templates[key] = model
	return model:Clone()
end

-- Loads (once per humanoid) and returns a looped animation track by Assets.Animations name.
local tracks: { [Humanoid]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any

function Rig.track(humanoid: Humanoid, name: string): AnimationTrack?
	local byName = tracks[humanoid]
	if not byName then
		byName = {}
		tracks[humanoid] = byName
	end
	local t = byName[name]
	if t then
		return t
	end
	local id = Assets.Animations[name]
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not id or not animator then
		return nil
	end
	local ok, loaded = pcall(function()
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		return animator:LoadAnimation(anim)
	end)
	if not ok or not loaded then
		return nil
	end
	local track = loaded :: AnimationTrack
	track.Looped = true
	byName[name] = track
	return track
end

-- Plays exactly one of the looped animations (idle / walk / run), crossfading.
function Rig.setPose(humanoid: Humanoid, name: string, speed: number?)
	local want = Rig.track(humanoid, name)
	if not want then
		return
	end
	for other, t in tracks[humanoid] or {} do
		if other ~= name and t.IsPlaying then
			t:Stop(0.2)
		end
	end
	if not want.IsPlaying then
		want:Play(0.2)
	end
	if speed then
		want:AdjustSpeed(speed)
	end
end

-- Welds a decorative part to a body part (keeps it on while animations move the body).
function Rig.attach(bodyPart: BasePart, p: BasePart, offset: CFrame)
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = bodyPart.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = bodyPart
	w.Part1 = p
	w.Parent = p
	p.Parent = bodyPart.Parent
end

return Rig
