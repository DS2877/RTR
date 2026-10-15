--!strict
-- The digging grid of one tunnel: which blocks are dug, as per-chunk bitsets (chunk = 8x8x8 blocks
-- = 64 bytes). Pure Luau (buffers, no Roblox APIs): used by the server, every client and Lune tests.
--
-- Saved form: every chunk's 64 bytes in chunk order -> RLE (runs of 0x00 / 0xFF bytes) -> base64.
-- A fresh tunnel saves as a few dozen characters; a fully dug one as well.

local Voxel = {}

export type Grid = {
	w: number,
	h: number,
	d: number,
	cs: number,
	ncx: number,
	ncy: number,
	ncz: number,
	chunkBytes: number,
	chunks: { [number]: buffer }, -- chunk id -> bits (only chunks with something dug)
	count: number, -- dug blocks
}

function Voxel.new(w: number, h: number, d: number, cs: number): Grid
	local bits = cs * cs * cs
	assert(bits % 8 == 0, "chunk bits must be whole bytes")
	return {
		w = w,
		h = h,
		d = d,
		cs = cs,
		ncx = math.ceil(w / cs),
		ncy = math.ceil(h / cs),
		ncz = math.ceil(d / cs),
		chunkBytes = bits // 8,
		chunks = {},
		count = 0,
	}
end

function Voxel.inBounds(g: Grid, x: number, y: number, z: number): boolean
	return x >= 0 and y >= 0 and z >= 0 and x < g.w and y < g.h and z < g.d
end

-- Flat block index (also the wire format of a block): x + w * (y + h * z)
function Voxel.index(g: Grid, x: number, y: number, z: number): number
	return x + g.w * (y + g.h * z)
end

function Voxel.unindex(g: Grid, i: number): (number, number, number)
	local x = i % g.w
	local rest = i // g.w
	return x, rest % g.h, rest // g.h
end

function Voxel.chunkId(g: Grid, cx: number, cy: number, cz: number): number
	return cx + g.ncx * (cy + g.ncy * cz)
end

function Voxel.chunkCoords(g: Grid, id: number): (number, number, number)
	local cx = id % g.ncx
	local rest = id // g.ncx
	return cx, rest % g.ncy, rest // g.ncy
end

