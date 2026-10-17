--!strict
-- PRISON PASS: pass XP from playing, tiers, claiming the free / premium reward of each tier. The
-- premium track is the "PrisonPass" developer product (Services/Product calls Pass.grantPremium);
-- it lasts for the season it was bought in. A new season starts everything over (XP, claims,
-- premium) but keeps whatever you earned. Attribute "Pass" (JSON) feeds the client panel.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Pass)
local PassMath = require(Shared.Pass)
local Zones = require(Shared.Config.Zones)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Loot = require(script.Parent.Loot)
local Stats = require(script.Parent.Stats)

local Pass = {}

Pass.onReward = nil :: ((player: Player, kind: string, id: string?) -> ())? -- cosmetics re-render

local blockLeft: { [any]: number } = {} -- blocks toward the next "per block" XP

local function data(s: State.PlayerState): any
	local p = s.data.Pass
	local season = PassMath.season(os.time())
	if not p then
		p = { Season = season, Xp = 0, Premium = false, Free = {}, Paid = {} }
		s.data.Pass = p
	end
	if p.Season ~= season then
		-- a new season: start over
		p.Season, p.Xp, p.Premium, p.Free, p.Paid = season, 0, false, {}, {}
	end
	return p
end

local function rubble(s: State.PlayerState): number
	local z = math.max(s.data.Zone, Progression.zoneAt(math.max(0, s.data.MaxDepth - 1)))
	return Zones[math.clamp(z, 1, #Zones)].rubble
end

function Pass.sync(player: any)
	local s = State.get(player)
	if not s or typeof(player) ~= "Instance" then
		return
	end
	local p = data(s)
	player:SetAttribute(
		"Pass",
		HttpService:JSONEncode({
			season = p.Season,
			xp = p.Xp,
			premium = p.Premium,
			free = p.Free,
			paid = p.Paid,
			ends = PassMath.seasonEnds(os.time()),
			rubble = rubble(s),
		})
	)
end

-- Pass XP for something you did (premium earns more). Returns the XP given.
function Pass.addXp(player: any, amount: number): number
	local s = State.get(player)
	if not s or amount <= 0 or PassMath.season(os.time()) <= 0 then
		return 0
	end
	local p = data(s)
	local before = PassMath.tier(p.Xp)
	local gain = math.floor(amount * (if p.Premium then 1 + Config.PremiumXpBoost else 1) + 0.5)
	p.Xp += gain
	local after = PassMath.tier(p.Xp)
	if after > before then
		Net.fire(player, Remotes.Names.PassTier, after)
	end
	Pass.sync(player)
	return gain
end

-- Dig.onBroken: 1 XP per BlocksPerXp blocks.
function Pass.countBlocks(player: any, n: number)
	local left = (blockLeft[player] or 0) + n
	local xp = left // Config.Xp.BlocksPerXp
	blockLeft[player] = left % Config.Xp.BlocksPerXp
	if xp > 0 then
		Pass.addXp(player, xp)
	end
end

local function give(player: any, s: State.PlayerState, r: any)
	if r.kind == "noodles" then
		local n = math.floor(r.n * rubble(s) + 0.5)
		Loot.addNoodles(player, n)
	elseif r.kind == "dynamite" then
		s.data.Dynamite += r.n
		if typeof(player) == "Instance" then
			player:SetAttribute("Dynamite", s.data.Dynamite)
		end
	elseif r.kind == "uniform" or r.kind == "fist" then
		s.data.Uniforms[r.id] = true
	end
	if Pass.onReward then
		Pass.onReward(player, r.kind, r.id)
	end
end

-- Claim tier `index` of a track (premium = the paid one). Returns a reason when refused.
function Pass.claim(player: any, index: any, premium: any): string?
	local s = State.get(player)
	if not s or typeof(index) ~= "number" or index % 1 ~= 0 or typeof(premium) ~= "boolean" then
		return "bad args"
	end
	local p = data(s)
	local reached = PassMath.tier(p.Xp)
	if index < 1 or index > reached then
		return "locked"
	end
	if premium and not p.Premium then
		return "not premium"
	end
	local claimed = if premium then p.Paid else p.Free
	if claimed[tostring(index)] then
		return "claimed"
	end
	local r = PassMath.reward(index, premium)
	if not r then
		return "bad args"
	end
	claimed[tostring(index)] = true
	give(player, s, r)
	Stats.sync(player)
	Pass.sync(player)
	Net.fire(player, Remotes.Names.PassClaimed, index, premium)
	return nil
end

-- The PrisonPass product was bought (idempotent for the season).
function Pass.grantPremium(player: any): boolean
	local s = State.get(player)
	if not s then
		return false
	end
	local p = data(s)
	p.Premium = true
	Pass.sync(player)
	Net.notice(player, "🎫 PRISON PASS PREMIUM unlocked for this season! Claim your rewards.", "good")
	return true
end

function Pass.onLeaving(player: any)
	blockLeft[player] = nil
end

function Pass.start()
	local limit = RateLimit.new(4, 8)
	Net.on(Remotes.Names.PassClaim, function(player, index, premium)
		if limit(player) then
			Pass.claim(player, index, premium)
		end
	end)
end

return Pass
