--!strict
-- CREW: dig together. A host invites players (CrewInvite); a guest who accepts (CrewAnswer) may
-- punch blocks in the host's tunnel (Dig.crewHost). The tunnel and its depth stay the host's;
-- each digger keeps their own rubble, finds, gold and combo. Everyone in a crew earns more Noodles
-- (Loot.crewBonus): +CrewBonus per other member, +CrewFriendBonus more per Roblox friend.
-- Attributes for the UI: "CrewHost" (the host's UserId while you're a guest, 0 = none) and
-- "Crew" (JSON: host name, member names, bonus). Nobody is ever in two crews; a guest can't host.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Dig = require(script.Parent.Dig)
local Loot = require(script.Parent.Loot)
local Cells = require(script.Parent.Cells)

local Crew = {}

-- night: guests stay in the crew but can't be brought over (DayNight sets it)
Crew.canVisit = function(): boolean
	return true
end

local hostOf: { [any]: any } = {} -- guest -> host
local guestsOf: { [any]: { any } } = {} -- host -> guests
local invites: { [any]: { host: any, at: number } } = {} -- guest -> pending invite
local friendCache: { [string]: boolean } = {}

local function byId(id: number): any
	for p in State.all() do
		if p.UserId == id then
			return p
		end
	end
	return nil
end

local function friends(a: any, b: any): boolean
	local key = math.min(a.UserId, b.UserId) .. ":" .. math.max(a.UserId, b.UserId)
	local cached = friendCache[key]
	if cached ~= nil then
		return cached
	end
	local ok, yes = false, false
	if typeof(a) == "Instance" and typeof(b) == "Instance" and a.UserId > 0 and b.UserId > 0 then
		ok, yes = pcall(function()
			return a:IsFriendsWith(b.UserId)
		end)
	end
	friendCache[key] = ok and yes == true
	return friendCache[key]
end

-- The host of whoever's crew this player is in (themselves if they host one), or nil.
function Crew.hostOf(player: any): any
	if hostOf[player] then
		return hostOf[player]
	end
	if guestsOf[player] and #guestsOf[player] > 0 then
		return player
	end
	return nil
end

-- Everyone in the player's crew (host first), or { player } when solo.
function Crew.members(player: any): { any }
	local host = Crew.hostOf(player)
	if not host then
		return { player }
	end
	local out = { host }
	for _, g in guestsOf[host] or {} do
		table.insert(out, g)
	end
	return out
end

-- The Noodles bonus share for being in this player's crew (0 when solo).
function Crew.bonus(player: any): number
	local members = Crew.members(player)
	if #members <= 1 then
		return 0
	end
	local b = 0
	for _, m in members do
		if m ~= player then
			b += Economy.CrewBonus + (if friends(player, m) then Economy.CrewFriendBonus else 0)
		end
	end
	return math.min(b, Economy.CrewBonusMax)
end

-- Dig.crewHost: may `guest` dig in the tunnel of `ownerId`?
function Crew.hostFor(guest: any, ownerId: number): any
	local h = hostOf[guest]
	if h and h.UserId == ownerId then
		return h
	end
	return nil
end

local function sync(player: any)
	if typeof(player) ~= "Instance" then
		return
	end
	local host = Crew.hostOf(player)
	player:SetAttribute("CrewHost", if hostOf[player] then hostOf[player].UserId else 0)
	if not host then
		player:SetAttribute("Crew", "")
		return
	end
	local names = {}
	for _, m in Crew.members(player) do
		table.insert(names, m.Name)
	end
	player:SetAttribute(
		"Crew",
		HttpService:JSONEncode({
			host = host.Name,
			hostId = host.UserId,
			members = names,
			bonus = math.floor(Crew.bonus(player) * 100 + 0.5),
			you = if host == player then "host" else "guest",
		})
	)
end

local function syncCrew(host: any)
	for _, m in Crew.members(host) do
		sync(m)
	end
end

-- Returns a reason when the invite is refused.
function Crew.invite(host: any, targetId: any): string?
	if typeof(targetId) ~= "number" or targetId ~= targetId then
		return "bad args"
	end
	local target = byId(targetId)
	if not target or target == host then
		return "nobody"
	end
	if hostOf[host] then
		Net.notice(host, "You're digging in someone else's crew. Leave it to start your own.", "info")
		return "guest"
	end
	if Crew.hostOf(target) then
		Net.notice(host, target.Name .. " is already in a crew.", "info")
		return "taken"
	end
	if #(guestsOf[host] or {}) >= Economy.CrewMaxGuests then
		Net.notice(host, "Your crew is full!", "info")
		return "full"
	end
	invites[target] = { host = host, at = os.clock() }
	Net.fire(target, Remotes.Names.CrewInvited, host.UserId, host.Name, friends(host, target))
	Net.notice(host, "Crew invite sent to " .. target.Name .. " 📨", "info")
	return nil
