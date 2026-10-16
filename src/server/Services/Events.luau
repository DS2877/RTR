--!strict
-- Server events (Config/Cycle.Events), random every EventMin..EventMax seconds or by admin:
--   BLACKOUT        all walls 2x weaker
--   RIOT            (night) the doors stay open
--   INSPECTION DAY  (day) be in your own cell with an empty backpack when it ends: bonus Noodles
--   TREASURE RACE   a mega find at the same depth in every tunnel: the first to dig to it wins
--   GOLD RUSH       finds are way more common
--   PAYDAY          dumping and flushing pay double
--   EARTHQUAKE      the ground shakes: a chunk of blocks breaks at the front of every tunnel
--   SUPPLY DROP     (day) a crate parachutes into the Yard: the first to grab it gets the prize

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Cycle = require(Shared.Config.Cycle)
local World = require(Shared.Config.World)
local Zones = require(Shared.Config.Zones)
local Finds = require(Shared.Config.Finds)
local Voxel = require(Shared.Voxel)
local Progression = require(Shared.Progression)
local Tunnel = require(Shared.Tunnel)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local Dig = require(script.Parent.Dig)
local Loot = require(script.Parent.Loot)
local Build = require(script.Parent.Parent.Util.Build)

local Events = {}

Events.phase = function(): string
	return "Day"
end
Events.onRiot = nil :: ((on: boolean) -> ())?

local current: string? = nil
local endsAt = 0
local treasure: { [any]: number } = {} -- player -> block index of their treasure
local last: string? = nil
local crate: Model? = nil

function Events.current(): string?
	return current
end

function Events.riot(): boolean
	return current == "RIOT"
end

