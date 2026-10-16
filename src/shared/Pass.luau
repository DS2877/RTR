--!strict
-- Prison Pass math (no Roblox APIs): which season it is, tiers from XP, reward texts.

local function config(name: string): any
	if script then
		return (require :: any)((script :: any).Parent.Config[name])
	end
	return (require :: any)("./Config/" .. name)
end
local Config = config("Pass")

local Pass = {}

local DAY = 86400

-- The season number at unix time t (1 = the first; 0 before the first started).
function Pass.season(t: number): number
	if t < Config.Epoch then
		return 0
	end
	return (t - Config.Epoch) // (Config.SeasonDays * DAY) + 1
end

-- Unix time the current season ends.
function Pass.seasonEnds(t: number): number
	local s = math.max(1, Pass.season(t))
	return Config.Epoch + s * Config.SeasonDays * DAY
end

-- Tiers reached with this much XP (0..#Tiers) and the XP into the next one.
function Pass.tier(xp: number): (number, number)
	local n = math.clamp(xp // Config.TierXp, 0, #Config.Tiers)
	return n, if n >= #Config.Tiers then 0 else xp - n * Config.TierXp
end

function Pass.reward(tierIndex: number, premium: boolean): any
	local t = Config.Tiers[tierIndex]
	if not t then
		return nil
	end
	return if premium then t.premium else t.free
end

-- How a reward reads ("🍜 1.2K", "🧨 x2", "🪖 Riot Gear"); `rubble` = your deepest zone's value.
function Pass.text(r: any, rubble: number, names: { [string]: string }?): string
	if r.kind == "noodles" then
		local n = r.n * rubble
		local s
		if n >= 1e6 then
			s = string.format("%.1fM", n / 1e6)
		elseif n >= 1e3 then
			s = string.format("%.1fK", n / 1e3)
		else
			s = tostring(math.floor(n))
		end
		return "🍜 " .. s
	elseif r.kind == "dynamite" then
		return "🧨 x" .. r.n
	end
	local name = names and names[r.id] or r.id
	return name
end

return Pass
