--!strict
-- The gym in the Yard: stand next to a station and tap LIFT. Time is the cost.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Stats = require(script.Parent.Stats)

local Gym = {}

local world: any = nil

-- Returns the strength gained (0 = refused).
function Gym.lift(player: Player): number
	local s = State.get(player)
	local root = State.root(player)
	if not s or not root then
		return 0
	end
	local now = os.clock()
	if now - s.lastLift < Economy.LiftInterval * 0.85 then
		return 0
	end
	local best: number? = nil
	for _, station in world.stations do
		if (station.Position - root).Magnitude <= Economy.GymRange + 3 then
			best = station:GetAttribute("Station")
			break
		end
	end
	if not best then
		return 0
	end
	local st = Economy.Gym[best]
	if s.data.Strength < st.minStrength then
		Net.notice(player, string.format("You need %d 💪 for the %s", st.minStrength, st.name), "bad")
		return 0
	end
	s.lastLift = now
	local mult = if s.passes.DoubleStrength then Economy.PassEffects.DoubleStrength else 1
	local gain = Progression.liftGain(best, s.data.Rebirths, mult)
	s.data.Strength += gain
	s.data.Stats.Lifts += 1
	Net.fire(player, Remotes.Names.Lifted, gain)
	Stats.sync(player)
	return gain
end

function Gym.start(w: any)
	world = w
	local limit = RateLimit.new(1 / Economy.LiftInterval * 1.5, 4)
	Net.on(Remotes.Names.Lift, function(player)
		if limit(player) then
			Gym.lift(player)
		end
	end)
end

return Gym