local function finish()
	local id = current
	if not id then
		return
	end
	current = nil
	Dig.globalBoost = 1
	Dig.eventBonus = 0
	Loot.eventMult = 1
	if crate then
		crate:Destroy()
		crate = nil
	end
	if id == "RIOT" and Events.onRiot then
		Events.onRiot(false)
	end
	ReplicatedStorage:SetAttribute("Event", "")
	Remotes.get(Remotes.Names.Event):FireAllClients("", 0)
	if id == "INSPECTION" then
		local blocks = Cycle.InspectionDayBlocks
		for player, s in State.all() do
			local pos = State.root(player)
			if pos and s.cell and Tunnel.cellAt(pos) == s.cell and s.data.Bag == 0 then
				local amount = blocks * Zones[math.clamp(s.data.Zone, 1, #Zones)].rubble
				Loot.addNoodles(player, amount)
				Net.notice(player, "Tidy cell bonus! +" .. Format.noodles(amount), "cash")
			end
		end
	elseif id == "TREASURE" then
		for player in treasure do
			Net.fire(player, Remotes.Names.Treasure, nil)
		end
		treasure = {}
	end
end

-- The treasure block in this player's tunnel: the first solid block at depth >= target.
local function placeTreasure(player: Player, s: State.PlayerState, depth: number)
	local g = s.grid
	if not g then
		return
	end
	local mid = World.TunnelWidth // 2
	for z = depth, Progression.diggableDepth() - 1 do
		if not Progression.chamberAt(mid, 1, z) and Voxel.isSolid(g, mid, 1, z) then
			treasure[player] = Voxel.index(g, mid, 1, z)
			Net.fire(player, Remotes.Names.Treasure, mid, 1, z)
			return
		end
	end
end

-- EARTHQUAKE: breaks up to QuakeBlocks exposed blocks at the front of this player's tunnel.
local function quake(player: Player, s: State.PlayerState): number
	local g = s.grid
	if not g then
		return 0
	end
	local maxZ = Progression.diggableDepth()
	local candidates = {}
	local front = s.data.MaxDepth
	for z = math.max(0, front - 3), math.min(front + 1, maxZ - 1) do
		for y = 0, World.TunnelHeight - 1 do
			for x = 0, World.TunnelWidth - 1 do
				if
					Voxel.isSolid(g, x, y, z)
					and Voxel.isExposed(g, x, y, z)
					and not Progression.chamberAt(x, y, z)
				then
					table.insert(candidates, { x, y, z })
				end
			end
		end
	end
	for i = #candidates, 2, -1 do
		local j = math.random(1, i)
		candidates[i], candidates[j] = candidates[j], candidates[i]
	end
	local targets = {}
	for i = 1, math.min(Cycle.QuakeBlocks, #candidates) do
		targets[i] = candidates[i]
	end
	if #targets == 0 then
		return 0
	end
	return Dig.applyHits(player, s, targets, math.huge)
end

-- SUPPLY DROP: the first player to grab the crate wins. Returns the prize (0 = refused).
function Events.claimCrate(player: Player): number
	local c = crate
	local s = State.get(player)
	local pos = State.root(player)
	if current ~= "SUPPLYDROP" or not c or not s or not pos then
		return 0
	end
	local box = c.PrimaryPart
	if not box or (box.Position - pos).Magnitude > 16 then
		return 0
	end
	local amount = Cycle.SupplyBlocks * Zones[math.clamp(s.data.Zone, 1, #Zones)].rubble
	Loot.addNoodles(player, amount)
	Net.announce(
		string.format("%s grabbed the SUPPLY DROP! +%s", player.Name, Format.noodles(amount)),
		{ 255, 215, 60 },
		"Zone"
	)
	finish()
	return amount
end

local function dropCrate()
	local dump = CollectionService:GetTagged("Dump")[1]
	if not dump or not dump:IsA("BasePart") then
		return
	end
	local spot =
		Vector3.new(dump.Position.X + math.random(-30, 30), 0, dump.Position.Z + math.random(-18, 18))
	local m = Instance.new("Model")
	m.Name = "SupplyDrop"
	local box = Build.part(
		m,
		"Crate",
		Vector3.new(4, 4, 4),
		CFrame.new(spot + Vector3.new(0, 80, 0)),
		Color3.fromRGB(150, 110, 60),
		{
			Material = Enum.Material.WoodPlanks,
		}
	)
	for _, off in
		{
			Vector3.new(0, 0, 2.05),
			Vector3.new(0, 0, -2.05),
			Vector3.new(2.05, 0, 0),
			Vector3.new(-2.05, 0, 0),
		}
	do
		local band = Build.part(
			m,
			"Band",
			Vector3.new(if off.X ~= 0 then 0.1 else 4.1, 0.5, if off.Z ~= 0 then 0.1 else 4.1),
			box.CFrame + off,
			Color3.fromRGB(60, 60, 66),
			{
				Material = Enum.Material.Metal,
				CanCollide = false,
			}
		)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = box
		weld.Part1 = band
		weld.Parent = band
		band.Anchored = false
		band.Massless = true
	end
	local chute = Build.part(
		m,
		"Parachute",
		Vector3.new(9, 3, 9),
		box.CFrame * CFrame.new(0, 7, 0),
		Color3.fromRGB(255, 140, 50),
		{
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Fabric,
			CanCollide = false,
			Transparency = 0.05,
		}
	)
	local cw = Instance.new("WeldConstraint")
	cw.Part0 = box
	cw.Part1 = chute
	cw.Parent = chute
	chute.Anchored = false
	chute.Massless = true
	m.PrimaryPart = box
	-- a marker everyone sees through walls
	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(110, 26)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.LightInfluence = 0
	bb.Parent = box
	local pill = Instance.new("TextLabel")
	pill.Size = UDim2.fromScale(1, 1)
	pill.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
	pill.BackgroundTransparency = 0.3
	pill.Text = "📦 SUPPLY DROP"
	pill.Font = Enum.Font.GothamBold
	pill.TextSize = 12
	pill.TextColor3 = Color3.fromRGB(255, 214, 90)
	pill.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = pill
	local prompt = Build.prompt(box, "Grab", "Supply Drop", 12)
	prompt.Triggered:Connect(function(player)
		Events.claimCrate(player)
	end)
	m.Parent = workspace
	crate = m
	-- parachutes down, then the chute collapses
	TweenService:Create(box, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(spot + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.random() * 6, 0),
	}):Play()
	task.delay(5.2, function()
		if chute.Parent then
			chute:Destroy()
		end
	end)
end

-- (smoke test) the supply crate, if one is out
function Events.crate(): Model?
	return crate
end

-- Starts an event now. Returns false if the id is unknown or another event runs.
function Events.trigger(id: string): boolean
	local cfg = Cycle.Events[id]
	if not cfg or current then
		return false
	end
	current = id
	last = id
	endsAt = os.clock() + cfg.seconds
	ReplicatedStorage:SetAttribute("Event", id)
	ReplicatedStorage:SetAttribute("EventEnds", workspace:GetServerTimeNow() + cfg.seconds)
	Remotes.get(Remotes.Names.Event):FireAllClients(id, cfg.seconds)
	Net.announce(cfg.name .. "! " .. cfg.text, { 255, 120, 60 }, "Siren")
	if id == "BLACKOUT" then
		Dig.globalBoost = 2
	elseif id == "GOLDRUSH" then
		Dig.eventBonus = Cycle.GoldRushBonus
	elseif id == "PAYDAY" then
		Loot.eventMult = Cycle.PaydayMult
	elseif id == "EARTHQUAKE" then
		for player, s in State.all() do
			quake(player, s)
		end
	elseif id == "SUPPLYDROP" then
		dropCrate()
	elseif id == "RIOT" then
		if Events.onRiot then
			Events.onRiot(true)
		end
	elseif id == "TREASURE" then
		-- a few layers past the median depth of everyone here
		local depths = {}
		for _, s in State.all() do
			table.insert(depths, s.data.MaxDepth)
		end
		table.sort(depths)
		local median = depths[math.max(1, #depths // 2)] or 0
		local target = math.clamp(median + 6, 3, Progression.diggableDepth() - 1)
		for player, s in State.all() do
			placeTreasure(player, s, target)
		end
	end
	return true
end

function Events.stop()
	finish()
end

-- Dig hook: did someone break their treasure?
function Events.onBroken(player: Player, broken: { number })
	local idx = treasure[player]
	if current ~= "TREASURE" or not idx or not table.find(broken, idx) then
		return
	end
	local s = State.get(player)
	if not s then
		return
	end
	local zone = math.clamp(s.data.Zone, 1, #Zones)
	local amount = Cycle.TreasureBlocks * Zones[zone].rubble
	Loot.addNoodles(player, amount)
	-- the best find of your zone, straight into your Stash (known prize: shown in the event text)
	local best: string? = nil
	local bestValue = -1
	for _, f in Finds.ByZone[zone] or {} do
		if f.value > bestValue then
			best, bestValue = f.id, f.value
		end
	end
	if best then
		table.insert(s.data.Stash, best)
		s.data.Found[best] = true
		Net.fire(player, Remotes.Names.Stash, s.data.Stash)
	end
	Net.announce(
		string.format("%s won the TREASURE RACE! +%s", player.Name, Format.noodles(amount)),
		{ 255, 215, 60 },
		"Zone"
	)
	finish()
end

function Events.startService()
	Dig.onBroken = Events.onBroken
	task.spawn(function()
		local nextAt = os.clock() + math.random(Cycle.EventMin, Cycle.EventMax)
		while true do
			task.wait(1)
			if current and os.clock() >= endsAt then
				finish()
			end
			if not current and os.clock() >= nextAt then
				nextAt = os.clock() + math.random(Cycle.EventMin, Cycle.EventMax)
				local phase = Events.phase()
				local pool = table.clone(Cycle.EventPools[if phase == "Night" then "Night" else "Day"])
				local i = table.find(pool, last or "")
				if i and #pool > 1 then
					table.remove(pool, i)
				end
				Events.trigger(pool[math.random(1, #pool)])
			end
		end
	end)
end

-- (smoke test) the block index of this player's treasure, if any
function Events.treasureOf(player: Player): number?
	return treasure[player]
end

function Events.onLeaving(player: Player)
	treasure[player] = nil
end

return Events