end

-- A guest joins (also used by the smoke test). Returns a reason when it can't happen.
function Crew.answer(guest: any, hostId: any, accept: any): string?
	local inv = invites[guest]
	invites[guest] = nil
	if not inv or typeof(hostId) ~= "number" or inv.host.UserId ~= hostId then
		return "no invite"
	end
	local host = inv.host
	if accept ~= true then
		Net.notice(host, guest.Name .. " said no this time.", "info")
		return "declined"
	end
	if os.clock() - inv.at > Economy.CrewInviteSeconds then
		Net.notice(guest, "That invite ran out.", "info")
		return "expired"
	end
	if not State.get(host) or Crew.hostOf(guest) or hostOf[host] then
		return "taken"
	end
	local list = guestsOf[host] or {}
	if #list >= Economy.CrewMaxGuests then
		Net.notice(guest, host.Name .. "'s crew is full.", "info")
		return "full"
	end
	table.insert(list, guest)
	guestsOf[host] = list
	hostOf[guest] = host
	-- (look every friendship up now, so no punch ever waits on the web)
	for _, a in Crew.members(host) do
		for _, b in Crew.members(host) do
			if a ~= b then
				friends(a, b)
			end
		end
	end
	syncCrew(host)
	for _, m in Crew.members(host) do
		Net.notice(
			m,
			string.format(
				"👥 %s joined %s crew! +%d%% Noodles",
				guest.Name,
				if m == host then "your" else host.Name .. "'s",
				math.floor(Crew.bonus(m) * 100 + 0.5)
			),
			"good"
		)
	end
	-- straight to the host's cell (by day; at night the doors are locked)
	local hs = State.get(host)
	if typeof(guest) == "Instance" and hs and hs.cell and Crew.canVisit() then
		local cell = Cells.record(hs.cell)
		local character = guest.Character
		if cell and character then
			character:PivotTo(cell.spawn * CFrame.new(3, 0, 0))
		end
	end
	return nil
end

-- Leave your crew (a host disbands it); a host may kick one guest by id.
function Crew.leave(player: any, kickId: any)
	local host = hostOf[player]
	if host then
		local list = guestsOf[host] or {}
		table.remove(list, table.find(list, player) or (#list + 1))
		hostOf[player] = nil
		sync(player)
		syncCrew(host)
		Net.notice(host, player.Name .. " left your crew.", "info")
		return
	end
	local list = guestsOf[player]
	if not list then
		return
	end
	if typeof(kickId) == "number" then
		for i, g in list do
			if g.UserId == kickId then
				table.remove(list, i)
				hostOf[g] = nil
				sync(g)
				Net.notice(g, player.Name .. " sent you back to your own tunnel.", "info")
				break
			end
		end
	else
		for _, g in list do
			hostOf[g] = nil
			sync(g)
			Net.notice(g, player.Name .. " broke up the crew.", "info")
		end
		guestsOf[player] = {}
	end
	syncCrew(player)
	sync(player)
end

function Crew.onLeaving(player: any)
	invites[player] = nil
	Crew.leave(player)
	guestsOf[player] = nil
end

function Crew.start()
	Dig.crewHost = Crew.hostFor
	Loot.crewBonus = function(s)
		return Crew.bonus(s.player)
	end
	local limit = RateLimit.new(0.5, 3)
	Net.on(Remotes.Names.CrewInvite, function(player, targetId)
		if limit(player) then
			Crew.invite(player, targetId)
		end
	end)
	local answerLimit = RateLimit.new(1, 3)
	Net.on(Remotes.Names.CrewAnswer, function(player, hostId, accept)
		if answerLimit(player) then
			Crew.answer(player, hostId, accept)
		end
	end)
	local leaveLimit = RateLimit.new(1, 3)
	Net.on(Remotes.Names.CrewLeave, function(player, kickId)
		if leaveLimit(player) then
			Crew.leave(player, kickId)
		end
	end)
	Players.PlayerAdded:Connect(function(p)
		p:SetAttribute("CrewHost", 0)
		p:SetAttribute("Crew", "")
	end)
end

return Crew
