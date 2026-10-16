--!strict
-- WORK DETAIL (Config/Missions, Shared/Missions): three daily jobs + a bonus for all three.
-- Other services report what happened through Missions.count (wired in init.server); progress
-- resets at 00:00 UTC. The client reads the "Missions" attribute (JSON) and claims with
-- ClaimMission (server checks completion; rewards are Noodles with known amounts).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Missions)
local Zones = require(Shared.Config.Zones)
local Pick = require(Shared.Missions)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Loot = require(script.Parent.Loot)

local Missions = {}

export type Data = { Day: number, Progress: { number }, Claimed: { boolean }, Bonus: boolean }

local function today(): number
	return os.time() // 86400
end

local function zoneValue(s: State.PlayerState): number
	return Zones[math.clamp(s.data.Zone, 1, #Zones)].rubble
end

local function ensure(s: State.PlayerState): Data
	local d = s.data :: any
	local m = d.Missions
	if typeof(m) ~= "table" then
		m = { Day = 0, Progress = {}, Claimed = {}, Bonus = false }
		d.Missions = m
	end
	local t = today()
	if m.Day ~= t then
		m.Day = t
		m.Progress = { 0, 0, 0 }
		m.Claimed = { false, false, false }
		m.Bonus = false
	end
	return m
end

function Missions.list(s: State.PlayerState): { Pick.Picked }
	local atBottom = s.data.MaxDepth >= Progression.diggableDepth() - 20
	return Pick.pick(today(), s.data.Seed, atBottom)
end

function Missions.sync(player: Player)
	local s = State.get(player)
	if not s or typeof(player) ~= "Instance" then
		return
	end
	local m = ensure(s)
	local zv = zoneValue(s)
	local items = {}
	for i, job in Missions.list(s) do
		table.insert(items, {
			text = job.text,
			emoji = job.emoji,
			goal = job.goal,
			progress = math.min(job.goal, m.Progress[i] or 0),
			claimed = m.Claimed[i] == true,
			reward = job.reward * zv,
		})
	end
	player:SetAttribute(
		"Missions",
		HttpService:JSONEncode({
			items = items,
			bonus = m.Bonus,
			bonusReward = Config.BonusBlocks * zv,
			resets = (today() + 1) * 86400,
		})
	)
end

-- Something happened: `stat` went up by n (Blocks, Finds, Dumps, Lifts, Perfects, Crits, Depth, Sells).
function Missions.count(player: Player, stat: string, n: number?)
	local s = State.get(player)
	if not s then
		return
	end
	local m = ensure(s)
	local changed = false
	for i, job in Missions.list(s) do
		local p = m.Progress[i] or 0
		if job.stat == stat and p < job.goal then
			m.Progress[i] = math.min(job.goal, p + (n or 1))
			changed = true
			if m.Progress[i] >= job.goal then
				Net.fire(player, Remotes.Names.MissionDone, i)
			end
		end
	end
	if changed then
		Missions.sync(player)
	end
end

-- index 1..3 = a job, 4 = the all-three bonus. Returns the Noodles paid (0 = refused).
function Missions.claim(player: Player, index: number): number
	local s = State.get(player)
	if not s then
		return 0
	end
	local m = ensure(s)
	local list = Missions.list(s)
	local pay = 0
	if index >= 1 and index <= #list then
		local job = list[index]
		if m.Claimed[index] or (m.Progress[index] or 0) < job.goal then
			return 0
		end
		m.Claimed[index] = true
		pay = job.reward * zoneValue(s)
	elseif index == 4 then
		for i = 1, #list do
			if not m.Claimed[i] then
				return 0
			end
		end
		if m.Bonus then
			return 0
		end
		m.Bonus = true
		pay = Config.BonusBlocks * zoneValue(s)
	else
		return 0
	end
	Loot.addNoodles(player, pay)
	Net.notice(player, "Work detail paid " .. Format.noodles(pay), "cash")
	Missions.sync(player)
	return pay
end

function Missions.start()
	local limit = RateLimit.new(3, 6)
	Net.on(Remotes.Names.ClaimMission, function(player, index)
		if limit(player) and typeof(index) == "number" and index % 1 == 0 then
			Missions.claim(player, index)
		end
	end)
end

return Missions
