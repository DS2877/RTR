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
local decks: { [string]: { string } } = {} -- per list: lines not said yet (a shuffled deck)
local lastSaid: { [string]: string } = {}

-- Draws the next line from a list's deck: every line is said once before any repeats.
local function draw(key: string, list: { string }): string
	local deck = decks[key]
	if not deck or #deck == 0 then
		deck = table.clone(list)
		for i = #deck, 2, -1 do
			local j = math.random(1, i)
			deck[i], deck[j] = deck[j], deck[i]
		end
		-- never the same line twice in a row across a reshuffle
		if #deck > 1 and deck[#deck] == lastSaid[key] then
			deck[1], deck[#deck] = deck[#deck], deck[1]
		end
		decks[key] = deck
	end
	local line = table.remove(deck) :: string
	lastSaid[key] = line
	return line
end

local function pick(kind: string, name: string?, guard: number?): string
	local list = Config.Lines[kind] or Config.Lines.Day
	local key = kind
	local spec = guard and Config.Guards[guard]
	-- idle moments: sometimes the guard's own quirks instead
	if name == nil and spec and spec.quirks and math.random() < Config.QuirkChance then
		list, key = spec.quirks, "quirk" .. guard
	end
	return (string.gsub(draw(key, list), "{name}", name or "inmate"))
end

-- What this guard should talk about right now, and about whom.
function Patrol.situation(pos: Vector3, phase: string): (string, string?)
	local nearest: Player? = nil
	local nearestDist = Config.HearRange
	local nowClock = os.clock()
	local best: string? = nil
	local bestRank = 0
	local who: string? = nil
	local rank = { Stolen = 6, Fight = 5, Digging = 4, Bag = 3, Lifting = 2, TopDog = 1 }
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
			-- (0 = never: os.clock() starts near 0 on a fresh server)
			if
				(s.lastHitAt > 0 and nowClock - s.lastHitAt < 6)
				or (s.lastBrawl > 0 and nowClock - s.lastBrawl < 6)
			then
				consider("Fight", Config.HearRange)
			end
			if s.lastPunch > 0 and nowClock - s.lastPunch < 3 then
				consider("Digging", Config.HearRange * 1.6)
			end
			if s.data.Bag >= 10 and s.data.Bag >= Stats.capacity(s) * 0.6 then
				consider("Bag", Config.HearRange * 0.7)
			end
			if attr("Lifting") ~= nil then
				consider("Lifting", Config.HearRange)
			end
			if attr("TopDog") == true and math.random() < 0.5 then
				consider("TopDog", Config.HearRange)
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
				local ok, err = pcall(function()
					local phase = Patrol.phase()
					local pose = PatrolMath.guard(i, phase, workspace:GetServerTimeNow())
					local kind, name = Patrol.situation(Vector3.new(pose.x, 3, pose.z), phase)
					say(i, pick(kind, name, i))
					task.wait(math.random(Config.SayEvery[1] * 10, Config.SayEvery[2] * 10) / 10)
				end)
				if not ok then
					warn("[Patrol] loop:", err)
					task.wait(1)
				end
			end
		end)
	end
end

return Patrol
