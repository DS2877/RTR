--!strict
-- Dig Out! server entry: builds the prison, loads players, wires every service.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Economy = require(Shared.Config.Economy)

local State = require(script.State)
local Services = script.Services
local WorldBuilder = require(Services.WorldBuilder)
local Data = require(Services.Data)
local Stats = require(Services.Stats)
local Cells = require(Services.Cells)
local Dig = require(Services.Dig)
local Loot = require(Services.Loot)
local Shop = require(Services.Shop)
local Gym = require(Services.Gym)
local Admin = require(Services.Admin)
local DayNight = require(Services.DayNight)
local Collection = require(Services.Collection)
local Brawl = require(Services.Brawl)
local Raid = require(Services.Raid)
local TopDog = require(Services.TopDog)
local Product = require(Services.Product)
local Escape = require(Services.Escape)
local Rewards = require(Services.Rewards)
local Guards = require(Services.Guards)
local Hideout = require(Services.Hideout)
local Missions = require(Services.Missions)
local Characters = require(script.Util.Characters)
local Patrol = require(Services.Patrol)
local Events = require(Services.Events)
local Market = require(Services.Market)
local Tutorial = require(Services.Tutorial)

Remotes.setup()

-- debris cubes (client-side) never bump into characters, but pile up on each other
pcall(function()
	PhysicsService:RegisterCollisionGroup("Characters")
	PhysicsService:RegisterCollisionGroup("Debris")
	PhysicsService:CollisionGroupSetCollidable("Characters", "Debris", false)
	PhysicsService:CollisionGroupSetCollidable("Debris", "Debris", true) -- cubes pile up
end)

