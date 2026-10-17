--!strict
-- Roblox badges (milestones). Create each badge in Creator Hub (Experience → Badges) and paste its
-- id here; an id of 0 means "not created yet" and is simply skipped (nothing breaks).

local Badges = {
	Welcome = 0, -- first time in the prison
	FirstVault = 0, -- cracked your first vault door
	Zone5 = 0, -- reached CLAY & PIPES
	Zone10 = 0, -- reached ANCIENT RUINS
	FirstEscape = 0, -- escaped for the first time
	GoldBreakout = 0, -- a GOLD medal on THE BREAKOUT
	Jackpot = 0, -- broke a jackpot vein
	SetComplete = 0, -- completed a zone's collection set
} :: { [string]: number }

return Badges
