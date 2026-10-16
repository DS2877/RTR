--!strict
-- CELLMATES: buy (known price, no randomness), equip (1 slot, +1 after your first escape, +1 after
-- your third), XP from every block broken with a pet out, level-ups. The perks themselves apply
-- where they matter (Dig: power / finds / gold, Loot: value / vacuum) straight from the saved pets
-- (Shared/Pets); the dig pet's swings run here. Attributes for the clients: "Pets" (what you have
-- out, "Rat:3,Cat:1", everyone renders it) and "PetData" (JSON for your own shop panel).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Pets)
local PetMath = require(Shared.Pets)
local Progression = require(Shared.Progression)
local Voxel = require(Shared.Voxel)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Dig = require(script.Parent.Dig)
local Stats = require(script.Parent.Stats)

local Pets = {}

local function data(s: State.PlayerState): any
	local p = s.data.Pets
	if not p then
		p = { Owned = {}, Equipped = {} }
		s.data.Pets = p
	end
	return p
end

-- The deepest zone you've ever reached (your record survives escapes).
local function recordZone(s: State.PlayerState): number
	return math.max(s.data.Zone, Progression.zoneAt(math.max(0, s.data.MaxDepth - 1)))
end

function Pets.sync(player: any)
	local s = State.get(player)
	if not s or typeof(player) ~= "Instance" then
		return
	end
	local p = data(s)
	local out = {}
	for _, id in p.Equipped do
		if p.Owned[id] then
			table.insert(out, id .. ":" .. (PetMath.level(p.Owned[id])))
		end
	end
	player:SetAttribute("Pets", table.concat(out, ","))
	player:SetAttribute(
		"PetData",
		HttpService:JSONEncode({
			owned = p.Owned,
			equipped = p.Equipped,
			slots = PetMath.slots(s.data.Rebirths),
			zone = recordZone(s),
		})
	)
end

-- Returns a reason when refused (also used by the smoke test).
function Pets.buy(player: any, id: any): string?
	local s = State.get(player)
	local pet = typeof(id) == "string" and PetMath.get(id)
	if not s or not pet then
		return "bad args"
	end
	local p = data(s)
	if p.Owned[id] then
		return "owned"
	end
	if recordZone(s) < pet.zone then
		Net.notice(player, string.format("Reach zone %d to get the %s!", pet.zone, pet.name), "info")
		return "locked"
	end
	local price = PetMath.price(id)
	if s.data.Noodles < price then
		Net.notice(player, "Not enough Noodles for the " .. pet.name .. ".", "bad")
		return "poor"
	end
	s.data.Noodles -= price
	p.Owned[id] = 0
	if #p.Equipped < PetMath.slots(s.data.Rebirths) then
		table.insert(p.Equipped, id)
	end
	Stats.sync(player)
	Pets.sync(player)
	Net.notice(player, string.format("%s %s joined your cell!", pet.emoji, pet.name), "good")
	return nil
end

function Pets.equip(player: any, id: any, on: any): string?
	local s = State.get(player)
	if not s or typeof(id) ~= "string" or typeof(on) ~= "boolean" then
		return "bad args"
	end
	local p = data(s)
	if not p.Owned[id] then
		return "not owned"
	end
	local at = table.find(p.Equipped, id)
	if on and not at then
		if #p.Equipped >= PetMath.slots(s.data.Rebirths) then
			-- full: the oldest one goes back to the cell
			table.remove(p.Equipped, 1)
		end
		table.insert(p.Equipped, id)
	elseif not on and at then
		table.remove(p.Equipped, at)
	end
	Pets.sync(player)
	return nil
end

-- Dig.onPetXp: every equipped pet learns from the blocks you break.
function Pets.addXp(player: any, blocks: number)
	local s = State.get(player)
	if not s or blocks <= 0 then
		return
	end
	local p = data(s)
	local leveled = false
	for _, id in p.Equipped do
		local xp = p.Owned[id]
		if xp then
			local before = PetMath.level(xp)
			p.Owned[id] = xp + blocks
			local after = PetMath.level(p.Owned[id])
			if after > before then
				leveled = true
				local pet = PetMath.get(id)
				Net.fire(player, Remotes.Names.PetLevel, id, after)
				Net.notice(
					player,
					string.format(
						"%s %s reached Lv %d: %s",
						pet.emoji,
						pet.name,
						after,
						PetMath.perkText(id, after)
					),
					"good"
				)
			end
		end
	end
	if leveled then
		Pets.sync(player)
	end
end

-- The dig pet: next to your last punch, a swing every DigInterval while you're digging.
local function digPet(player: any, s: State.PlayerState, now: number)
	local mult = PetMath.bonus(data(s).Owned, data(s).Equipped, "dig")
	local hit = s.lastHit
	if mult <= 0 or not hit or now - s.lastPunch > Config.DigActive or now < s.petDigAt then
		return
	end
	s.petDigAt = now + Config.DigInterval
	local ownerId = hit[4]
	local host: any = nil
	if ownerId ~= player.UserId then
		host = if Dig.crewHost then Dig.crewHost(player, ownerId) else nil
		if not host then
			return
		end
	end
	local ts = if host then State.get(host) else s
	if not ts or not ts.grid then
		return
	end
	local maxZ = Progression.diggableDepth()
	-- the punched block if it still stands, else an exposed one right around it
	local target: { number }? = nil
	local hx, hy, hz = hit[1], hit[2], hit[3]
	if Voxel.isSolid(ts.grid, hx, hy, hz) and hz < maxZ then
		target = { hx, hy, hz }
	else
		local best = math.huge
		for dz = -1, 2 do
			for dy = -2, 2 do
				for dx = -2, 2 do
					local x, y, z = hx + dx, hy + dy, hz + dz
					local d = dx * dx + dy * dy + dz * dz
					if
						d < best
						and z < maxZ
						and Voxel.inBounds(ts.grid, x, y, z)
						and Voxel.isExposed(ts.grid, x, y, z)
					then
						best, target = d, { x, y, z }
					end
				end
			end
		end
	end
	if not target then
		return
	end
	local id = "Badger"
	for _, e in data(s).Equipped do
		local p = PetMath.get(e)
		if p and p.perk == "dig" then
			id = e
			break
		end
	end
	for _, viewer in Dig.watchersOf(host or player) do
		Net.fire(
			viewer,
			Remotes.Names.PetAct,
			player.UserId,
			id,
			target[1],
			target[2],
			target[3],
			(host or player).UserId
		)
	end
	Dig.applyHits(player, s, { target }, Stats.power(s) * mult, host)
end
Pets._digPet = digPet

function Pets.start()
	Dig.onPetXp = Pets.addXp
	local buyLimit = RateLimit.new(1, 3)
	Net.on(Remotes.Names.PetBuy, function(player, id)
		if buyLimit(player) then
			Pets.buy(player, id)
		end
	end)
	local equipLimit = RateLimit.new(3, 6)
	Net.on(Remotes.Names.PetEquip, function(player, id, on)
		if equipLimit(player) then
			Pets.equip(player, id, on)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for player, s in State.all() do
				digPet(player, s, now)
			end
		end
	end)
end

return Pets
