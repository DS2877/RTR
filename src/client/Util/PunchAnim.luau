--!strict
-- Your character's punch. Plays real animation tracks through the Humanoid's Animator (Roblox's
-- own lunge / slash, Config/Assets.Animations): works on every rig (Motor6D or the new animation
-- constraints) and replicates to everyone automatically. If no Animator/track is available it
-- falls back to a procedural punch on the shoulder/waist joints (wind-up, twist, straight arm).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)

local PunchAnim = {}

local DURATION = 0.34
local WINDUP = 0.05
local STRIKE = 0.11
local HOLD = 0.15

type Rig = {
	character: Model,
	base: { [Motor6D]: CFrame },
	joints: { [string]: Motor6D },
	r15: boolean,
	started: number,
	side: number, -- 1 = right, -1 = left
	nextSide: number,
	active: boolean,
}

local rigs: { [Model]: Rig } = {}

local function find(c: Model, partName: string, joint: string): Motor6D?
	local p = c:FindFirstChild(partName)
	local m = p and p:FindFirstChild(joint)
	return if m and m:IsA("Motor6D") then m else nil
end

local function rigFor(c: Model): Rig?
	local r = rigs[c]
	if r then
		return r
	end
	local joints: { [string]: Motor6D } = {}
	local r15 = c:FindFirstChild("UpperTorso") ~= nil
	if r15 then
		joints.RS = find(c, "RightUpperArm", "RightShoulder") :: any
		joints.LS = find(c, "LeftUpperArm", "LeftShoulder") :: any
		joints.RE = find(c, "RightLowerArm", "RightElbow") :: any
		joints.LE = find(c, "LeftLowerArm", "LeftElbow") :: any
		joints.W = find(c, "UpperTorso", "Waist") :: any
	else
		joints.RS = find(c, "Torso", "Right Shoulder") :: any
		joints.LS = find(c, "Torso", "Left Shoulder") :: any
	end
	if not joints.RS or not joints.LS then
		return nil
	end
	local base = {}
	for _, m in joints do
		base[m] = m.C0
	end
	r = {
		character = c,
		base = base,
		joints = joints,
		r15 = r15,
		started = 0,
		side = 1,
		nextSide = 1,
		active = false,
	}
	rigs[c] = r
	c.AncestryChanged:Connect(function()
		if not c.Parent then
			rigs[c] = nil
		end
	end)
	return r
end

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

-- 0..1 curves over the punch: wind-up (negative), strike (1), recover.
local function curve(t: number): number
	if t < WINDUP then
		return -0.35 * smooth(t / WINDUP)
	elseif t < STRIKE then
		return -0.35 + 1.35 * smooth((t - WINDUP) / (STRIKE - WINDUP))
	elseif t < HOLD then
		return 1
	end
	return 1 - smooth((t - HOLD) / (DURATION - HOLD))
end

local function pose(r: Rig, t: number)
	local k = curve(t)
	local strike = math.max(0, k)
	local wind = math.max(0, -k) / 0.35
	local side = r.side
	local j = r.joints
	local punchS = if side > 0 then j.RS else j.LS
	local otherS = if side > 0 then j.LS else j.RS
	if r.r15 then
		local punchE = if side > 0 then j.RE else j.LE
		local otherE = if side > 0 then j.LE else j.RE
		-- punching arm: pulled back on the wind-up, straight out on the strike (aimed a bit inward)
		local pitch = math.rad(-30) * wind + math.rad(100) * strike
		local yaw = math.rad(18) * strike * side
		punchS.C0 = r.base[punchS] * CFrame.Angles(pitch, yaw, 0)
		if punchE then
			punchE.C0 = r.base[punchE]
				* CFrame.Angles(math.rad(70) * wind + math.rad(10) * (1 - strike), 0, 0)
		end
		-- guard arm comes up
		local guard = math.max(wind, strike)
		otherS.C0 = r.base[otherS] * CFrame.Angles(math.rad(55) * guard, -math.rad(25) * guard * side, 0)
		if otherE then
			otherE.C0 = r.base[otherE] * CFrame.Angles(math.rad(85) * guard, 0, 0)
		end
		-- torso: twist away on the wind-up, into the punch on the strike, lean forward
		if j.W then
			local twist = (math.rad(-14) * wind + math.rad(26) * strike) * side
			j.W.C0 = r.base[j.W] * CFrame.Angles(math.rad(-9) * strike, twist, 0)
		end
	else
		local a = math.rad(-30) * wind + math.rad(95) * strike
		punchS.C0 = r.base[punchS] * CFrame.Angles(0, 0, a * side)
		local guard = math.max(wind, strike)
		otherS.C0 = r.base[otherS] * CFrame.Angles(0, 0, -math.rad(45) * guard * side)
	end
end

local function reset(r: Rig)
	for m, b in r.base do
		if m.Parent then
			m.C0 = b
		end
	end
end

-- ===== animation tracks (preferred) =====

local trackSets: { [Model]: { AnimationTrack } } = {}
local counts: { [Model]: number } = {}
local function tracksFor(c: Model): { AnimationTrack }?
	local cached = trackSets[c]
	if cached then
		return if #cached > 0 then cached else nil
	end
	local list: { AnimationTrack } = {}
	trackSets[c] = list
	local humanoid = c:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not humanoid or not animator then
		trackSets[c] = nil -- try again once the Animator exists
		return nil
	end
	local ids = if humanoid.RigType == Enum.HumanoidRigType.R15
		then Assets.Animations.PunchR15
		else Assets.Animations.PunchR6
	for _, id in ids do
		local ok, track = pcall(function()
			local a = Instance.new("Animation")
			a.AnimationId = id
			return animator:LoadAnimation(a)
		end)
		if ok and track then
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = false
			table.insert(list, track)
		end
	end
	c.AncestryChanged:Connect(function()
		if not c.Parent then
			trackSets[c] = nil
			counts[c] = nil
		end
	end)
	return if #list > 0 then list else nil
end

-- Punch (lunge; every 3rd punch the slash).
function PunchAnim.play(c: Model?)
	if not c then
		return
	end
	local list = tracksFor(c)
	if list then
		local n = (counts[c] or 0) + 1
		counts[c] = n
		local track = list[if n % 3 == 0 and #list > 1 then 2 else 1]
		track:Play(0.04, 1, Assets.Animations.PunchSpeed)
		return
	end
	local r = rigFor(c)
	if not r then
		return
	end
	r.side = r.nextSide
	r.nextSide = -r.nextSide
	r.started = os.clock()
	r.active = true
end

function PunchAnim.playPlayer(userId: number)
	local p = Players:GetPlayerByUserId(userId)
	if p then
		PunchAnim.play(p.Character)
	end
end

-- Is this character mid-punch? (others leave its joints alone then)
function PunchAnim.busy(c: Model?): boolean
	local r = c and rigs[c]
	return r ~= nil and r.active
end

function PunchAnim.start()
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, r in rigs do
			if r.active then
				local t = now - r.started
				local owner = Players:GetPlayerFromCharacter(r.character)
				if t >= DURATION or (owner and owner:GetAttribute("Lifting")) then
					r.active = false
					reset(r)
				else
					pose(r, t)
				end
			end
		end
	end)
end

return PunchAnim
