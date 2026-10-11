--!strict
-- Rob the Rich! server entry point.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Format)

local State = require(script.State)
local Net = require(script.Net)
local RateLimit = require(script.Util.RateLimit)
local Services = script.Services
local WorldBuilder = require(Services.WorldBuilder)
local Data = require(Services.Data)
local Wallet = require(Services.Wallet)
local Movement = require(Services.Movement)
local Bases = require(Services.Bases)
local Carry = require(Services.Carry)
local VaultLoot = require(Services.Vaults)
local Guards = require(Services.Guards)
local Treadmill = require(Services.Treadmill)
local Richest = require(Services.Richest)
local Fuse = require(Services.Fuse)
local Product = require(Services.Product)
local Admin = require(Services.Admin)
local Events = require(Services.Events)

Remotes.setup()
local world = WorldBuilder.build()

Events.startService()
Bases.start(world)
Carry.startService()
VaultLoot.start(world)
Guards.start(world)
Treadmill.start(world)
Richest.start(world)
Fuse.start(world)
Product.start()
Admin.start()

local function toBase(player: Player)
	local s = State.get(player)
	local character = player.Character
	if not s or not s.base or not character then
		return
	end
	character:PivotTo(s.base.spawnCFrame)
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	task.wait(0.1)
	toBase(player)
	Movement.refresh(player)
	humanoid.Died:Connect(function()
		Carry.drop(player)
	end)
	task.spawn(Richest.onCharacter, player)
	task.spawn(Product.onCharacter, player)
end

local function giveOffline(player: Player)
	local s = State.get(player)
	if not s or s.data.LastOnline <= 0 then
		return
	end
	local away = math.min(os.time() - s.data.LastOnline, Economy.OfflineMaxHours * 3600)
	if away < 60 then
		return
	end
	local earned = math.floor(Bases.incomePerSecond(player) * away * Economy.OfflineRate)
	if earned > 0 then
		Wallet.add(player, earned)
		Net.fire(player, Remotes.Names.Offline, earned, away)
	end
end

local function onPlayerAdded(player: Player)
	local data = Data.load(player)
	if not data or player.Parent ~= Players then
		return
	end
	local s = State.add(player, data)
	Wallet.setupLeaderstats(player)
	if not Bases.assign(player) then
		player:Kick("This server is full. Please join another one!")
		return
	end
	Product.loadPasses(player)
	if not data.StarterGiven then
		data.StarterGiven = true
		Bases.addItem(player, Economy.StarterItem, "None")
	end
	giveOffline(player)
	s.data.LastOnline = os.time()
	player:SetAttribute("SpeedPoints", data.Speed)
	player:SetAttribute("Steals", data.Stats.Steals + data.Stats.PlayerSteals)
	player:SetAttribute("Collected", data.Stats.Collected)
	player:SetAttribute("TutorialDone", data.TutorialDone)
	player:SetAttribute("Loaded", true)
	Bases.sync(player)

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

Players.PlayerRemoving:Connect(function(player)
	local s = State.get(player)
	Carry.onLeaving(player)
	Richest.onLeaving(player)
	if s then
		s.data.LastOnline = os.time()
	end
	Bases.release(player)
	State.remove(player)
	Data.release(player)
end)

game:BindToClose(function()
	for _, p in Players:GetPlayers() do
		local s = State.get(p)
		if s then
			s.data.LastOnline = os.time()
		end
		Data.release(p)
	end
	task.wait(2)
end)

local syncLimit = RateLimit.new(1, 3)
Net.on(Remotes.Names.RequestSync, function(player)
	if syncLimit(player) then
		Bases.sync(player)
	end
end)

local slowLimit = RateLimit.new(3, 5)
Net.on(Remotes.Names.SetSlowMode, function(player, on)
	local s = State.get(player)
	if s and slowLimit(player) and typeof(on) == "boolean" then
		s.slowMode = on
		player:SetAttribute("SlowMode", on)
		Movement.refresh(player)
	end
end)

-- keep LastOnline fresh so a server crash still gives fair offline earnings
task.spawn(function()
	while true do
		task.wait(30)
		for _, s in State.all() do
			s.data.LastOnline = os.time()
		end
	end
end)

-- first-session guide is done after one steal brought home + one collect
task.spawn(function()
	while true do
		task.wait(2)
		for player, s in State.all() do
			local st = s.data.Stats
			if not s.data.TutorialDone and st.Steals + st.PlayerSteals > 0 and st.Collected > 0 then
				s.data.TutorialDone = true
				player:SetAttribute("TutorialDone", true)
			end
		end
	end
end)

print("Rob the Rich! server ready — " .. Format.number(#world.vaults) .. " vaults")
