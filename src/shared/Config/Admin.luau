--!strict
-- Admins can use chat commands for testing. The experience owner is always an admin (group-owned:
-- rank >= GroupMinRank). Everyone is an admin in Studio.
--   !cash 1e9   !speed 1e6   !item GoldBar Diamond   !reroll   !event GoldRush 90   !reset
local Admin = {
	UserIds = {} :: { number },
	GroupMinRank = 254,
}

return Admin
