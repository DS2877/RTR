--!strict
-- TOP DOG: the richest prisoner on the server (most Noodles) wears a gold chain and is shown on
-- the TOP DOG board in the Common Room. LONGEST TUNNEL board: this server's deepest tunnels plus
-- the all-time top list (OrderedDataStore).

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
	-- LONGEST TUNNEL: this server + all time
	local here = {}
	for player, s in State.all() do
		table.insert(here, { name = (player :: any).Name, depth = s.data.MaxDepth })
	end
	table.sort(here, function(a, b)
		return a.depth > b.depth
	end)
	local lines = { "THIS PRISON" }
	for i = 1, math.min(3, #here) do
		table.insert(lines, string.format("%d. %s  %dm", i, here[i].name, here[i].depth))
	end
	table.insert(lines, "ALL TIME")
	for i = 1, math.min(5, #allTime) do
		table.insert(lines, string.format("%d. %s  %dm", i, allTime[i].name, allTime[i].depth))
	end
	local depthBody = world.boards.Depth:FindFirstChild("Body") :: TextLabel
	depthBody.Text = table.concat(lines, "\n")
end

local function saveDepth(player: Player)
	local s = State.get(player)
	if not s or not depthStore or typeof(player) ~= "Instance" then
		return
	end
	local depth = s.data.MaxDepth
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

local nameCache: { [number]: string } = {}
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
	if current == player then
		current = nil
	end
end

function TopDog.start(w: any)
	world = w
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("DigOut_Depth_v1")
	end)
	depthStore = if ok then store else nil
	task.spawn(function()
		local tick = 0
		while true do
			pcall(TopDog.update)
			tick += 1
			if tick % 24 == 1 then -- every ~2 minutes
				for player in State.all() do
					saveDepth(player)
				end
				refreshAllTime()
			end
			task.wait(5)
		end
	end)
end

return TopDog
