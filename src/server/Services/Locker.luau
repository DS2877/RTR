--!strict
-- LIFER'S LOCKER: the steel locker in every cell (WorldBuilder builds it, its prompt opens the
-- panel on the client: Controllers/Locker). Escaping earns FREEDOM POINTS (Escape calls
-- onEscape right away, THE BREAKOUT's medal adds its bonus in onBreakout); the points buy
-- permanent perks (Config/Locker, Shared/Locker). The perks' effects live where their systems
-- are: Stats (power, slots), Shop (prices), Escape (head start, muscle memory), init (night finds).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Locker)
local Economy = require(Shared.Config.Economy)
local Rules = require(Shared.Locker)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Stats = require(script.Parent.Stats)

local Locker = {}

local world: any = nil
-- FP an escape already paid, waiting for THE BREAKOUT's medal (then the "+N FP" card shows)
local pending: { [any]: number } = {}

Locker.onBought = nil :: ((player: Player, id: string, level: number) -> ())?

function Locker.sync(player: Player)
	local s = State.get(player)
	if not s or typeof(player) ~= "Instance" then
		return
	end
	local l = s.data.Locker
	player:SetAttribute("FP", l.FP)
	player:SetAttribute("FPEarned", l.Earned)
	player:SetAttribute("RunStart", l.RunStart)
	-- (Rewards writes it every minute; on join it isn't there yet)
	player:SetAttribute("PlayMinutes", s.data.PlayMinutes)
	for _, p in Config.Perks do
		player:SetAttribute(Rules.attr(p.id), Rules.level(l.Perks, p.id))
	end
end

-- Head Start: the run's upgrade levels are at least the perk's start levels.
function Locker.applyHeadStart(s: State.PlayerState)
	local levels = s.data.Levels :: any
	for track, level in Rules.headStart(s.data.Locker.Perks) do
		if typeof(levels[track]) == "number" and levels[track] < level then
			levels[track] = level
		end
	end
end

function Locker.grant(player: Player, points: number)
	local s = State.get(player)
	if not s or points <= 0 then
		return
	end
	local l = s.data.Locker
	l.FP += math.floor(points)
	l.Earned += math.floor(points)
	Locker.sync(player)
end

-- An escape just happened (before the reset): the base (+ fast) points, and a new run starts.
function Locker.onEscape(player: Player): number
	local s = State.get(player)
	if not s then
		return 0
	end
	local l = s.data.Locker
	local points = Rules.escapePoints(s.data.PlayMinutes - l.RunStart)
	Locker.grant(player, points)
	l.RunStart = s.data.PlayMinutes
	pending[player] = points
	Locker.sync(player)
	return points
end

-- THE BREAKOUT ended (Breakout.onFinish; medal "" = none / out of time). Only a run that came from
-- a real escape counts (admin practice runs have nothing pending).
function Locker.onBreakout(player: Player, medal: string)
	local base = pending[player]
	if not base then
		return
	end
	pending[player] = nil
	local bonus = Rules.medalPoints(medal)
	Locker.grant(player, bonus)
	local s = State.get(player)
	Net.fire(player, Remotes.Names.Freedom, base + bonus, if s then s.data.Locker.FP else 0, bonus > 0)
end

local function nearLocker(player: Player, s: State.PlayerState): boolean
	local root = State.root(player)
	local cell = world and s.cell and world.cells[s.cell]
	local part = cell and cell.locker
	return root ~= nil and part ~= nil and (root - part.Position).Magnitude <= Config.Range + 6
end

-- Returns the new level, or nil and the reason the purchase was refused.
function Locker.buy(player: Player, id: string): (number?, string?)
	local s = State.get(player)
	if not s then
		return nil, "no state"
	end
	local perk = Rules.perk(id)
	if not perk then
		return nil, "unknown perk"
	end
	if not nearLocker(player, s) then
		return nil, "too far"
	end
	local l = s.data.Locker
	local cost = Rules.nextCost(l.Perks, id)
	if not cost then
		Net.notice(player, "That perk is maxed!", "info")
		return nil, "maxed"
	end
	if l.FP < cost then
		Net.notice(player, "Not enough Freedom Points 🗝️ Escape to earn more!", "bad")
		return nil, "poor"
	end
	l.FP -= cost
	local level = Rules.level(l.Perks, id) + 1
	l.Perks[id] = level
	if id == "HeadStart" then
		Locker.applyHeadStart(s)
	end
	Net.notice(player, string.format("%s %s level %d!", perk.emoji, perk.name, level), "upgrade")
	Locker.sync(player)
	Stats.sync(player)
	if Locker.onBought then
		Locker.onBought(player, id, level)
	end
	return level, nil
end

-- The strength an escape leaves you with (Muscle Memory).
function Locker.strengthAfterEscape(s: State.PlayerState): number
	return Rules.strengthAfterEscape(s.data.Locker.Perks, s.data.Strength, Economy.StartingStrength)
end

-- Extra find chance at night (Night Owl), for Dig.findBoost.
function Locker.nightBonus(player: Player): number
	local s = State.get(player)
	return if s then Rules.nightBonus(s.data.Locker.Perks) else 0
end

function Locker.onLeaving(player: Player)
	pending[player] = nil
end

function Locker.start(w: any)
	world = w
	for index, cell in world.cells do
		local prompt = cell.locker and cell.locker:FindFirstChild("LockerPrompt") :: ProximityPrompt?
		if prompt then
			prompt.Triggered:Connect(function(player)
				local s = State.get(player)
				if not s then
					return
				end
				if s.cell ~= index then
					Net.notice(player, "That's someone else's locker 🔒", "info")
					return
				end
				Net.fire(player, Remotes.Names.OpenLocker)
			end)
		end
	end
	local limit = RateLimit.new(2, 4)
	Net.on(Remotes.Names.LockerBuy, function(player, id)
		if limit(player) and typeof(id) == "string" and #id <= 24 then
			Locker.buy(player, id)
		end
	end)
end

return Locker
