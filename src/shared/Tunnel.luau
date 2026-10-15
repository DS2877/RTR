--!strict
-- Geometry of the cells and their tunnels (Roblox side: CFrames). Same answers on server and client.

local Config = script.Parent.Config
local World = require(Config.World)

local Tunnel = {}

local B = World.BlockSize
local HALF_W = World.TunnelWidth * B / 2

-- Row 0 cells face -Z, row 1 cells face +Z: tunnels grow away from the corridor and never meet.
function Tunnel.row(cell: number): number
	return (cell - 1) // World.CellsPerRow
end

function Tunnel.cellCenterX(cell: number): number
	local col = (cell - 1) % World.CellsPerRow
	return (col - (World.CellsPerRow - 1) / 2) * World.CellPitch
end

-- Bottom-center of the back wall's cell-side face. Local -Z points deeper into the tunnel.
function Tunnel.frame(cell: number): CFrame
	local wallZ = World.CorridorWidth / 2 + World.CellDepth
	if Tunnel.row(cell) == 0 then
		return CFrame.new(Tunnel.cellCenterX(cell), World.FloorY, -wallZ)
	end
	return CFrame.new(Tunnel.cellCenterX(cell), World.FloorY, wallZ) * CFrame.Angles(0, math.pi, 0)
end

-- Local position of a block's center relative to the frame.
function Tunnel.localCenter(x: number, y: number, z: number): Vector3
	return Vector3.new((x + 0.5) * B - HALF_W, (y + 0.5) * B, -(z + 0.5) * B)
end

function Tunnel.blockCenter(frame: CFrame, x: number, y: number, z: number): Vector3
	return frame:PointToWorldSpace(Tunnel.localCenter(x, y, z))
end

-- Block coordinates (may be out of bounds) of a world position.
function Tunnel.toBlock(frame: CFrame, pos: Vector3): (number, number, number)
	local p = frame:PointToObjectSpace(pos)
	return math.floor((p.X + HALF_W) / B), math.floor(p.Y / B), math.floor(-p.Z / B)
end

-- Is a world position inside the tunnel volume (plus a margin in blocks)?
function Tunnel.inside(frame: CFrame, pos: Vector3, margin: number?): boolean
	local m = margin or 0
	local x, y, z = Tunnel.toBlock(frame, pos)
	return x >= -m
		and y >= -m
		and z >= -m
		and x < World.TunnelWidth + m
		and y < World.TunnelHeight + m
		and z < World.TunnelDepth + m
end

-- World direction of a grid face normal (Voxel.Faces[i]).
function Tunnel.faceDirection(frame: CFrame, n: { number }): Vector3
	return frame:VectorToWorldSpace(Vector3.new(n[1], n[2], -n[3]))
end

return Tunnel
