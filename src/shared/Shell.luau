--!strict
-- Which blocks of a chunk a client must draw: the "shell" of the tunnel. Pure (Lune-tested).
--   blocks: solid blocks touching dug air (each gets its own part), plus `special` back-wall blocks
--           (damaged or ore) so they can show cracks / glints.
--   runs:   the rest of the intact back wall (z = 0), merged into horizontal runs (one part each).

local function shared(name: string): any
	if script then
		return (require :: any)((script :: any).Parent[name])
	end
	return (require :: any)("./" .. name)
end

local Voxel = shared("Voxel")

local Shell = {}

export type Run = { x0: number, x1: number, y: number }

local FACES = Voxel.Faces

local function touchesDug(g: any, x: number, y: number, z: number): boolean
	for _, f in FACES do
		local nx, ny, nz = x + f[1], y + f[2], z + f[3]
		if Voxel.inBounds(g, nx, ny, nz) and Voxel.isDug(g, nx, ny, nz) then
			return true
		end
	end
	return false
end

function Shell.chunk(
	g: any,
	chunkId: number,
	special: ((number, number, number) -> boolean)?
): ({ number }, { Run })
	local cx, cy, cz = Voxel.chunkCoords(g, chunkId)
	local cs = g.cs
	local x0, y0, z0 = cx * cs, cy * cs, cz * cs
	local x1 = math.min(g.w, x0 + cs) - 1
	local y1 = math.min(g.h, y0 + cs) - 1
	local z1 = math.min(g.d, z0 + cs) - 1
	local blocks: { number } = {}
	local runs: { Run } = {}
	local hasDug = g.chunks[chunkId] ~= nil
	-- a chunk with nothing dug can still border a dug neighbor chunk: check neighbors cheaply
	local nearDug = hasDug
	if not nearDug then
		for _, f in FACES do
			local ncx, ncy, ncz = cx + f[1], cy + f[2], cz + f[3]
			if ncx >= 0 and ncy >= 0 and ncz >= 0 and ncx < g.ncx and ncy < g.ncy and ncz < g.ncz then
				if g.chunks[Voxel.chunkId(g, ncx, ncy, ncz)] then
					nearDug = true
					break
				end
			end
		end
	end
	if nearDug then
		for z = z0, z1 do
			for y = y0, y1 do
				for x = x0, x1 do
					if not Voxel.isDug(g, x, y, z) and touchesDug(g, x, y, z) then
						table.insert(blocks, Voxel.index(g, x, y, z))
					end
				end
			end
		end
	end
	if z0 == 0 then
		local own: { [number]: boolean } = {}
		for _, i in blocks do
			own[i] = true
		end
		for y = y0, y1 do
			local start: number? = nil
			for x = x0, x1 + 1 do
				local face = false
				if x <= x1 and not Voxel.isDug(g, x, y, 0) then
					local i = Voxel.index(g, x, y, 0)
					if not own[i] then
						if special and special(x, y, 0) then
							table.insert(blocks, i)
							own[i] = true
						else
							face = true
						end
					end
				end
				if face and not start then
					start = x
				elseif not face and start then
					table.insert(runs, { x0 = start, x1 = x - 1, y = y })
					start = nil
				end
			end
		end
	end
	return blocks, runs
end

return Shell
