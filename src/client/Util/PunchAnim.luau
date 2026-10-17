--!strict
-- Your character's punch: a procedural boxing combo layered on top of whatever the Animator is
-- playing (idle, walk, run). Each frame (PreSimulation, after the animations) we add our pose to
-- the joints' Transform, so it works on every rig (Motor6D or the new AnimationConstraint joints)
-- and never "freezes": the walk keeps going underneath and the fists return to a guard.
--
-- One punch: wind-up (fist pulled back, torso twists away) -> snap (straight arm, torso twists in,
-- lean, a small step) -> a short hold with overshoot -> recover to the guard. Punches alternate
-- right / left; every 4th is a heavier overhand. While you keep punching, both fists stay up in a
-- guard; a moment after the last punch the arms drop back to the normal animation.
-- Every client runs this for every puncher (init.client calls play() for other players' hits).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PunchAnim = {}

local DURATION = 0.3
local WIND = 0.05
local SNAP = 0.11
local HOLD = 0.15
local GUARD_TIME = 0.75 -- seconds after the last punch the guard stays up

type Rig = {
	character: Model,
	joints: { [string]: Instance }, -- Motor6D or AnimationConstraint (both have Transform)
	r15: boolean,
	started: number,
	last: number,
	side: number, -- 1 = right, -1 = left
	count: number,
	heavy: boolean,
	guard: number, -- 0..1, eased
	base: { [Instance]: CFrame }, -- the Animator's Transform this frame
	written: { [Instance]: CFrame }, -- what we wrote last frame
	posed: boolean,
	frozenAt: number?, -- HITSTOP: the punch holds still from here...
	frozenUntil: number, -- ...until here
}

local rigs: { [Model]: Rig } = {}

local R15_JOINTS = { "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "Waist", "Neck", "Root" }
local R6_JOINTS = { "Right Shoulder", "Left Shoulder", "Neck" }

local function isJoint(i: Instance): boolean
	return i:IsA("Motor6D") or i:IsA("AnimationConstraint")
end

local function scan(c: Model, r15: boolean): { [string]: Instance }
	local out: { [string]: Instance } = {}
	local wanted: { [string]: boolean } = {}
	for _, n in if r15 then R15_JOINTS else R6_JOINTS do
		wanted[n] = true
	end
	for _, d in c:GetDescendants() do
		if wanted[d.Name] and isJoint(d) and not out[d.Name] then
			out[d.Name] = d
		end
	end
	return out
end

local function rigFor(c: Model): Rig?
	local r = rigs[c]
	if r then
		-- the avatar can be rebuilt after it loads: re-scan when a joint went away
		for _, j in r.joints do
			if not j.Parent then
				r.joints = scan(c, r.r15)
				break
			end
		end
		return r
	end
	local r15 = c:FindFirstChild("UpperTorso") ~= nil
	local joints = scan(c, r15)
	local rs = if r15 then joints.RightShoulder else joints["Right Shoulder"]
	if not rs then
		return nil
	end
	r = {
		character = c,
		joints = joints,
		r15 = r15,
		started = -1,
		last = -1,
		side = -1,
		count = 0,
		heavy = false,
		guard = 0,
		base = {},
		written = {},
		posed = false,
		frozenAt = nil,
		frozenUntil = 0,
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

local function outCubic(a: number): number
	a = math.clamp(a, 0, 1)
	return 1 - (1 - a) ^ 3
end

-- wind (0..1) and strike (0..~1.08) at time t into the punch
local function curve(t: number): (number, number)
	if t < 0 or t >= DURATION then
		return 0, 0
	elseif t < WIND then
		return smooth(t / WIND), 0
	elseif t < SNAP then
		local k = (t - WIND) / (SNAP - WIND)
		return 1 - outCubic(k), outCubic(k) * 1.08
	elseif t < HOLD then
		return 0, 1.08 - 0.08 * smooth((t - SNAP) / (HOLD - SNAP))
	end
	return 0, 1 - smooth((t - HOLD) / (DURATION - HOLD))
end

local rad = math.rad

-- our pose offsets per joint name (applied on top of the Animator's Transform)
local function offsetsR15(r: Rig, wind: number, strike: number): { [string]: CFrame }
	local g = r.guard
	local s = r.side
	local heavy = if r.heavy then 1 else 0
	local out: { [string]: CFrame } = {}
	local function arm(sideSign: number, punching: boolean): (CFrame, CFrame)
		-- guard: fist up by the chin, elbow bent, tucked in a little
		local pitch = rad(62) * g
		local roll = -rad(14) * g * sideSign
		local elbow = rad(105) * g
		if punching then
			-- wind-up: fist pulled back a bit; strike: straight out (overhand comes from higher)
			pitch += rad(-28) * wind + (rad(96) + rad(28) * heavy - pitch) * math.min(strike, 1)
			pitch += rad(6) * math.max(0, strike - 1) / 0.08
			roll += (-rad(10) * sideSign - roll) * math.min(strike, 1)
			elbow += rad(25) * wind + (rad(4) - elbow) * math.min(strike, 1)
		else
			-- the other fist pulls back to the chin while this one strikes
			pitch += rad(-10) * strike
			elbow += rad(15) * strike
		end
		return CFrame.Angles(pitch, 0, 0) * CFrame.Angles(0, 0, roll), CFrame.Angles(elbow, 0, 0)
	end
	local rsh, rel = arm(1, s > 0)
	local lsh, lel = arm(-1, s < 0)
	out.RightShoulder, out.RightElbow = rsh, rel
	out.LeftShoulder, out.LeftElbow = lsh, lel
	-- torso: twist away on the wind-up, into the punch on the strike, lean in
	local twist = (rad(-14) * wind + rad(28 + 10 * heavy) * strike) * s
	local lean = -rad(4) * g - rad(9 + 6 * heavy) * strike
	out.Waist = CFrame.Angles(lean, twist, 0)
	-- the head keeps looking at the target
	out.Neck = CFrame.Angles(-lean * 0.4, -twist * 0.6, 0)
	-- weight shift: a small dip + step into the punch
	out.Root = CFrame.new(0, -0.12 * strike - 0.05 * g, -0.18 * strike)
	return out
end

local function offsetsR6(r: Rig, wind: number, strike: number): { [string]: CFrame }
	local g = r.guard
	local s = r.side
	local out: { [string]: CFrame } = {}
	local function arm(sideSign: number, punching: boolean): CFrame
		local a = rad(70) * g
		if punching then
			a += rad(-25) * wind + (rad(95) - a) * math.min(strike, 1)
		else
			a -= rad(10) * strike
		end
		return CFrame.Angles(0, 0, a * sideSign)
	end
	out["Right Shoulder"] = arm(1, s > 0)
	out["Left Shoulder"] = arm(-1, s < 0)
	return out
end

-- Punch (alternating; every 4th a heavier overhand).
function PunchAnim.play(c: Model?)
	if not c then
		return
	end
	local owner = Players:GetPlayerFromCharacter(c)
	if owner and owner:GetAttribute("Lifting") then
		return
	end
	local r = rigFor(c)
	if not r then
		return
	end
	local now = os.clock()
	r.side = -r.side
	r.count += 1
	r.heavy = r.count % 4 == 0
	r.started = now
	r.last = now
end

-- Your punch froze on a breaking block (DigFX.onHitstop): hold the pose for `seconds`.
function PunchAnim.hitstop(c: Model?, seconds: number)
	local r = c and rigs[c]
	if not r or r.frozenAt then
		return
	end
	local now = os.clock()
	r.frozenAt = now
	r.frozenUntil = now + seconds
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
	return r ~= nil and os.clock() - r.started < DURATION
end

local function release(r: Rig)
	-- hand the joints back to the Animator exactly as it left them
	for j, b in r.base do
		if j.Parent then
			(j :: any).Transform = b
		end
	end
	table.clear(r.base)
	table.clear(r.written)
	r.posed = false
end

function PunchAnim.start()
	local last = os.clock()
	RunService.PreSimulation:Connect(function()
		local now = os.clock()
		local dt = math.min(0.1, now - last)
		last = now
		for c, r in rigs do
			local owner = Players:GetPlayerFromCharacter(c)
			local lifting = owner ~= nil and owner:GetAttribute("Lifting") ~= nil
			local target = if not lifting and now - r.last < GUARD_TIME then 1 else 0
			r.guard += (target - r.guard) * math.min(1, dt * (if target > r.guard then 16 else 7))
			-- HITSTOP: the pose holds at the moment of impact, then the punch carries on
			local frozenAt = r.frozenAt
			if frozenAt then
				if now >= r.frozenUntil then
					r.started += r.frozenUntil - frozenAt
					r.frozenAt = nil
				end
			end
			local t = if r.frozenAt then (r.frozenAt :: number) - r.started else now - r.started
			local wind, strike = curve(t)
			if lifting then
				wind, strike = 0, 0
			end
			if r.guard < 0.01 and wind == 0 and strike == 0 then
				if r.posed then
					release(r)
				end
				continue
			end
			local offsets = if r.r15 then offsetsR15(r, wind, strike) else offsetsR6(r, wind, strike)
			for name, off in offsets do
				local j = r.joints[name]
				if j and j.Parent then
					local cur = (j :: any).Transform :: CFrame
					-- the Animator rewrites Transform every frame for the joints it animates; if it
					-- didn't (nothing playing on that joint), start from what it had last time
					local b = if r.written[j] and cur == r.written[j] then r.base[j] or cur else cur
					r.base[j] = b
					local nt = b * off;
					(j :: any).Transform = nt
					r.written[j] = nt
				end
			end
			r.posed = true
		end
	end)
end

return PunchAnim
