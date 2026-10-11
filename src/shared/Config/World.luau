--!strict
-- World layout. X runs from the home plaza (x ~ 0) out along Rich Street (+X).

local World = {
	BaseCount = 8, -- also the server size
	BaseColumns = { -165, -55, 55, 165 }, -- X of each base (two rows of four)
	BaseRowZ = 30, -- front edge of a base, distance from the plaza center line
	BaseWidth = 100,
	BaseDepth = 72,
	WallHeight = 12,
	EntranceWidth = 18,
	PedestalColumns = 10,
	PedestalRows = 3,
	PedestalSpacingX = 9,
	PedestalRowDepth = { 18, 30, 42 }, -- distance into the base for each pedestal row

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
	StreetStartX = 240,
	StreetHalfWidth = 24,
	VaultSpacing = 130,
	VaultWidth = 92, -- along the street
	VaultDepth = 70,
	VaultOffsetZ = 30, -- vault front edge distance from the street center line
	VaultPedestals = 6,
}

return World
