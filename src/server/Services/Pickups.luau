--!strict
-- Cash pickups along Rich Street (and on the express lanes): run through one for a few seconds of
-- your income. During the Halloween season every pickup also drops 🍬 candy, and some are
-- pumpkins worth more candy. Taken pickups come back after a while.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Cosmetics = require(Shared.Config.Cosmetics)
local World = require(Shared.Config.World)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local Wallet = require(script.Parent.Wallet)
local Bases = require(script.Parent.Bases)
local Cosmetic = require(script.Parent.Cosmetic)

local Pickups = {}

type Pickup = { part: BasePart, active: boolean, back: number, big: boolean }

local P = Economy.Pickups
local list: { Pickup } = {}
local rng = Random.new()

local function setActive(p: Pickup, on: boolean)
	p.active = on
	p.part.Transparency = if on then 0 else 1
	local light = p.part:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = on
	end
end

local function makePart(parent: Instance, pos: Vector3, big: boolean): BasePart
	local part = Instance.new("Part")
	part.Name = if big then "PumpkinPickup" else "CoinPickup"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	if big then
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(2.6, 2.6, 2.6)
		part.Color = Color3.fromRGB(255, 130, 20)
		part.Material = Enum.Material.Neon
	else
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.4, 2.6, 2.6)
		part.Color = Color3.fromRGB(255, 205, 40)
		part.Material = Enum.Material.Neon
	end
	part.CFrame = CFrame.new(pos)
	local light = Instance.new("PointLight")
	light.Color = part.Color
	light.Range = 8
	light.Brightness = 1.2
	light.Parent = part
	CollectionService:AddTag(part, "Spin")
	part.Parent = parent
	return part
end

-- Reward for one pickup (also used by the smoke test).
function Pickups.reward(player: Player, big: boolean): (number, number)
	local cash = math.max(P.MinCash, math.floor(Bases.incomePerSecond(player) * P.IncomeSeconds))
	local candy = 0
	if Cosmetic.seasonActive() then
		candy = if big then Cosmetics.BigCandy else Cosmetics.CandyPerPickup
	end
	return cash, candy
end

local function collect(player: Player, p: Pickup)
	setActive(p, false)
	p.back = os.clock() + P.Respawn
	local cash, candy = Pickups.reward(player, p.big)
	Wallet.add(player, cash)
	Cosmetic.addCandy(player, candy)
	Net.fire(player, Remotes.Names.Pickup, cash, candy, p.part.Position)
end

function Pickups.all(): { Pickup }
	return list
end

function Pickups.start(worldInfo: any)
	local folder = Instance.new("Folder")
	folder.Name = "Pickups"
	folder.Parent = workspace
	local season = Cosmetic.seasonActive()
	local i = 0
	for x = World.StreetStartX + 24, worldInfo.streetEnd - 24, P.Spacing do
		i += 1
		-- weave across the street; every third one sits on an express lane
		local z = math.sin(i * 0.9) * 11
		if i % 3 == 0 then
			z = if i % 2 == 0 then 20 else -20
		end
		local big = season and rng:NextNumber() < Cosmetics.BigCandyChance
		local p: Pickup =
			{ part = makePart(folder, Vector3.new(x, 3, z), big), active = true, back = 0, big = big }
		table.insert(list, p)
	end
	task.spawn(function()
		while true do
			task.wait(0.15)
			local t = os.clock()
			for _, p in list do
				if not p.active then
					if t >= p.back then
						setActive(p, true)
					end
				else
					for player in State.all() do
						local r = State.root(player)
						if r and (r.Position - p.part.Position).Magnitude <= P.Radius then
							collect(player, p)
							break
						end
					end
				end
			end
		end
	end)
end

return Pickups
