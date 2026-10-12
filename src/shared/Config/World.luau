--!strict
-- World layout. X runs from the home plaza (x ~ 0) out along Rich Street (+X).
-- Look: bright, saturated, studded LEGO-style bricks everywhere (like the genre).

local World = {
	BaseCount = 8, -- also the server size
	BaseColumns = { -165, -55, 55, 165 }, -- X of each base (two rows of four)
	BaseRowZ = 30, -- front edge of a base, distance from the plaza center line
	BaseWidth = 100,
	BaseDepth = 72,
	WallHeight = 4.5, -- low walls: open plaza, loot visible (an invisible barrier stops jumping in)
	EntranceWidth = 18,
	PedestalColumns = 10,
	PedestalRows = 3,
	PedestalSpacingX = 9,
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

	PlazaHalfWidth = 230,
	-- Rich Street: one long corridor; the rich people's zones follow each other and you run
	-- straight through them (farther = richer). Zone i starts at StreetStartX + ZoneGap + (i-1)*VaultSpacing.
	StreetStartX = 240,
	ZoneGap = 20, -- entry hall between the gate and the first zone
	VaultSpacing = 130, -- zone length along the corridor
	ZoneHalfWidth = 48, -- corridor half width (walls at +-this)
	PathHalfWidth = 7, -- the running path down the middle of every zone
	ZoneWallHeight = 28, -- tall brick walls: each street feels like its own place
	-- Day / night cycle (looks only): seconds of each phase, the HUD counts down to the next one
	DaySeconds = 240,
	NightSeconds = 120,
	VaultPedestals = 6,
}

return World
