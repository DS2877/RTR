--!strict
local Pass = require("../src/shared/Pass")
local Config = require("../src/shared/Config/Pass")

return function()
	-- seasons
	assert(Pass.season(Config.Epoch - 1) == 0, "nothing before the first season")
	assert(Pass.season(Config.Epoch) == 1, "season 1 starts at the epoch")
	local len = Config.SeasonDays * 86400
	assert(Pass.season(Config.Epoch + len - 1) == 1, "still season 1 on its last second")
	assert(Pass.season(Config.Epoch + len) == 2, "season 2 after")
	assert(Pass.seasonEnds(Config.Epoch + 5) == Config.Epoch + len, "season 1 ends")
	-- the epoch is a Monday 00:00 UTC
	assert(Config.Epoch % 86400 == 0 and ((Config.Epoch // 86400) + 3) % 7 == 0, "epoch is a Monday midnight")
	-- tiers
	assert(Pass.tier(0) == 0, "no tier at 0 XP")
	assert(Pass.tier(Config.TierXp) == 1, "tier 1")
	assert(Pass.tier(Config.TierXp * 100) == #Config.Tiers, "capped")
	local _, into = Pass.tier(Config.TierXp + 7)
	assert(into == 7, "xp into the next tier")
	-- every tier has two rewards, all known kinds
	local kinds = { noodles = true, dynamite = true, uniform = true, fist = true, pet = true }
	for i = 1, #Config.Tiers do
		for _, premium in { false, true } do
			local r = Pass.reward(i, premium)
			assert(r and kinds[r.kind], "known reward kind at tier " .. i)
			if r.kind == "noodles" or r.kind == "dynamite" then
				assert((r.n or 0) > 0, "an amount at tier " .. i)
			else
				assert(typeof(r.id) == "string", "an item id at tier " .. i)
			end
			assert(Pass.text(r, 15) ~= "", "a text at tier " .. i)
		end
	end
	assert(#Config.Tiers == 30, "30 tiers")
end
