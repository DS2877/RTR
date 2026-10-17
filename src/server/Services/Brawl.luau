--!strict
-- YARD BRAWL: by day, fists work on players outside the safe zones (cells, shops, gym, dump).
-- Slapstick knockback, no blood. Stamina 0 = knocked out: you drop part of your backpack rubble
-- and one find as a pile anyone can pick up, then get a few seconds of protection.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local PvP = require(Shared.Config.PvP)
local Finds = require(Shared.Config.Finds)
local Progression = require(Shared.Progression)
local Tunnel = require(Shared.Tunnel)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Stats = require(script.Parent.Stats)

local Brawl = {}

local world: any = nil

-- hooks (set in init): is it day? / a carrier got hit
Brawl.isDay = function(): boolean
	return true
end
Brawl.onCarrierHit = nil :: ((thief: Player) -> ())?
Brawl.onFind = nil :: ((player: Player, id: string, firstTime: boolean) -> ())? -- the collection
-- somewhere fights don't happen (init: on THE BREAKOUT course)
Brawl.noFight = nil :: ((player: Player) -> boolean)?

export type Drop = { id: number, pos: Vector3, rubble: number, value: number, finds: { string }, born: number }
local drops: { Drop } = {}
local dropSeq = 0

local function now(): number
	return os.clock()
end

-- Safe zones: every cell room and tunnel, the shop counters, the gym and the dump.
function Brawl.isSafe(pos: Vector3): boolean
	if Tunnel.cellAt(pos) then
		return true
	end
	for _, counter in world.shops do
		if (counter.Position - pos).Magnitude <= PvP.SafeRadiusShop then
			return true
		end
	end
	for _, st in world.stations do
		if (st.Position - pos).Magnitude <= PvP.SafeRadiusGym then
			return true
		end
	end
	return (world.dump.Position - pos).Magnitude <= PvP.SafeRadiusDump
end

function Brawl.damage(attackerStrength: number, defenderStrength: number): number
	local ratio =
		math.clamp(math.sqrt(attackerStrength / math.max(1, defenderStrength)), PvP.DamageMin, PvP.DamageMax)
	return math.floor(PvP.BaseDamage * ratio + 0.5)
end

local function byUserId(userId: number): Player?
	for p in State.all() do
		if (p :: any).UserId == userId then
			return p
		end
	end
	return nil
end