local world = WorldBuilder.build()
Cells.start(world)
Hideout.start(world)
Dig.beforePunch = Hideout.beforePunch
Dig.start()
Loot.start(world)
Shop.start(world)
Gym.start(world)
Admin.start()
DayNight.start(world)
Brawl.start(world)
Raid.start(world)
TopDog.start(world)
Product.start()
Escape.start()
Rewards.start()
Tutorial.start()
Missions.start()
Guards.start()
-- real avatars for the NPCs (in the background: the blocky stand-ins show until they're ready)
task.spawn(function()
	Characters.publishTemplates()
	Characters.upgradeAll()
end)
Patrol.phase = DayNight.phase
Patrol.start()
Events.startService()
Market.start(world)
Dig.onPiles = Loot.sendPiles
Dig.onFind = function(player, id, firstTime)
	Collection.onFound(player, id, firstTime)
	Missions.count(player, "Finds", 1)
end
local function isDay(): boolean
	return DayNight.phase() == "Day"
end
Brawl.isDay = isDay
Raid.isDay = isDay
Brawl.onCarrierHit = function(thief)
	Raid.returnCarry(thief, "you got hit")
end
DayNight.onCounted = Rewards.rollCall
DayNight.onDay = function()
	Raid.newDay()
	Market.morning()
end
DayNight.riot = Events.riot
-- night: the doors are locked, so the cell toilet takes your rubble (for less)
Loot.canFlush = function(): boolean
	local p = DayNight.phase()
	return (p == "Night" or p == "LightsOut") and not Events.riot()
end
DayNight.onPhase = function(p)
	Loot.setFlush(p == "Night" or p == "LightsOut")
end
Events.onRiot = function(on)
	DayNight.setRiot(on)
	-- (during a riot the doors are open: the toilets stop taking rubble)
	local p = DayNight.phase()
	Loot.setFlush(not on and (p == "Night" or p == "LightsOut"))
end
Events.phase = DayNight.phase
Guards.isNight = function(): boolean
	return DayNight.phase() == "Night"
end
Dig.powerBoost = Market.powerBoost
Dig.findBoost = Market.findBoost
Dig.speedBoost = Market.speedBoost
Loot.magnet = Market.magnet
Escape.onEscaped = Market.renderDecor
Product.onPasses = function(player)
	task.spawn(Market.onCharacter, player)
end
Shop.onBought = function(player, track)
	if track == "Lock" then
		Raid.refreshPrompt(player)
	end
	Tutorial.did(player, "Upgrade")
	Tutorial.event(player, "Upgrade_" .. track)
end
-- tutorial + analytics (first punch, vacuum, sale, upgrade, zones, session length)
local eventsOnBroken = Dig.onBroken
Dig.onBroken = function(player, broken)
	if eventsOnBroken then
		eventsOnBroken(player, broken)
	end
	Tutorial.did(player, "Punch")
	Missions.count(player, "Blocks", #broken)
end
Dig.onCrit = function(player)
	Missions.count(player, "Crits", 1)
end
Dig.onDeeper = function(player, layers)
	Missions.count(player, "Depth", layers)
end
Gym.onLift = function(player, q)
	if q == "good" or q == "perfect" then
		Missions.count(player, "Lifts", 1)
	end
	if q == "perfect" then
		Missions.count(player, "Perfects", 1)
	end
end
Loot.onVacuum = function(player)
	Tutorial.did(player, "Vacuum")
end
Loot.onDump = function(player, pay)
	Tutorial.did(player, "Dump")
	Tutorial.event(player, "Dump", pay)
	if pay > 0 then
		Missions.count(player, "Dumps", 1)
	end
end
Loot.onSell = function(player, total, count)
	Tutorial.did(player, "Sell")
	Missions.count(player, "Sells", count)
	Tutorial.event(player, "Sell", total)
end
Dig.onZone = function(player, zone)
	Tutorial.zone(player, zone)
end

local function onCharacter(player: Player, character: Model)
	-- respawning (reset) never smuggles a stolen find home
	Raid.returnCarry(player, "respawned")
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = Economy.WalkSpeed
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Characters"
		end
	end
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = "Characters"
		end
	end)
	Hideout.onCharacter(player)
	task.wait(0.1)
	Cells.toCell(player)
	task.spawn(Market.onCharacter, player)
end

local function onPlayerAdded(player: Player)
	local data = Data.load(player)
	if not data or player.Parent ~= Players then
		return
	end
	State.add(player, data)
	Stats.setupLeaderstats(player)
	if not Cells.assign(player) then
		player:Kick("This prison is full. Please join another server!")
		return
	end
	Dig.loadTunnel(player)
	data.LastOnline = os.time()
	Stats.sync(player)
	Loot.sendFinds(player)
	Loot.sendPiles(player)
	Collection.render(player)
	Raid.sendStash(player)
	Raid.refreshPrompt(player)
	Product.loadPasses(player)
	Product.syncPackAttributes(player)
	Escape.check(player)
	Rewards.onJoin(player)
	Tutorial.onJoin(player)
	Missions.sync(player)
	player:SetAttribute("JoinedAt", os.time())
	Market.renderDecor(player)
	Market.sync(player)
	player:SetAttribute("Stamina", 100)
	player:SetAttribute("Loaded", true)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end

local function leave(player: Player)
	local s = State.get(player)
	if s then
		local joined = player:GetAttribute("JoinedAt")
		if typeof(joined) == "number" then
			Tutorial.event(player, "SessionMinutes", math.floor((os.time() - joined) / 60))
		end
		Dig.saveTunnel(s)
		s.data.LastOnline = os.time()
	end
	Raid.onLeaving(player)
	Gym.onLeaving(player)
	TopDog.onLeaving(player)
	Events.onLeaving(player)
	Market.clearRender(player)
	Dig.forget(player)
	Hideout.onLeaving(player)
	Cells.release(player)
	State.remove(player)
	Data.release(player)
end

Players.PlayerRemoving:Connect(leave)

game:BindToClose(function()
	for _, p in Players:GetPlayers() do
		leave(p)
	end
	task.wait(2)
end)

print("Dig Out! server ready")
