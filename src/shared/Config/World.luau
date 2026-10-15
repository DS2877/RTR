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
	BrushDepth = 2, -- a brush cell that hits air digs up to this many layers deeper

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