local function sendDrops()
	local list = {}
	for _, d in drops do
		table.insert(list, { d.id, d.pos.X, d.pos.Y, d.pos.Z, d.rubble, #d.finds })
	end
	Remotes.get(Remotes.Names.Drops):FireAllClients(list)
	if Net.sink then
		Net.sink(nil, Remotes.Names.Drops, { list })
	end
end

function Brawl.addDrop(pos: Vector3, rubble: number, value: number, finds: { string })
	if rubble <= 0 and #finds == 0 then
		return
	end
	dropSeq += 1
	table.insert(
		drops,
		{ id = dropSeq, pos = pos, rubble = rubble, value = value, finds = finds, born = now() }
	)
	sendDrops()
end

function Brawl.drops(): { Drop }
	return drops
end

local function deepestZone(data: any): number
	return math.max(data.Zone, Progression.zoneAt(math.max(0, data.MaxDepth - 1)))
end

-- `as` = the attacker: a veteran knocking out a much newer prisoner gets no find out of it
local function knockout(victim: Player, vs: State.PlayerState, pos: Vector3, as: State.PlayerState)
	local data = vs.data
	local rubble = math.floor(data.Bag * PvP.KnockoutDropShare)
	local value = if data.Bag > 0 then data.BagValue * rubble / data.Bag else 0
	data.Bag -= rubble
	data.BagValue -= value
	local finds = {}
	if PvP.KnockoutDropsFind and #data.Finds > 0 and deepestZone(as.data) <= deepestZone(data) + 1 then
		-- the most valuable find falls out of your pockets
		local best, bestValue = 1, -1
		for i, id in data.Finds do
			local v = Progression.findValue(id)
			if v > bestValue then
				best, bestValue = i, v
			end
		end
		table.insert(finds, table.remove(data.Finds, best))
	end
	Brawl.addDrop(pos, rubble, value, finds)
	vs.stamina = PvP.MaxStamina
	vs.protectedUntil = now() + PvP.SpawnProtection
	data.Stats.Knockouts += 1
	Stats.sync(victim)
	if typeof(victim) == "Instance" then
		victim:SetAttribute("Protected", true)
		task.delay(PvP.SpawnProtection, function()
			if victim.Parent then
				victim:SetAttribute("Protected", false)
			end
		end)
	end
	Net.fire(victim, Remotes.Names.Finds, data.Finds)
end

-- Returns a reason when the punch does nothing (also used by the smoke test).
function Brawl.punch(attacker: Player, userId: any): string?
	local as = State.get(attacker)
	if not as or typeof(userId) ~= "number" then
		return "bad args"
	end
	local victim = byUserId(userId)
	local vs = victim and State.get(victim)
	if not victim or not vs or victim == attacker then
		return "no victim"
	end
	if not Brawl.isDay() then
		return "night"
	end
	if Brawl.noFight and (Brawl.noFight(attacker) or Brawl.noFight(victim)) then
		return "no fights here"
	end
	-- newbie protection (a thief carrying your find is always fair game)
	if as.data.PlayMinutes < PvP.NewbieMinutes then
		return "newbie"
	end
	if vs.carrying == nil and vs.data.PlayMinutes < PvP.NewbieMinutes then
		return "newbie victim"
	end
	local t = now()
	if t - as.lastBrawl < PvP.PunchCooldown * 0.85 then
		return "too fast"
	end
	local apos, vpos = State.root(attacker), State.root(victim)
	if not apos or not vpos or (apos - vpos).Magnitude > PvP.PunchRange + 4 then
		return "out of reach"
	end
	local carrier = vs.carrying ~= nil
	if not carrier then
		if Brawl.isSafe(vpos) or Brawl.isSafe(apos) then
			return "safe zone"
		end
		if t < vs.protectedUntil then
			return "protected"
		end
	end
	as.lastBrawl = t
	local dmg = Brawl.damage(as.data.Strength, vs.data.Strength)
	vs.stamina -= dmg
	vs.lastHitAt = t
	local flat = Vector3.new(vpos.X - apos.X, 0, vpos.Z - apos.Z)
	local dir = if flat.Magnitude > 0.01 then flat.Unit else Vector3.xAxis
	local out = vs.stamina <= 0
	local impulse = dir * PvP.Knockback * (if out then 1.5 else 1) + Vector3.new(0, PvP.KnockUp, 0)
	if carrier and Brawl.onCarrierHit then
		Brawl.onCarrierHit(victim)
	end
	if out then
		knockout(victim, vs, vpos, as)
		Net.notice(victim, "KNOCKED OUT by " .. attacker.Name .. "!", "bad")
		Net.notice(attacker, "You knocked out " .. victim.Name .. "!", "good")
	end
	if typeof(victim) == "Instance" then
		victim:SetAttribute("Stamina", math.max(0, vs.stamina))
	end
	Net.fire(victim, Remotes.Names.Knocked, impulse, math.max(0, vs.stamina), out)
	Net.fire(attacker, Remotes.Names.Hit, userId, out)
	return nil
end

local function pickups()
	if #drops == 0 then
		return
	end
	local changed = false
	local t = now()
	for i = #drops, 1, -1 do
		local d = drops[i]
		if t - d.born > PvP.DropLifetime then
			table.remove(drops, i)
			changed = true
		else
			for player, s in State.all() do
				local pos = State.root(player)
				if pos and (pos - d.pos).Magnitude <= PvP.PickupRange then
					local room = Stats.capacity(s) - s.data.Bag
					local take = math.min(room, d.rubble)
					if take > 0 then
						local v = d.value * take / d.rubble
						s.data.Bag += take
						s.data.BagValue += v
						d.rubble -= take
						d.value -= v
						changed = true
					end
					local slots = Progression.findSlots(s.data.Levels.FindSlots)
					while #d.finds > 0 and #s.data.Finds < slots do
						local id = table.remove(d.finds) :: string
						table.insert(s.data.Finds, id)
						local first = not s.data.Found[id]
						s.data.Found[id] = true
						if Brawl.onFind then
							Brawl.onFind(player, id, first)
						end
						local f = Finds.ById[id]
						Net.notice(
							player,
							"You picked up " .. (if f then f.emoji .. " " .. f.name else id) .. "!",
							"good"
						)
						Net.fire(player, Remotes.Names.Finds, s.data.Finds)
						changed = true
					end
					if take > 0 then
						Stats.sync(player)
					end
				end
			end
			if d.rubble <= 0 and #d.finds == 0 then
				table.remove(drops, i)
				changed = true
			end
		end
	end
	if changed then
		sendDrops()
	end
end

function Brawl.start(w: any)
	world = w
	local limit = RateLimit.new(1 / PvP.PunchCooldown * 1.5, 4)
	Net.on(Remotes.Names.Brawl, function(player, userId)
		if limit(player) then
			Brawl.punch(player, userId)
		end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				local dt = task.wait(0.25)
				local t = now()
				for player, s in State.all() do
					if s.stamina < PvP.MaxStamina and t - s.lastHitAt >= PvP.RegenDelay then
						s.stamina = math.min(PvP.MaxStamina, s.stamina + PvP.StaminaRegen * dt)
						if typeof(player) == "Instance" then
							player:SetAttribute("Stamina", s.stamina)
						end
					end
				end
				pickups()
			end)
			if not ok then
				warn("[Brawl] loop:", err)
				task.wait(1)
			end
		end
	end)
	Players.PlayerAdded:Connect(function(p)
		task.wait(3)
		if p.Parent then
			sendDrops()
		end
	end)
end

return Brawl
