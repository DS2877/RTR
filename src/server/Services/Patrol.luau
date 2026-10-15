--!strict
-- Patrolling guards (Config/Patrol): the server picks what each guard says, based on who is near
-- them and what that prisoner is up to (stolen loot, fighting, digging, a bulging backpack,
-- lifting) - and the guard always has a reason not to see it. Positions come from Shared/Patrol
-- (server time), so clients render the walking themselves; a line is published as attributes on
-- ReplicatedStorage.Patrol ("Say<i>" text, "SayAt<i>" server time).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Patrol)
local PatrolMath = require(Shared.Patrol)

local State = require(script.Parent.Parent.State)
local Stats = require(script.Parent.Stats)

local Patrol = {}

Patrol.phase = function(): string
	return "Day"
end

local folder: Folder? = nil
local recent: { [string]: number } = {} -- line -> when it was last said (avoid repeats)

local function pick(kind: string, name: string?): string
	local list = Config.Lines[kind] or Config.Lines.Day
	local best, bestAge = list[1], -1
	local now = os.clock()
	-- a few random tries, prefer the line not heard for the longest time
	for _ = 1, 4 do
		local line = list[math.random(1, #list)]
		local age = now - (recent[line] or -1e9)
		if age > bestAge then
			best, bestAge = line, age
		end
	end
	recent[best] = now
	return (string.gsub(best, "{name}", name or "inmate"))
end

-- What this guard should talk about right now, and about whom.
function Patrol.situation(pos: Vector3, phase: string): (string, string?)
	local nearest: Player? = nil
	local nearestDist = Config.HearRange
	local nowClock = os.clock()
	local best: string? = nil
	local bestRank = 0
	local who: string? = nil
	local rank = { Stolen = 6, Fight = 5, Digging = 4, Bag = 3, Lifting = 2 }
	for player, s in State.all() do
		local root = State.root(player)
		if root then
			local d = (root - pos).Magnitude
			local name = if typeof(player) == "Instance" then player.DisplayName else "inmate"
			local function consider(kind: string, range: number)
				if d <= range and rank[kind] > bestRank then
					best, bestRank, who = kind, rank[kind], name
				end
			end
			local attr = function(a: string): any
				return if typeof(player) == "Instance" then player:GetAttribute(a) else nil
			end
			if attr("Carrying") == true then
				consider("Stolen", Config.HearRange)
			end
			if nowClock - s.lastHitAt < 6 or nowClock - s.lastBrawl < 6 then
				consider("Fight", Config.HearRange)
			end
			if nowClock - s.lastPunch < 3 then
				consider("Digging", Config.HearRange * 1.6)
			end
			if s.data.Bag >= 10 and s.data.Bag >= Stats.capacity(s) * 0.6 then
				consider("Bag", Config.HearRange * 0.7)
			end
			if attr("Lifting") ~= nil then
				consider("Lifting", Config.HearRange)
			end
			if d < nearestDist then
				nearest, nearestDist = player, d
			end
		end
	end
	if best then
		return best, who
	end
	if nearest and math.random() < 0.4 then
		return "Near", (nearest :: Player).DisplayName
	end
	return phase, nil
end

local function say(i: number, text: string)
	local f = folder
	if f then
		f:SetAttribute("Say" .. i, text)
		f:SetAttribute("SayAt" .. i, workspace:GetServerTimeNow())
	end
end

function Patrol.start()
	local f = Instance.new("Folder")
	f.Name = "Patrol"
	f.Parent = ReplicatedStorage
	folder = f
	for i in Config.Guards do
		task.spawn(function()
			task.wait(2 + i * 3)
			while true do
				local phase = Patrol.phase()
				local pose = PatrolMath.guard(i, phase, workspace:GetServerTimeNow())
				local kind, name = Patrol.situation(Vector3.new(pose.x, 3, pose.z), phase)
				say(i, pick(kind, name))
				task.wait(math.random(Config.SayEvery[1] * 10, Config.SayEvery[2] * 10) / 10)
			end
		end)
	end
end

return Patrol
