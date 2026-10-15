--!strict
-- The PRISON GYM in the Yard: use a station (toilet, mattresses, vending machine, a sleeping
-- guard...) to hoist it over your head, then tap LIFT when the timing meter's needle is in the
-- green zone. Perfect (gold center) = double strength and a combo; miss = OOF. The server owns the
-- meter: it computes the needle from its own clock (with an allowance for the player's ping).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local GymProps = require(script.Parent.Parent.Util.GymProps)
local Stats = require(script.Parent.Stats)

local Gym = {}

local world: any = nil

export type Lifting = { station: number, start: number, combo: number, weld: Weld?, held: Model? }
local lifting: { [any]: Lifting } = {}

local HELD_SIZE = 7 -- studs: even the bus gets squeezed to this (it's funnier that way)

local function now(): number
	return workspace:GetServerTimeNow()
end

function Gym.lifting(player: Player): Lifting?
	return lifting[player]
end

local function stationPart(i: number): BasePart?
	return world.stations[i]
end

local function setFrozen(player: Player, frozen: boolean)
	if typeof(player) ~= "Instance" then
		return
	end
	local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if h then
		h.WalkSpeed = if frozen then 0 else Economy.WalkSpeed
		h.JumpPower = if frozen then 0 else 50
	end
end

-- Puts the station's prop over the player's head and starts the meter. Returns a reason when refused.
function Gym.begin(player: Player, station: number): string?
	local s = State.get(player)
	local root = State.root(player)
	local st = Economy.Gym[station]
	local part = stationPart(station)
	if not s or not root or not st or not part then
		return "bad"
	end
	if lifting[player] then
		return "busy"
	end
	if (part.Position - root).Magnitude > Economy.GymRange + 4 then
		return "too far"
	end
	if s.data.Strength < st.minStrength then
		Net.notice(
			player,
			string.format("You need %s 💪 to lift the %s", Format.number(st.minStrength), st.name),
			"bad"
		)
		return "weak"
	end
	local l: Lifting = { station = station, start = now(), combo = 0 }
	lifting[player] = l
	-- the prop over your head (welded to the root part, bobbed by the server so everyone sees it)
	local character = typeof(player) == "Instance" and player.Character or nil
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		local held = GymProps.held(st.id, HELD_SIZE)
		local rootPart = held.PrimaryPart :: BasePart
		local _, size = held:GetBoundingBox()
		local weld = Instance.new("Weld")
		weld.Part0 = hrp
		weld.Part1 = rootPart
		weld.C0 = CFrame.new(0, 3.2 + size.Y / 2, 0)
		weld.Parent = rootPart
		held.Name = "Lifting"
		held.Parent = character
		l.weld = weld
		l.held = held
	end
	setFrozen(player, true)
	if typeof(player) == "Instance" then
		player:SetAttribute("Lifting", station)
	end
	Net.fire(player, Remotes.Names.LiftStart, station, l.start)
	Net.notice(player, st.emoji .. " " .. st.line, "info")
	return nil
end

function Gym.stop(player: Player)
	local l = lifting[player]
	if not l then
		return
	end
	lifting[player] = nil
	if l.held then
		l.held:Destroy()
	end
	setFrozen(player, false)
	if typeof(player) == "Instance" then
		player:SetAttribute("Lifting", nil)
	end
	Net.fire(player, Remotes.Names.LiftStop)
end

-- The best rep quality the needle had during the player's latency window.
local function quality(player: Player, l: Lifting, at: number): string
	local st = Economy.Gym[l.station]
	local ping = 0
	if typeof(player) == "Instance" then
		local ok, p = pcall(function()
			return player:GetNetworkPing()
		end)
		ping = if ok then math.clamp(p, 0, 0.4) else 0.15
	end
	local rank = { miss = 0, good = 1, perfect = 2 }
	local best = "miss"
	for i = 0, 6 do
		local t = at - (ping + 0.06) * i / 6
		local q = Progression.liftQuality(Progression.meterPos(t - l.start, st.meter), l.station)
		if rank[q] > rank[best] then
			best = q
		end
	end
	return best
end

local function bob(l: Lifting, good: boolean)
	local weld = l.weld
	if not weld then
		return
	end
	local base = weld.C0
	local up = if good then base * CFrame.new(0, 1.4, 0) else base * CFrame.Angles(0, 0, 0.35)
	local t = TweenService:Create(weld, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { C0 = up })
	t:Play()
	t.Completed:Once(function()
		if weld.Parent then
			TweenService:Create(weld, TweenInfo.new(0.22, Enum.EasingStyle.Bounce), { C0 = base }):Play()
		end
	end)
end

-- One rep. Returns the strength gained and the quality ("perfect" | "good" | "miss" | "" refused).
function Gym.lift(player: Player, at: number?): (number, string)
	local s = State.get(player)
	local l = lifting[player]
	if not s or not l then
		return 0, ""
	end
	local clock = os.clock()
	if clock - s.lastLift < Economy.LiftInterval * 0.85 then
		return 0, ""
	end
	s.lastLift = clock
	local q = quality(player, l, at or now())
	if q == "perfect" then
		l.combo += 1
	elseif q == "miss" then
		l.combo = 0
	end
	local mult = if s.passes.DoubleStrength then Economy.PassEffects.DoubleStrength else 1
	local gain = Progression.liftReward(l.station, q, math.max(0, l.combo - 1), s.data.Rebirths, mult)
	if gain > 0 then
		s.data.Strength += gain
		s.data.Stats.Lifts += 1
		Stats.sync(player)
	end
	bob(l, gain > 0)
	Net.fire(player, Remotes.Names.Lifted, gain, q, l.combo)
	return gain, q
end

function Gym.start(w: any)
	world = w
	for i, part in world.stations do
		local prompt = part:FindFirstChild("LiftPrompt") :: ProximityPrompt?
		if prompt then
			prompt.Triggered:Connect(function(player)
				if lifting[player] then
					Gym.stop(player)
				else
					Gym.begin(player, i)
				end
			end)
		end
	end
	local limit = RateLimit.new(1 / Economy.LiftInterval * 1.6, 4)
	Net.on(Remotes.Names.Lift, function(player)
		if limit(player) then
			Gym.lift(player)
		end
	end)
	Net.on(Remotes.Names.GymStop, function(player)
		Gym.stop(player)
	end)
	-- walked away / teleported / died: put it down
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, l in table.clone(lifting) do
				local pos = State.root(player)
				local part = stationPart(l.station)
				if
					not State.get(player)
					or not pos
					or not part
					or (part.Position - pos).Magnitude > Economy.GymRange + 8
				then
					Gym.stop(player)
				end
			end
		end
	end)
end

function Gym.onLeaving(player: Player)
	lifting[player] = nil
end

return Gym
