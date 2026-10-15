--!strict
local Voxel = require("../src/shared/Voxel")
local Shell = require("../src/shared/Shell")
local World = require("../src/shared/Config/World")

local function check(cond: boolean, msg: string)
	if not cond then
		error(msg, 2)
	end
end

local function count(g: any, radiusChunks: number?): (number, number)
	local blocks, runs = 0, 0
	for id = 0, g.ncx * g.ncy * g.ncz - 1 do
		local _, _, cz = Voxel.chunkCoords(g, id)
		if not radiusChunks or cz <= radiusChunks then
			local b, r = Shell.chunk(g, id)
			blocks += #b
			runs += #r
		end
	end
	return blocks, runs
end

return function()
	local W, H, D, C = World.TunnelWidth, World.TunnelHeight, World.TunnelDepth, World.ChunkSize
	local g = Voxel.new(W, H, D, C)
	local b, r = count(g)
	check(b == 0, "untouched wall has no single blocks")
	check(r == H * g.ncx, "untouched wall = one run per row per chunk column, got " .. r)

	-- one hole in the face: the block behind + the 4 around it get parts
	Voxel.dig(g, 8, 5, 0)
	b, r = count(g)
	check(b == 5, "one hole -> 5 blocks, got " .. b)

	-- STRESS (same as the admin !stress command): a 6x6 tunnel 120 deep with side rooms
	local s = Voxel.new(W, H, D, C)
	for z = 0, 119 do
		for y = 0, 5 do
			for x = 6, 11 do
				Voxel.dig(s, x, y, z)
			end
		end
		if z % 20 == 10 then
			for zz = z, z + 5 do
				for y = 0, 8 do
					for x = 1, 16 do
						Voxel.dig(s, x, y, zz)
					end
				end
			end
		end
	end
	local all = count(s)
	-- inside the stream radius (40 blocks = 5 chunks deep from the camera)
	local near = count(s, World.StreamRadius // C)
	print(string.format("      stress tunnel: %d shell parts total, %d within the stream radius", all, near))
	check(near <= World.MaxVoxelParts, "stress area must fit the part budget")
end
