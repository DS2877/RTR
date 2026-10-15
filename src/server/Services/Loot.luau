--!strict
-- Rubble and finds: vacuuming loose piles into the backpack, dumping rubble in the Yard for Noodles,
-- selling finds at The Fence.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Stats = require(script.Parent.Stats)

local Loot = {}

local world: any = nil

Loot.magnet = nil :: ((player: Player) -> boolean)?
-- tutorial / analytics hooks
Loot.onVacuum = nil :: ((player: Player) -> ())?
Loot.onDump = nil :: ((player: Player, pay: number) -> ())?
Loot.onSell = nil :: ((player: Player, total: number) -> ())?

-- every Noodles multiplier: 2x pass, collection sets, rebirths, group bonus, buffs
function Loot.multiplier(s: State.PlayerState): number
	local pass = if s.passes.DoubleNoodles then Economy.PassEffects.DoubleNoodles else 1
	local group = if s.groupBonus then 1 + Economy.GroupBonus else 1
	return pass
		* Progression.collectionMultiplier(s.data.Found)
		* Progression.rebirthMultiplier(s.data.Rebirths)
		* group
end
local noodleMult = Loot.multiplier

function Loot.addNoodles(player: Player, amount: number)
	local s = State.get(player)
	if not s or amount ~= amount then
		return
	end
	s.data.Noodles = math.max(0, s.data.Noodles + amount)
	if amount > 0 then
		s.data.Stats.Earned += amount
	end
	Stats.sync(player)
end

function Loot.sendPiles(player: Player)
	local s = State.get(player)
	if not s then
		return
	end
	local list = {}
	for _, p in s.piles do
		table.insert(list, { p.id, p.pos.X, p.pos.Y, p.pos.Z, p.rubble })
	end
	Net.fire(player, Remotes.Names.Piles, list)
end

function Loot.sendFinds(player: Player)
	local s = State.get(player)
	if s then
		Net.fire(player, Remotes.Names.Finds, s.data.Finds)
	end
end

-- Moves piles within vacuum range into the backpack (up to capacity). Returns rubble moved.
function Loot.vacuum(player: Player): number
	local s = State.get(player)
	local root = State.root(player)
	if not s or not root or #s.piles == 0 then
		return 0
	end
	local range = Progression.vacuumRange(s.data.Levels.Vacuum)
	local room = Stats.capacity(s) - s.data.Bag
	local moved = 0
	local keep = {}
	for _, p in s.piles do
		if room > 0 and (p.pos - root).Magnitude <= range then
			local take = math.min(room, p.rubble)
			local valueTake = p.value * take / p.rubble
			s.data.Bag += take
			s.data.BagValue += valueTake
			p.rubble -= take
			p.value -= valueTake
			s.loose -= take
			room -= take
			moved += take
		end
		if p.rubble > 0 then
			table.insert(keep, p)
		end
	end
	s.piles = keep
	if moved > 0 then
		if Loot.onVacuum then
			Loot.onVacuum(player)
		end
		Loot.sendPiles(player)
		Stats.sync(player)
		if room <= 0 then
			Net.fire(player, Remotes.Names.Full, "bag")
		end
	end
	return moved
end

local function near(player: Player, part: BasePart, range: number): boolean
	local root = State.root(player)
	return root ~= nil and (root - part.Position).Magnitude <= range
end

function Loot.dump(player: Player): number
	local s = State.get(player)
	if not s or not near(player, world.dump, Economy.DumpRange + 4) then
		return 0
	end
	if s.data.Bag <= 0 then
		Net.notice(player, "Your backpack is empty. Go dig!", "info")
		return 0
	end
	local pay = math.floor(s.data.BagValue * noodleMult(s) + 0.5)
	s.data.Bag = 0
	s.data.BagValue = 0
	Loot.addNoodles(player, pay)
	Net.fire(player, Remotes.Names.Dumped, pay)
	if Loot.onDump then
		Loot.onDump(player, pay)
	end
	return pay
end

-- Instant Backpack Empty (developer product): pays the backpack and every loose pile, anywhere.
function Loot.dumpAnywhere(player: Player): number
	local s = State.get(player)
	if not s then
		return 0
	end
	local value = s.data.BagValue
	for _, p in s.piles do
		value += p.value
	end
	s.piles = {}
	s.loose = 0
	s.data.Bag = 0
	s.data.BagValue = 0
	local pay = math.floor(value * noodleMult(s) + 0.5)
	Loot.addNoodles(player, pay)
	Loot.sendPiles(player)
	Net.fire(player, Remotes.Names.Dumped, pay)
	return pay
end

-- slot 0 = sell everything
function Loot.sell(player: Player, slot: number): number
	local s = State.get(player)
	if not s or not near(player, world.shops.Fence, Economy.ShopRange + 6) then
		return 0
	end
	local finds = s.data.Finds
	local total = 0
	if slot == 0 then
		for _, id in finds do
			total += Progression.findValue(id)
		end
		s.data.Finds = {}
	elseif finds[slot] then
		total = Progression.findValue(finds[slot])
		table.remove(finds, slot)
	else
		return 0
	end
	total = math.floor(total * noodleMult(s))
	if total > 0 then
		Loot.addNoodles(player, total)
		Net.notice(player, "The Fence paid " .. Format.noodles(total), "cash")
		if Loot.onSell then
			Loot.onSell(player, total)
		end
	end
	Loot.sendFinds(player)
	return total
end

function Loot.start(w: any)
	world = w
	Net.on(Remotes.Names.Vacuum, function(player, on)
		local s = State.get(player)
		if s and typeof(on) == "boolean" then
			s.vacuuming = on
		end
	end)
	local sellLimit = RateLimit.new(4, 6)
	Net.on(Remotes.Names.Sell, function(player, slot)
		if sellLimit(player) and typeof(slot) == "number" and slot % 1 == 0 and slot >= 0 and slot <= 100 then
			Loot.sell(player, slot)
		end
	end)
	local dumpPrompt = world.dump:FindFirstChild("DumpPrompt") :: ProximityPrompt
	dumpPrompt.Triggered:Connect(function(player)
		Loot.dump(player)
	end)
	-- vacuum tick
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player, s in State.all() do
				local magnet = Loot.magnet ~= nil and Loot.magnet(player)
				if (s.vacuuming or s.passes.AutoVacuum or magnet) and #s.piles > 0 then
					Loot.vacuum(player)
				end
			end
		end
	end)
end

return Loot
