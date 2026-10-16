--!strict
-- Pure: today's three WORK DETAIL jobs for a player (Config/Missions). Deterministic from the day
-- number and the player's seed, so the server can rebuild them any time without saving them.

-- Works in Roblox (script.Parent) and in Lune (relative path requires).
local Config = if script
	then (require :: any)((script :: any).Parent.Config.Missions)
	else (require :: any)("./Config/Missions")

local Missions = {}

export type Picked = { id: string, text: string, stat: string, goal: number, reward: number, emoji: string }

-- a small LCG so the pick is the same everywhere (Lune tests, server)
local function rng(seed: number): () -> number
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end

-- excludeDepth: the player can't dig deeper right now (at the bottom of the open zones)
function Missions.pick(day: number, seed: number, excludeDepth: boolean?): { Picked }
	local rand = rng(day * 7919 + seed % 100000 * 13 + 17)
	local pool = {}
	for _, job in Config.Pool do
		if not (excludeDepth and job.stat == "Depth") then
			table.insert(pool, job)
		end
	end
	local out: { Picked } = {}
	for tier = 1, Config.PerDay do
		if #pool == 0 then
			break
		end
		local i = math.clamp(math.floor(rand() * #pool) + 1, 1, #pool)
		local job = table.remove(pool, i) :: any
		local goal = job.goals[tier] or job.goals[#job.goals]
		table.insert(out, {
			id = job.id,
			text = string.format(job.text, goal),
			stat = job.stat,
			goal = goal,
			reward = math.floor(job.reward * (Config.TierMult[tier] or 1)),
			emoji = job.emoji,
		})
	end
	return out
end

return Missions
