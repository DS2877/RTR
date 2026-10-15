--!strict
-- What's inside the rock: deterministic, cosmetic features per zone (pipes in the clay, rebar in
-- the reinforced concrete, lava veins in the magma...). Pure (no Roblox APIs) so Lune tests it;
-- the client (VoxelRender) turns a feature into a color / material / glow / carved face.
-- Features never touch gameplay: hp, rubble and finds are the zone's as always.

local function shared(name: string): any
	if script then
		return (require :: any)((script :: any).Parent[name])
	end
	return (require :: any)("./" .. name)
end

local Progression = shared("Progression")

local Strata = {}

export type Look = {
	color: { number },
	material: string, -- Enum.Material name
	glow: { number }?, -- PointLight color (lights are capped on the client)
	carve: string?, -- "Tally" | "Glyph": a pattern scratched into the open faces
	shade: number?, -- random brightness spread (0 = none)
}

Strata.Looks = {
	Tally = { color = { 128, 132, 138 }, material = "Concrete", carve = "Tally" },
	Copper = { color = { 184, 110, 60 }, material = "Metal", shade = 0.08 },
	Bracket = { color = { 60, 62, 68 }, material = "Metal" },
	Conduit = { color = { 150, 156, 162 }, material = "Metal" },
	Aggregate = { color = { 170, 172, 168 }, material = "Pebble" },
	Rebar = { color = { 104, 110, 120 }, material = "Concrete", carve = "Rebar", shade = 0.04 },
	Terracotta = { color = { 196, 104, 60 }, material = "SmoothPlastic", shade = 0.06 },
	PipeInside = { color = { 26, 22, 20 }, material = "SmoothPlastic" },
	Iron = { color = { 96, 62, 48 }, material = "CorrodedMetal" },
	Pebble = { color = { 120, 112, 100 }, material = "Pebble", shade = 0.12 },
	Slime = { color = { 120, 220, 90 }, material = "Glass", glow = { 120, 255, 90 } },
	RustPipe = { color = { 110, 70, 50 }, material = "CorrodedMetal" },
	Grate = { color = { 50, 54, 58 }, material = "DiamondPlate" },
	Quartz = { color = { 186, 178, 210 }, material = "Marble", shade = 0.06 },
	Fossil = { color = { 226, 214, 186 }, material = "Limestone" },
	CrystalCyan = { color = { 70, 190, 230 }, material = "Neon", glow = { 90, 220, 255 } },
	CrystalPink = { color = { 220, 90, 190 }, material = "Neon", glow = { 255, 110, 220 } },
	CrystalViolet = { color = { 160, 100, 230 }, material = "Neon", glow = { 180, 110, 255 } },
	Lava = { color = { 255, 120, 30 }, material = "Neon", glow = { 255, 120, 40 } },
	Obsidian = { color = { 24, 20, 28 }, material = "Glass" },
	Pillar = { color = { 226, 200, 140 }, material = "Limestone", shade = 0.04 },
	Gold = { color = { 230, 180, 60 }, material = "Foil" },
	Glyph = { color = { 196, 166, 98 }, material = "Sandstone", carve = "Glyph" },
} :: { [string]: Look }

-- What floats in the air around the camera in each zone (by Zones[i].id): dust, drips, embers...
-- rise > 0 drifts up, < 0 falls. light = LightEmission (glowy embers / sparkles).
export type Air = { color: { number }, rate: number, size: number, rise: number, light: number }
Strata.Air = {
	Plaster = { color = { 220, 220, 225 }, rate = 6, size = 0.12, rise = -0.3, light = 0 },
	Brick = { color = { 210, 160, 130 }, rate = 7, size = 0.12, rise = -0.3, light = 0 },
	Concrete = { color = { 220, 225, 235 }, rate = 7, size = 0.12, rise = -0.3, light = 0 },
	Reinforced = { color = { 200, 205, 215 }, rate = 8, size = 0.12, rise = -0.4, light = 0 },
	Clay = { color = { 200, 150, 100 }, rate = 8, size = 0.14, rise = -0.5, light = 0 },
	Sewer = { color = { 160, 230, 150 }, rate = 10, size = 0.1, rise = -6, light = 0.3 },
	Bedrock = { color = { 180, 175, 200 }, rate = 6, size = 0.1, rise = -0.2, light = 0.2 },
	Crystal = { color = { 220, 170, 255 }, rate = 14, size = 0.14, rise = 0.3, light = 1 },
	Magma = { color = { 255, 140, 50 }, rate = 16, size = 0.12, rise = 2.5, light = 1 },
	Ruins = { color = { 255, 220, 140 }, rate = 9, size = 0.12, rise = 0.15, light = 0.6 },
} :: { [string]: Air }

