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

Remotes.setup()

-- debris cubes (client-side) never bump into characters
pcall(function()
	PhysicsService:RegisterCollisionGroup("Characters")
	PhysicsService:RegisterCollisionGroup("Debris")
	PhysicsService:CollisionGroupSetCollidable("Characters", "Debris", false)
	PhysicsService:CollisionGroupSetCollidable("Debris", "Debris", false)
end)

local world = WorldBuilder.build()
Cells.start(world)
Dig.start()
Loot.start(world)
Shop.start(world)
Gym.start(world)
Admin.start()
Dig.onPiles = Loot.sendPiles

local function onCharacter(player: Player, character: Model)
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
	task.wait(0.1)
	Cells.toCell(player)
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
		Dig.saveTunnel(s)
		s.data.LastOnline = os.time()
	end
	Dig.forget(player)
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
