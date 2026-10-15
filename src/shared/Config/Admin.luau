--!strict
-- Admins get the ADMIN button (phone testing). The experience owner is always an admin
-- (group-owned: rank >= GroupMinRank). Everyone is an admin in Studio.
local Admin = {
	UserIds = {} :: { number },
	GroupMinRank = 254,
}

return Admin
