--!strict
-- TOP DOG: the richest prisoner on the server (most Noodles) wears a gold chain and is shown on
-- the TOP DOG board in the Common Room. LONGEST TUNNEL board: this server's deepest tunnels plus
-- the all-time top list (OrderedDataStore). THIS WEEK board: blocks broken since Monday 00:00
-- UTC across every server (one OrderedDataStore scope per week); last week's top 10 wear a
-- crown tag over their heads all week.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)

local TopDog = {}

local world: any = nil
local current: Player? = nil
local depthStore: OrderedDataStore? = nil
local allTime: { { name: string, depth: number } } = {}

-- the ESCAPE ARTISTS score: escapes rank first, this run's depth breaks ties
local function escapeScore(s: State.PlayerState): number
	return s.data.Rebirths * 1000 + math.min(999, s.data.RunDepth)
end

local function scoreText(score: number): string
	local escapes, depth = score // 1000, score % 1000
	return if escapes > 0 then string.format("🏃%d · %dm", escapes, depth) else string.format("%dm", depth)
end
local lastSaved: { [number]: number } = {}

local GOLD = Color3.fromRGB(232, 178, 52)

local function chain(character: Model)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") or character:FindFirstChild("TopDogChain") then
		return
	end
	local m = Instance.new("Model")
	m.Name = "TopDogChain"
	local links = 12
	for i = 0, links - 1 do
		local a = i / links * math.pi * 2
		local link = Instance.new("Part")
		link.Name = "Link"
		link.Size = Vector3.new(0.24, 0.24, 0.24)
		-- polished gold (Neon + bloom made the chain a glowing blob)
		link.Material = Enum.Material.SmoothPlastic
		link.Reflectance = 0.2
		link.Color = GOLD
		link.CanCollide = false
		link.CanQuery = false
		link.CanTouch = false
		link.Massless = true
		link.CastShadow = false
		-- a loop hanging around the neck, lower in front
		link.CFrame = torso.CFrame
			* CFrame.new(math.sin(a) * 0.9, 0.75 - (1 + math.cos(a)) * 0.35, -math.cos(a) * 0.6)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = link
		weld.Parent = link
		link.Parent = m
	end
	local medal = Instance.new("Part")
	medal.Name = "Medal"
	medal.Shape = Enum.PartType.Cylinder
	medal.Size = Vector3.new(0.12, 0.6, 0.6)
	medal.Material = Enum.Material.SmoothPlastic
	medal.Reflectance = 0.25
	medal.Color = GOLD
	medal.CanCollide = false
	medal.CanQuery = false
	medal.Massless = true
	medal.CFrame = torso.CFrame * CFrame.new(0, 0.05, -0.62) * CFrame.Angles(0, math.pi / 2, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = medal
	weld.Parent = medal
	medal.Parent = m
	m.Parent = character
end

local function unchain(player: Player)
	local c = player.Character
	local m = c and c:FindFirstChild("TopDogChain")
	if m then
		m:Destroy()
	end
end

function TopDog.current(): Player?
	return current
end

function TopDog.update()
	local best: Player? = nil
	local bestNoodles = -1
	for player, s in State.all() do
		if typeof(player) == "Instance" and s.data.Noodles > bestNoodles then
			best, bestNoodles = player, s.data.Noodles
		end
	end
	if best ~= current then
		if current and current.Parent then
			current:SetAttribute("TopDog", false)
			unchain(current)
		end
		current = best
		if best then
			best:SetAttribute("TopDog", true)
			if bestNoodles > 0 then
				Net.announce(best.Name .. " is the new TOP DOG! 🐶", { 255, 205, 60 }, nil)
			end
		end
	end
	if current and current.Character then
		chain(current.Character)
	end
	local top = world.boards.TopDog:FindFirstChild("Body") :: TextLabel
	top.Text = if current
		then string.format("%s\n🍜 %s", current.Name, Format.number(bestNoodles))
		else "nobody yet"
	-- ESCAPE ARTISTS: escapes first, then this run's depth (score = escapes * 1000 + depth);
	-- this server + all time
	local here = {}
	for player, s in State.all() do
		table.insert(here, { name = (player :: any).Name, depth = escapeScore(s) })
	end
	table.sort(here, function(a, b)
		return a.depth > b.depth
	end)
	local lines = { "THIS PRISON" }
	for i = 1, math.min(3, #here) do
		table.insert(lines, string.format("%d. %s  %s", i, here[i].name, scoreText(here[i].depth)))
	end
	table.insert(lines, "ALL TIME")
	for i = 1, math.min(5, #allTime) do
		table.insert(lines, string.format("%d. %s  %s", i, allTime[i].name, scoreText(allTime[i].depth)))
	end
	local depthBody = world.boards.Depth:FindFirstChild("Body") :: TextLabel
	depthBody.Text = table.concat(lines, "\n")
end

local function saveDepth(player: Player)
	local s = State.get(player)
	if not s or not depthStore or typeof(player) ~= "Instance" then
		return
	end
	local depth = escapeScore(s)
	if depth <= 0 or lastSaved[player.UserId] == depth then
		return
	end
	lastSaved[player.UserId] = depth
	local store = depthStore
	task.spawn(function()
		pcall(function()
			store:SetAsync(tostring(player.UserId), depth)
		end)
	end)
end

-- ===== the weekly race =====

local WEEK = 7 * 86400
-- weeks start on Monday 00:00 UTC (the epoch was a Thursday)
function TopDog.week(t: number?): number
	return ((t or os.time()) + 3 * 86400) // WEEK
end

function TopDog.weekEnds(): number
	return (TopDog.week() + 1) * WEEK - 3 * 86400
end

-- Dig.onBroken: count blocks for this week (a new week starts the count over).
function TopDog.countBlocks(player: any, n: number)
	local s = State.get(player)
	if not s or n <= 0 then
		return
	end
	local w = s.data.Week
	local now = TopDog.week()
	if w.Id ~= now then
		w.Id, w.Blocks = now, 0
	end
	w.Blocks += n
end

local weekStores: { [number]: OrderedDataStore } = {}
local function weekStore(week: number): OrderedDataStore?
	if weekStores[week] then
		return weekStores[week]
	end
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("DigOut_Week_v1", tostring(week))
	end)
	if ok and store then
		weekStores[week] = store
		return store
	end
	return nil
end

local weekSaved: { [number]: number } = {}
local function saveWeek(player: any)
	local s = State.get(player)
	if not s or typeof(player) ~= "Instance" then
		return
	end
	local w = s.data.Week
	if w.Id ~= TopDog.week() or w.Blocks <= 0 or weekSaved[player.UserId] == w.Blocks then
		return
	end
	weekSaved[player.UserId] = w.Blocks
	local store = weekStore(w.Id)
	local blocks = w.Blocks
	if store then
		task.spawn(function()
			pcall(function()
				store:SetAsync(tostring(player.UserId), blocks)
			end)
		end)
	end
end

local nameCache: { [number]: string } = {}
local function nameOf(id: number): string
	local name = nameCache[id]
	if not name then
		local ok, n = pcall(function()
			return game:GetService("Players"):GetNameFromUserIdAsync(id)
		end)
		name = if ok and n then n else "?"
		nameCache[id] = name
	end
	return name :: string
end

local thisWeek: { { name: string, blocks: number } } = {}
local lastWeekRank: { [number]: number } = {} -- userId -> rank (1..10) last week
local function refreshWeek()
	local store = weekStore(TopDog.week())
	if store then
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, 8)
		end)
		if ok and pages then
			local list = {}
			for _, entry in (pages :: DataStorePages):GetCurrentPage() do
				table.insert(list, { name = nameOf(tonumber(entry.key) or 0), blocks = entry.value })
			end
			thisWeek = list
		end
	end
	local last = weekStore(TopDog.week() - 1)
	if last then
		local ok, pages = pcall(function()
			return last:GetSortedAsync(false, 10)
		end)
		if ok and pages then
			local ranks = {}
			for i, entry in (pages :: DataStorePages):GetCurrentPage() do
				ranks[tonumber(entry.key) or 0] = i
			end
			lastWeekRank = ranks
		end
	end