function Voxel.chunkOf(g: Grid, x: number, y: number, z: number): number
	return Voxel.chunkId(g, x // g.cs, y // g.cs, z // g.cs)
end

local function locate(g: Grid, x: number, y: number, z: number): (number, number, number)
	local cs = g.cs
	local id = Voxel.chunkId(g, x // cs, y // cs, z // cs)
	local bit = (x % cs) + cs * ((y % cs) + cs * (z % cs))
	return id, bit // 8, bit % 8
end

function Voxel.isDug(g: Grid, x: number, y: number, z: number): boolean
	local id, byte, bit = locate(g, x, y, z)
	local c = g.chunks[id]
	if not c then
		return false
	end
	return bit32.btest(buffer.readu8(c, byte), bit32.lshift(1, bit))
end

-- Returns true if the block was solid (and is now dug).
function Voxel.dig(g: Grid, x: number, y: number, z: number): boolean
	if not Voxel.inBounds(g, x, y, z) then
		return false
	end
	local id, byte, bit = locate(g, x, y, z)
	local c = g.chunks[id]
	if not c then
		c = buffer.create(g.chunkBytes)
		g.chunks[id] = c
	end
	local v = buffer.readu8(c, byte)
	local mask = bit32.lshift(1, bit)
	if bit32.btest(v, mask) then
		return false
	end
	buffer.writeu8(c, byte, bit32.bor(v, mask))
	g.count += 1
	return true
end

-- Solid = inside the grid and not dug. Outside the grid is bedrock (also "not air").
function Voxel.isSolid(g: Grid, x: number, y: number, z: number): boolean
	return Voxel.inBounds(g, x, y, z) and not Voxel.isDug(g, x, y, z)
end

-- Air you can stand in: a dug block, or the cell in front of the back wall (z = -1).
function Voxel.isOpen(g: Grid, x: number, y: number, z: number): boolean
	if z == -1 then
		return x >= 0 and y >= 0 and x < g.w and y < g.h
	end
	return Voxel.inBounds(g, x, y, z) and Voxel.isDug(g, x, y, z)
end

Voxel.Faces = {
	{ 1, 0, 0 },
	{ -1, 0, 0 },
	{ 0, 1, 0 },
	{ 0, -1, 0 },
	{ 0, 0, 1 },
	{ 0, 0, -1 },
}

-- A solid block you can punch: it touches open air on at least one face.
function Voxel.isExposed(g: Grid, x: number, y: number, z: number): boolean
	if not Voxel.isSolid(g, x, y, z) then
		return false
	end
	for _, f in Voxel.Faces do
		if Voxel.isOpen(g, x + f[1], y + f[2], z + f[3]) then
			return true
		end
	end
	return false
end

-- Deepest dug layer + 1 (0 for an untouched wall). Scans chunk slabs from the back.
function Voxel.depth(g: Grid): number
	for cz = g.ncz - 1, 0, -1 do
		local any = false
		for cy = 0, g.ncy - 1 do
			for cx = 0, g.ncx - 1 do
				if g.chunks[Voxel.chunkId(g, cx, cy, cz)] then
					any = true
				end
			end
		end
		if any then
			for z = math.min(g.d - 1, cz * g.cs + g.cs - 1), cz * g.cs, -1 do
				for y = 0, g.h - 1 do
					for x = 0, g.w - 1 do
						if Voxel.isDug(g, x, y, z) then
							return z + 1
						end
					end
				end
			end
		end
	end
	return 0
end

-- ===== serialization =====

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local ENC: { string } = {}
local DEC: { [number]: number } = {}
for i = 1, 64 do
	ENC[i - 1] = string.sub(ALPHABET, i, i)
	DEC[string.byte(ALPHABET, i)] = i - 1
end

function Voxel.base64(bytes: buffer, n: number): string
	local out = table.create(math.ceil(n / 3) * 4)
	for i = 0, n - 1, 3 do
		local a = buffer.readu8(bytes, i)
		local b = if i + 1 < n then buffer.readu8(bytes, i + 1) else 0
		local c = if i + 2 < n then buffer.readu8(bytes, i + 2) else 0
		local v = a * 65536 + b * 256 + c
		table.insert(out, ENC[v // 262144])
		table.insert(out, ENC[(v // 4096) % 64])
		table.insert(out, if i + 1 < n then ENC[(v // 64) % 64] else "=")
		table.insert(out, if i + 2 < n then ENC[v % 64] else "=")
	end
	return table.concat(out)
end

function Voxel.unbase64(s: string): (buffer, number)
	local len = #s
	local out = buffer.create(math.max(1, len // 4 * 3))
	local n = 0
	for i = 1, len - 3, 4 do
		local c1, c2, c3, c4 = string.byte(s, i, i + 3)
		local v = (DEC[c1] or 0) * 262144 + (DEC[c2] or 0) * 4096 + (DEC[c3] or 0) * 64 + (DEC[c4] or 0)
		buffer.writeu8(out, n, v // 65536)
		n += 1
		if c3 ~= 61 then -- "="
			buffer.writeu8(out, n, (v // 256) % 256)
			n += 1
		end
		if c4 ~= 61 then
			buffer.writeu8(out, n, v % 256)
			n += 1
		end
	end
	return out, n
end

-- RLE: 0x00 n = n zero bytes, 0xFF n = n 0xFF bytes (n = 1..255), anything else is literal.
function Voxel.serialize(g: Grid): string
	local total = g.ncx * g.ncy * g.ncz * g.chunkBytes
	local out = buffer.create(total * 2 + 2)
	local n = 0
	local runByte = -1
	local run = 0
	local function flush()
		if run > 0 then
			buffer.writeu8(out, n, runByte)
			buffer.writeu8(out, n + 1, run)
			n += 2
			run = 0
		end
	end
	local nchunks = g.ncx * g.ncy * g.ncz
	for id = 0, nchunks - 1 do
		local c = g.chunks[id]
		for i = 0, g.chunkBytes - 1 do
			local v = if c then buffer.readu8(c, i) else 0
			if v == 0 or v == 255 then
				if runByte ~= v or run == 255 then
					flush()
					runByte = v
				end
				run += 1
			else
				flush()
				runByte = -1
				buffer.writeu8(out, n, v)
				n += 1
			end
		end
	end
	flush()
	return Voxel.base64(out, n)
end

-- Rebuilds a grid from Voxel.serialize output. Bad or empty input gives an untouched grid.
function Voxel.deserialize(s: string?, w: number, h: number, d: number, cs: number): Grid
	local g = Voxel.new(w, h, d, cs)
	if not s or s == "" then
		return g
	end
	local bytes, n = Voxel.unbase64(s)
	local cb = g.chunkBytes
	local nchunks = g.ncx * g.ncy * g.ncz
	local pos = 0 -- position in the decoded chunk stream
	local function put(v: number)
		local id = pos // cb
		if v ~= 0 and id < nchunks then
			local c = g.chunks[id]
			if not c then
				c = buffer.create(cb)
				g.chunks[id] = c
			end
			buffer.writeu8(c, pos % cb, v)
		end
		pos += 1
	end
	local i = 0
	while i < n do
		local v = buffer.readu8(bytes, i)
		if (v == 0 or v == 255) and i + 1 < n then
			local run = buffer.readu8(bytes, i + 1)
			if v == 0 then
				pos += run
			else
				for _ = 1, run do
					put(255)
				end
			end
			i += 2
		else
			put(v)
			i += 1
		end
	end
	-- recount dug blocks, and drop bits outside the grid (chunks at the edges are partial)
	local count = 0
	for id, c in g.chunks do
		local cx, cy, cz = Voxel.chunkCoords(g, id)
		for b = 0, cb * 8 - 1 do
			local byte = buffer.readu8(c, b // 8)
			local mask = bit32.lshift(1, b % 8)
			if bit32.btest(byte, mask) then
				local lx = b % cs
				local ly = (b // cs) % cs
				local lz = b // (cs * cs)
				if Voxel.inBounds(g, cx * cs + lx, cy * cs + ly, cz * cs + lz) then
					count += 1
				else
					buffer.writeu8(c, b // 8, bit32.band(byte, bit32.bnot(mask)))
				end
			end
		end
	end
	g.count = count
	return g
end

return Voxel
