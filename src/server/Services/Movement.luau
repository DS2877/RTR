--!strict
-- Walk speed is always decided here: treadmill points -> speed, then slow mode, carry weight, stun.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Progression)
local Economy = require(Shared.Config.Economy)
local State = require(script.Parent.Parent.State)

local Movement = {}

function Movement.refresh(player: Player)
	local s = State.get(player)
	local h = State.humanoid(player)
	if not s or not h then
		return
	end
	local speed = Progression.walkSpeed(s.data.Speed)
	player:SetAttribute("WalkSpeedStat", speed)
	player:SetAttribute("SpeedPoints", s.data.Speed)
	if s.slowMode then
		speed = math.min(speed, Economy.Speed.SlowMode)
	end
	local carry = s.carry
	if carry then
		local info = Progression.item(carry.id)
		local mult = if info then Economy.CarrySlowdown[info.rarity] else 0.9
		speed *= mult or 0.9
	end
	if os.clock() < s.stunUntil then
		speed = 0
	end
	h.WalkSpeed = speed
end

function Movement.stun(player: Player, seconds: number)
	local s = State.get(player)
	if not s then
		return
	end
	s.stunUntil = os.clock() + seconds
	Movement.refresh(player)
	task.delay(seconds + 0.05, function()
		Movement.refresh(player)
	end)
end

return Movement
