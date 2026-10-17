--!strict
-- World layout and digging grid. Every size is in studs unless the name says "blocks".
--
-- Coordinates of a tunnel: x (0..Width-1, across), y (0..Height-1, up), z (0..Depth-1, deeper).
-- z = 0 is the back wall of the cell. The tunnel's CFrame ("frame") sits at the bottom-center of the
-- back wall's cell-side face; local -Z of the frame points deeper into the tunnel.

local World = {
	-- voxel grid
	BlockSize = 2,
	TunnelWidth = 18, -- blocks
	TunnelHeight = 12, -- blocks
	TunnelDepth = 600, -- blocks
	ChunkSize = 8, -- blocks per chunk edge (8x8x8 = 512 bits = 64 bytes)

	-- cell block: two rows of 6 cells facing each other across a corridor along X
	CellCount = 12,
	CellsPerRow = 6,
	CellPitch = 40, -- cell width (36 = tunnel width) + 4 stud wall
	CellDepth = 20, -- from the corridor (door) to the back wall
	CorridorWidth = 24,
	FloorY = 0, -- top of the floor everywhere inside
	WallThickness = 4,

	-- where the other areas sit: center X, Z and size X, Z (studs), all on the floor level
	-- (both at the -X end of the corridor so a trip from any cell is short)
	CommonRoom = { x = -182, z = 0, sx = 120, sz = 96, height = 26 },
	Yard = { x = -330, z = 0, sx = 176, sz = 150 },

	-- digging rules
	Reach = 11, -- studs from HumanoidRootPart to the target block's center (client aims inside this)
	ReachSlack = 6, -- extra studs the server allows for latency
	AttackInterval = 0.32, -- seconds between punches (hold = auto-punch at this rate)
	CritChance = 0.08, -- share of punches that are CRITs (server rolls it)...
	CritMult = 3, -- ...hitting this many times harder
	BrushDepth = 2, -- a brush cell that hits air digs up to this many layers deeper

	-- COMBO: punches that land with less than ComboWindow seconds between them build a chain
	-- (holding VACUUM pauses the clock). The tier multiplies the Noodles the broken rubble is worth.
	ComboWindow = 1.6,
	ComboVacuumPause = 4, -- holding VACUUM pauses the chain clock for at most this long
	ComboTiers = {
		{ hits = 0, mult = 1, name = "" },
		{ hits = 12, mult = 1.25, name = "ON A ROLL" },
		{ hits = 35, mult = 1.5, name = "ON FIRE" },
		{ hits = 75, mult = 2, name = "UNSTOPPABLE" },
		{ hits = 140, mult = 3, name = "PRISON BREAK" },
	},
	-- GOLD: rare glittering blocks (fixed per tunnel by its seed, visible as soon as they're
	-- exposed) pay their worth in Noodles the moment they break: GoldBlocks / JackpotBlocks blocks
	-- of that zone's rubble, with every Noodles multiplier. A JACKPOT is announced to the server.
	GoldChance = 1 / 220,
	GoldBlocks = 14,
	JackpotChance = 1 / 2600,
	JackpotBlocks = 220,
	-- CAVE-IN: each broken block may bring down the exposed rock around it (within CaveInRadius
	-- blocks, at most CaveInMax blocks); CaveInExpected = the average extra blocks (balance sim)
	CaveInChance = 0.012,
	CaveInRadius = 2,
	CaveInMax = 14,
	CaveInExpected = 7,
	-- VAULT DOORS: each zone's sealed chamber is guarded by a door. Breaking next to the chamber
	-- brings it out; punching the chamber hits the door (one hit per punch, whatever the brush).
	-- HP = BossBlocks blocks of the zone before it; everyone who hit it gets BossReward blocks of
	-- the new zone's rubble when it cracks.
	BossBlocks = 14,
	BossReward = 60,

	-- client rendering budget (iPhone 11)
	StreamRadius = 40, -- blocks around the camera
	MaxVoxelParts = 3000,
	MaxDebris = 150,
	DebrisPerBlock = 4,
	DebrisLifetime = 4,
	-- other players' tunnels are only rendered this deep while your camera is outside them
	OutsideRenderDepth = 16,

	-- loose rubble (vacuum)
	PileMergeRadius = 5,
	MaxPiles = 60,
}

return World
