--!strict
-- World layout, like the genre: a big grass plaza inside giant checker walls, all bases side by
-- side in ONE row on the west side facing east, their treadmills out on the grass in front, and
-- Rich Street leaving from the middle of the east wall, pointing straight at the bases.
-- X runs from the bases (x = BaseFrontX) across the plaza (x = StreetStartX) out along the street.
-- Look: bright, saturated, studded LEGO-style bricks everywhere.

local World = {
	BaseCount = 8, -- also the server size
	BaseFrontX = -150, -- the bases' entrances (they face +X, across the plaza at the street)
	BaseWidth = 92,
	BaseGap = 4, -- between neighbouring bases' fences
	BaseDepth = 72,
	WallHeight = 4.5, -- low walls: open plaza, loot visible (an invisible barrier stops jumping in)
	EntranceWidth = 18,
	PedestalColumns = 10,
	PedestalRows = 3,
	PedestalSpacingX = 8.4,
	PedestalRowDepth = { 47, 56, 65 }, -- pedestal rows on the raised stage at the back of the base
	StageDepth = 40, -- the stage starts this far into the base and runs to the back wall
	StageHeight = 1.6,

	BaseColors = {
		{ 255, 90, 90 },
		{ 70, 160, 255 },
		{ 90, 210, 110 },
		{ 255, 190, 50 },
		{ 180, 100, 255 },
		{ 255, 130, 200 },
		{ 60, 220, 220 },
		{ 255, 140, 50 },
	},

	PlazaWallHeight = 60, -- the giant checker walls around the plaza
	-- Rich Street: one long corridor; the rich people's zones follow each other and you run
	-- straight through them (farther = richer). Zone i starts at StreetStartX + ZoneGap + (i-1)*VaultSpacing.
	StreetStartX = 0, -- the street's mouth in the plaza's east wall
	ZoneGap = 20, -- entry hall between the gate and the first zone
	VaultSpacing = 130, -- zone length along the corridor
	ZoneHalfWidth = 48, -- corridor half width (walls at +-this)
	PathHalfWidth = 7, -- the running path down the middle of every zone
	ZoneWallHeight = 28, -- tall brick walls: each street feels like its own place
	-- Looks by level: plot level where each palace tier starts (shack, cottage, manor, mansion,
	-- palace, royal palace) and treadmill level where each treadmill tier starts
	PalaceTierLevels = { 1, 3, 5, 7, 9, 12 },
	TreadTierLevels = { 1, 4, 8, 13, 19, 25 },
	-- Day / night cycle (looks only): seconds of each phase, the HUD counts down to the next one
	DaySeconds = 240,
	NightSeconds = 120,
	VaultPedestals = 6,
}

return World