local function h(x: number, y: number, z: number, salt: number): number
	return Progression.hash01(0, x, y, z, salt)
end

-- smooth 3D value noise (0..1) with features about `scale` blocks across: organic veins and
-- clusters instead of grid-looking patterns
local function noise(x: number, y: number, z: number, scale: number, salt: number): number
	local fx, fy, fz = x / scale, y / scale, z / scale
	local x0, y0, z0 = math.floor(fx), math.floor(fy), math.floor(fz)
	local function s(t: number): number
		return t * t * (3 - 2 * t)
	end
	local tx, ty, tz = s(fx - x0), s(fy - y0), s(fz - z0)
	local function lerp(a: number, b: number, t: number): number
		return a + (b - a) * t
	end
	local function v(i: number, j: number, k: number): number
		return Progression.hash01(0, x0 + i, y0 + j, z0 + k, salt)
	end
	return lerp(
		lerp(lerp(v(0, 0, 0), v(1, 0, 0), tx), lerp(v(0, 1, 0), v(1, 1, 0), tx), ty),
		lerp(lerp(v(0, 0, 1), v(1, 0, 1), tx), lerp(v(0, 1, 1), v(1, 1, 1), tx), ty),
		tz
	)
end
Strata.noise = noise

-- The feature at block (x, y, z), or nil for plain rock. z = 0 (the cell's back wall) is always
-- plain so the wall stays one seamless surface.
function Strata.featureAt(x: number, y: number, z: number): string?
	if z <= 0 then
		return nil
	end
	local zone = Progression.zoneAt(z)
	local zl = z - Progression.zoneStart(zone) -- layer inside the zone
	if zone == 1 then
		-- earlier escape attempts: tally marks scratched into the plaster
		if y >= 2 and y <= 8 and h(x, y, z, 31) < 0.012 then
			return "Tally"
		end
	elseif zone == 2 then
		-- an old copper water pipe on brackets, high on the left
		if x == 2 and y == 9 then
			return "Copper"
		elseif x == 2 and y == 10 and zl % 5 == 0 then
			return "Bracket"
		end
	elseif zone == 3 then
		if x == 15 and y == 10 then
			return "Conduit"
		elseif h(x, y, z, 33) < 0.05 then
			return "Aggregate"
		end
	elseif zone == 4 then
		-- a lattice of rebar: rods along the tunnel and across it every 5 layers
		if y % 4 == 1 and (x % 4 == 2 or zl % 5 == 0) then
			return "Rebar"
		end
	elseif zone == 5 then
		-- two big pipes through the clay (3x3 cross sections with a dark bore)
		if x == 4 and y == 3 then
			return "PipeInside"
		elseif math.abs(x - 4) <= 1 and math.abs(y - 3) <= 1 and not (x ~= 4 and y ~= 3) then
			return "Terracotta"
		elseif math.abs(x - 13) <= 1 and math.abs(y - 8) <= 1 and not (x ~= 13 and y ~= 8) then
			return if x == 13 and y == 8 then "PipeInside" else "Iron"
		elseif h(x, y, z, 35) < 0.04 then
			return "Pebble"
		end
	elseif zone == 6 then
		if x == 9 and y == 11 then
			return "RustPipe"
		elseif y == 0 and zl % 10 == 0 then
			return "Grate"
		elseif y <= 3 and noise(x, y, z, 3, 36) > 0.78 then
			return "Slime"
		end
	elseif zone == 7 then
		-- diagonal quartz veins through the basalt, the odd fossil
		if math.abs(noise(x, y, z, 6, 37) - 0.5) < 0.026 then
			return "Quartz"
		elseif h(x, y, z, 37) < 0.006 then
			return "Fossil"
		end
	elseif zone == 8 then
		-- crystal clusters (one color per cluster) in dark rock
		if noise(x, y, z, 3.5, 38) > 0.74 then
			local hue = noise(x, y, z, 10, 39)
			return if hue < 0.34 then "CrystalCyan" elseif hue < 0.67 then "CrystalPink" else "CrystalViolet"
		end
	elseif zone == 9 then
		-- thin glowing veins winding through dark rock, and the odd molten pocket
		if math.abs(noise(x, y, z, 6, 40) - 0.5) < 0.022 or noise(x, y, z, 4, 42) > 0.86 then
			return "Lava"
		elseif h(x, y, z, 40) < 0.04 then
			return "Obsidian"
		end
	elseif zone == 10 then
		-- the old escape route: pillars with gold bands, carved glyphs
		local col = zl % 7 <= 1
		if col and y == 9 then
			return "Gold"
		elseif col and (x == 2 or x == 15) then
			return "Pillar"
		elseif h(x, y, z, 41) < 0.05 then
			return "Glyph"
		end
	end
	return nil
end

return Strata
