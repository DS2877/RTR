--!strict
-- Day-time PvP: Yard Brawl (slapstick knockback, no blood) and Cell Raids on Stash chests.

local PvP = {
	-- Yard Brawl
	MaxStamina = 100,
	StaminaRegen = 12, -- per second, after RegenDelay seconds without being hit
	RegenDelay = 3,
	BaseDamage = 14, -- scaled by sqrt(attacker / defender strength), clamped
	DamageMin = 0.5,
	DamageMax = 2,
	NewbieMinutes = 20, -- new prisoners (less play time than this) can't brawl or be hit
	PunchRange = 9, -- studs between root parts
	PunchCooldown = 0.55,
	Knockback = 55, -- studs/s away from the attacker
	KnockUp = 28,
	KnockoutDropShare = 0.3, -- share of the backpack rubble dropped on a knockout
	KnockoutDropsFind = true, -- one find from your slots drops too
	SpawnProtection = 8, -- seconds nobody can hit you after a knockout
	DropLifetime = 90, -- seconds a dropped pile stays on the floor
	PickupRange = 6,
	SafeRadiusShop = 16, -- studs around shop counters
	SafeRadiusGym = 14, -- studs around gym stations
	SafeRadiusDump = 12,

	-- Cell Raids
	StashSize = 12, -- finds a Stash chest holds
	CarrySpeed = 12, -- walk speed while carrying a stolen find
	-- Lock levels (Upgrades.Lock): seconds the thief must hold STEAL
	-- Trap (Upgrades.Trap): the thief slips on soap for TrapSeconds when they start
	TrapSeconds = 2.5,
	-- Alarm (Upgrades.Alarm): owner gets a notice + a beam to the thief
}

return PvP