end

-- last week's top 10: a crown tag over the head ("👑 #1 LAST WEEK")
local function crown(player: Player)
	local rank = lastWeekRank[player.UserId]
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not rank or not head or head:FindFirstChild("WeekCrown") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "WeekCrown"
	gui.Size = UDim2.fromOffset(150, 22)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.GothamBlack
	l.TextSize = 14
	l.TextStrokeTransparency = 0.3
	l.TextColor3 = if rank == 1
		then Color3.fromRGB(255, 205, 60)
		elseif rank <= 3 then Color3.fromRGB(215, 220, 230)
		else Color3.fromRGB(240, 240, 240)
	l.Text = string.format("%s #%d LAST WEEK", if rank <= 3 then "👑" else "🏆", rank)
	l.Parent = gui
	gui.Parent = head
end

local function paintWeek()
	local body = world.boards.Week and world.boards.Week:FindFirstChild("Body") :: TextLabel?
	if not body then
		return
	end
	local left = math.max(0, TopDog.weekEnds() - os.time())
	local lines = {
		string.format("BLOCKS BROKEN · new week in %dd %dh", left // 86400, (left % 86400) // 3600),
	}
	if #thisWeek == 0 then
		table.insert(lines, "be the first!")
	end
	for i, e in thisWeek do
		table.insert(lines, string.format("%d. %s  %s", i, e.name, Format.number(e.blocks)))
	end
	body.Text = table.concat(lines, "\n")
end

local function refreshAllTime()
	local store = depthStore
	if not store then
		return
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, 5)
	end)
	if not ok or not pages then
		return
	end
	local list = {}
	for _, entry in (pages :: DataStorePages):GetCurrentPage() do
		local id = tonumber(entry.key) or 0
		local name = nameCache[id]
		if not name then
			local okName, n = pcall(function()
				return game:GetService("Players"):GetNameFromUserIdAsync(id)
			end)
			name = if okName and n then n else "?"
			nameCache[id] = name
		end
		table.insert(list, { name = name :: string, depth = entry.value })
	end
	allTime = list
end

function TopDog.onLeaving(player: Player)
	saveDepth(player)
	saveWeek(player)
	lastSaved[player.UserId] = nil
	weekSaved[player.UserId] = nil
	if current == player then
		current = nil
	end
end

function TopDog.start(w: any)
	world = w
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("DigOut_Escapes_v1")
	end)
	depthStore = if ok then store else nil
	task.spawn(function()
		local tick = 0
		while true do
			local ok, err = pcall(function()
				pcall(TopDog.update)
				tick += 1
				if tick % 24 == 1 then -- every ~2 minutes
					for player in State.all() do
						saveDepth(player)
						saveWeek(player)
					end
					refreshAllTime()
					pcall(refreshWeek)
				end
				pcall(paintWeek)
				for player in State.all() do
					if typeof(player) == "Instance" then
						pcall(crown, player)
					end
				end
				task.wait(5)
			end)
			if not ok then
				warn("[TopDog] loop:", err)
				task.wait(1)
			end
		end
	end)
end

return TopDog
