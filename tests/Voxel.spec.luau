--!strict
local Voxel = require("../src/shared/Voxel")

local function check(cond: boolean, msg: string)
	if not cond then
		error(msg, 2)
	end
end

return function()
	local g = Voxel.new(18, 12, 600, 8)
	check(g.ncx == 3 and g.ncy == 2 and g.ncz == 75, "chunk counts")
	check(not Voxel.isDug(g, 0, 0, 0), "fresh grid is solid")
	check(Voxel.isExposed(g, 5, 5, 0), "back wall face is exposed")
	check(not Voxel.isExposed(g, 5, 5, 1), "second layer is buried")
	check(Voxel.dig(g, 5, 5, 0), "dig works")
	check(not Voxel.dig(g, 5, 5, 0), "dig twice is a no-op")
	check(not Voxel.dig(g, -1, 0, 0), "out of bounds can't be dug")
	check(Voxel.isExposed(g, 5, 5, 1), "block behind a hole is exposed")
	check(g.count == 1, "count")

	-- index round trip
	for _, p in { { 0, 0, 0 }, { 17, 11, 599 }, { 3, 7, 42 } } do
		local i = Voxel.index(g, p[1], p[2], p[3])
		local x, y, z = Voxel.unindex(g, i)
		check(x == p[1] and y == p[2] and z == p[3], "unindex " .. i)
	end

	-- serialize round trip: empty, sparse, dense, edge chunks
	check(Voxel.deserialize(Voxel.serialize(Voxel.new(18, 12, 600, 8)), 18, 12, 600, 8).count == 0, "empty")
	local seed = 7
	local function rand(lo: number, hi: number): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return lo + seed % (hi - lo + 1)
	end
	local h = Voxel.new(18, 12, 600, 8)
	for z = 0, 40 do
		for y = 0, 11 do
			for x = 0, 17 do
				Voxel.dig(h, x, y, z) -- a fully dug slab
			end
		end
	end
	for _ = 1, 3000 do
		Voxel.dig(h, rand(0, 17), rand(0, 11), rand(0, 599))
	end
	local s = Voxel.serialize(h)
	local back = Voxel.deserialize(s, 18, 12, 600, 8)
	check(back.count == h.count, string.format("count %d vs %d", back.count, h.count))
	for z = 0, 599 do
		for y = 0, 11 do
			for x = 0, 17 do
				if Voxel.isDug(back, x, y, z) ~= Voxel.isDug(h, x, y, z) then
					error(string.format("mismatch at %d %d %d", x, y, z))
				end
			end
		end
	end
	check(#Voxel.serialize(Voxel.new(18, 12, 600, 8)) < 400, "a fresh tunnel saves small")
	check(Voxel.depth(back) == Voxel.depth(h), "depth survives")
	check(Voxel.deserialize("garbage!!", 18, 12, 600, 8) ~= nil, "garbage does not crash")

	-- base64 round trip with every byte value
	local bytes = buffer.create(256)
	for i = 0, 255 do
		buffer.writeu8(bytes, i, i)
	end
	for n = 254, 256 do
		local decoded, m = Voxel.unbase64(Voxel.base64(bytes, n))
		check(m == n, "base64 length " .. n)
		for i = 0, n - 1 do
			check(buffer.readu8(decoded, i) == i, "base64 byte " .. i)
		end
	end
end
