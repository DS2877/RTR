--!strict
-- Stand on your own treadmill to earn speed points. Standing still is enough (AFK-friendly on a
-- phone): your character plays a run animation and the belt stripes scroll (both client side).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local Movement = require(script.Parent.Movement)

local Treadmill = {}

local TICK = 0.25
local POPUP_EVERY = 0.5

function Treadmill.onBelt(base: any, pos: Vector3): boolean
	local belt = base.belt :: BasePart
	local l = belt.CFrame:PointToObjectSpace(pos)
	return math.abs(l.X) <= belt.Size.X / 2 + 0.5 and math.abs(l.Z) <= belt.Size.Z / 2 and l.Y > 0 and l.Y < 7
end

function Treadmill.start(_worldInfo: any)
	local buffered: { [Player]: number } = {}
	local sincePopup = 0
	task.spawn(function()
		while true do
			local dt = task.wait(TICK)
			sincePopup += dt
			for player, s in State.all() do
				local r = State.root(player)
				if s.base and r and not s.carry and Treadmill.onBelt(s.base, r.Position) then
					local rate = Progression.treadmillRate(s.data.Treadmill)
						* (if s.passes.DoubleSpeed then 2 else 1)
					local gain = rate * dt
					s.data.Speed += gain
					buffered[player] = (buffered[player] or 0) + gain
					Movement.refresh(player)
				end
			end
			if sincePopup >= POPUP_EVERY then
				sincePopup = 0
				for player, amount in buffered do
					if player.Parent then
						Net.fire(player, Remotes.Names.SpeedTick, amount)
					end
				end
				table.clear(buffered)
			end
		end
	end)
end

return Treadmill
