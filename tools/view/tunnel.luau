--!strict
-- Adds what the CLIENT renders to a world dump: every cell's intact back wall, and a dug sample
-- tunnel in cell 1 (a 7x6 bore through all zones) with the same colors, materials and Strata
-- features as Controllers/VoxelRender.   lune run tools/view/tunnel > tunnel.txt
local Zones = require("../../src/shared/Config/Zones")
local World = require("../../src/shared/Config/World")
local Progression = require("../../src/shared/Progression")
local Strata = require("../../src/shared/Strata")

local B = World.BlockSize
local W, H, D = World.TunnelWidth, World.TunnelHeight, World.TunnelDepth
local BACK = World.CorridorWidth / 2 + World.CellDepth

local function cellX(cell: number): number
	local col = (cell - 1) % World.CellsPerRow
	return (col - (World.CellsPerRow - 1) / 2) * World.CellPitch
end

local function world(cell: number, x: number, y: number, z: number): (number, number, number)
	local lx, ly, lz = (x + 0.5) * B - W * B / 2, (y + 0.5) * B, -(z + 0.5) * B
	if (cell - 1) // World.CellsPerRow == 0 then
		return cellX(cell) + lx, ly, -BACK + lz
	end
	return cellX(cell) - lx, ly, BACK - lz
end

local function color(x: number, y: number, z: number): (number, number, number, string)
	local zone = Zones[Progression.zoneAt(z)]
	local pal = zone.palette
	local feature = Strata.featureAt(x, y, z)
	if feature then
		local look = Strata.Looks[feature]
		local s = 1 + ((Progression.hash01(0, x, y, z, 13) - 0.5) * 2 * (look.shade or 0))
		local c = look.color
		return math.min(255, c[1] * s), math.min(255, c[2] * s), math.min(255, c[3] * s), look.material
	end
	if z == 0 then
		return pal[1][1], pal[1][2], pal[1][3], zone.material
	end
	local h = Progression.hash01(0, x, y, z, 9)
	local c = pal[1 + math.floor(h * #pal) % #pal]
	local shade = 0.9 + Progression.hash01(0, x, y, z, 11) * 0.14
	return math.min(255, c[1] * shade),
		math.min(255, c[2] * shade),
		math.min(255, c[3] * shade),
		zone.material
end

local out: { string } = {}
local function part(
	px: number,
	py: number,
	pz: number,
	sx: number,
	sy: number,
	sz: number,
	r: number,
	g: number,
	b: number,
	mat: string
)
	table.insert(
		out,
		string.format(
			"P|Voxel|Block|%.2f|%.2f|%.2f|1|0|0|0|1|0|0|0|1|%.2f|%.2f|%.2f|%d|%d|%d|%s|0",
			px,
			py,
			pz,
			sx,
			sy,
			sz,
			math.floor(r),
			math.floor(g),
			math.floor(b),
			mat
		)
	)
end

-- intact back walls (one slab each) for cells 2..12
for cell = 2, World.CellCount do
	local x0, y0, z0 = world(cell, 0, 0, 0)
	local x1, _, _ = world(cell, W - 1, 0, 0)
	local c = Zones[1].palette[1]
	part((x0 + x1) / 2, H * B / 2, z0, W * B, H * B, B, c[1], c[2], c[3], Zones[1].material)
	local _ = y0
end

-- cell 1: a 7 wide x 6 high bore all the way down
local function dug(x: number, y: number, z: number): boolean
	return x >= 6 and x <= 12 and y >= 0 and y <= 5 and z >= 0 and z < D
end
for z = 0, D - 1 do
	for x = 0, W - 1 do
		for y = 0, H - 1 do
			if not dug(x, y, z) then
				local exposed = (z == 0) -- the back wall faces the cell
				for _, n in
					{ { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }
				do
					if dug(x + n[1], y + n[2], z + n[3]) then
						exposed = true
					end
				end
				if exposed then
					local px, py, pz = world(1, x, y, z)
					local r, g, b, mat = color(x, y, z)
					part(px, py, pz, B, B, B, r, g, b, mat)
					local f = Strata.featureAt(x, y, z)
					local look = f and Strata.Looks[f]
					if look and look.glow then
						table.insert(
							out,
							string.format(
								"L|PointLight|%.2f|%.2f|%.2f|%d|%d|%d|9|0.9",
								px,
								py,
								pz,
								look.glow[1],
								look.glow[2],
								look.glow[3]
							)
						)
					end
				end
			end
		end
	end
end
-- floor plates (VoxelRender: dug y = 0 rows) and the work lamps every 10 layers
for z = 0, D - 1 do
	local zone = Zones[Progression.zoneAt(z)]
	local c = zone.palette[1]
	local ax, _, az = world(1, 6, 0, z)
	local bx = world(1, 12, 0, z)
	part((ax + bx) / 2, 0.1, az, 7 * B, 0.2, B, c[1] * 0.82, c[2] * 0.82, c[3] * 0.82, zone.material)
	if z % 10 == 5 then
		local lx, ly, lz = world(1, 9, 5, z)
		table.insert(
			out,
			string.format(
				"P|Bulb|Ball|%.2f|%.2f|%.2f|1|0|0|0|1|0|0|0|1|0.55|0.55|0.55|255|196|120|Neon|0",
				lx,
				ly + B / 2 - 0.95,
				lz
			)
		)
		table.insert(
			out,
			string.format("L|PointLight|%.2f|%.2f|%.2f|255|190|120|18|1.3", lx, ly + B / 2 - 0.95, lz)
		)
	end
end
print(table.concat(out, "\n"))
