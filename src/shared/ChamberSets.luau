--!strict
-- The set pieces inside each zone's chamber (the room you break into at the start of a zone):
-- pure data (Lune-renderable in tools/view), built by the client (Controllers/Chambers).
-- Coordinates are chamber-local studs: x across (0 = center), y up from the floor, d = depth into
-- the room from its entrance. rot = degrees (x, y, z). Effects: light = PointLight, emit = particles.

export type Spec = {
	shape: string, -- "Block" | "Cylinder" | "Ball" | "Wedge"
	size: { number },
	pos: { number }, -- x, y, d
	rot: { number }?,
	color: { number },
	material: string,
	transparency: number?,
	light: { color: { number }, range: number, brightness: number, flicker: boolean? }?,
	emit: string?, -- "steam" | "embers" | "drips" | "sparkle" | "fire"
	collide: boolean?,
	sign: string?, -- text on the face toward the entrance
}

local ChamberSets = {}

local function S(
	shape: string,
	size: { number },
	pos: { number },
	color: { number },
	material: string,
	extra: { [string]: any }?
): Spec
	local s: Spec = { shape = shape, size = size, pos = pos, color = color, material = material }
	if extra then
		for k, v in extra do
			(s :: any)[k] = v
		end
	end
	return s
end

local RUST = { 120, 62, 40 }
local IRON = { 70, 72, 76 }
local GOLD = { 230, 180, 60 }

-- width/height/depth in studs; returns the specs for a zone's chamber
local builders: { [number]: (w: number, h: number, d: number) -> { Spec } } = {
	-- 2: OLD BOILER ROOM
	[2] = function(w, h, d)
		local out = {
			S("Block", { 12, 2, 7 }, { 0, 1, d * 0.55 }, { 120, 60, 44 }, "Brick"),
			S(
				"Cylinder",
				{ 11, 6, 6 },
				{ 0, 5, d * 0.55 },
				{ 70, 40, 30 },
				"CorrodedMetal",
				{ rot = { 0, 0, 0 } }
			),
			S("Cylinder", { 0.6, 1.6, 1.6 }, { 5.8, 5.6, d * 0.55 }, { 230, 225, 210 }, "SmoothPlastic", {}),
			S("Cylinder", { 8, 1.2, 1.2 }, { -3, h - 4, d * 0.55 }, RUST, "Metal", { rot = { 0, 0, 90 } }),
			S("Cylinder", { 8, 1.2, 1.2 }, { 3, h - 4, d * 0.55 }, RUST, "Metal", { rot = { 0, 0, 90 } }),
			S("Block", { 1, 1, 1 }, { -5, 6.5, d * 0.55 - 3.2 }, { 255, 140, 40 }, "Neon", {
				light = { color = { 255, 140, 60 }, range = 22, brightness = 2, flicker = true },
				emit = "steam",
			}),
			S(
				"Wedge",
				{ 6, 2.4, 5 },
				{ -8.5, 1.2, d * 0.3 },
				{ 25, 25, 28 },
				"Slate",
				{ rot = { 0, 90, 0 } }
			),
			S(
				"Block",
				{ 0.3, 4.5, 0.3 },
				{ -6, 2.2, d * 0.25 },
				{ 110, 80, 50 },
				"Wood",
				{ rot = { 0, 0, 20 } }
			),
			S("Block", { 1.4, 0.2, 1.2 }, { -6.8, 0.15, d * 0.25 }, IRON, "Metal", { rot = { 0, 0, 20 } }),
		}
		return out
	end,
	-- 3: FORGOTTEN BUNKER
	[3] = function(w, h, d)
		local out = {}
		for i, x in { -9, 9 } do
			table.insert(out, S("Block", { 3.4, 0.5, 7 }, { x, 1.6, d * 0.5 }, IRON, "Metal"))
			table.insert(out, S("Block", { 3.2, 0.5, 6.8 }, { x, 2, d * 0.5 }, { 110, 120, 90 }, "Fabric"))
			table.insert(out, S("Block", { 3.4, 0.5, 7 }, { x, 5.6, d * 0.5 }, IRON, "Metal"))
			table.insert(out, S("Block", { 3.2, 0.5, 6.8 }, { x, 6, d * 0.5 }, { 120, 110, 90 }, "Fabric"))
			for _, dz in { -3.3, 3.3 } do
				table.insert(
					out,
					S(
						"Block",
						{ 0.3, 6.5, 0.3 },
						{ x - 1.5 * (i == 1 and 1 or -1), 3.25, d * 0.5 + dz },
						IRON,
						"Metal"
					)
				)
			end
		end
		table.insert(out, S("Block", { 6, 0.4, 3 }, { 0, 3, d - 2 }, { 90, 80, 60 }, "WoodPlanks"))
		table.insert(out, S("Block", { 2.2, 1.6, 1.4 }, { -1.5, 4, d - 2 }, { 60, 70, 60 }, "Metal"))
		table.insert(out, S("Block", { 0.6, 0.3, 0.1 }, { -1.5, 4.3, d - 2.75 }, { 120, 255, 120 }, "Neon"))
		table.insert(
			out,
			S(
				"Block",
				{ 7, 4.5, 0.1 },
				{ 0, 8, d - 0.1 },
				{ 210, 200, 170 },
				"SmoothPlastic",
				{ sign = "ESCAPE PLAN v1" }
			)
		)
		table.insert(
			out,
			S("Block", { 0.4, 0.4, 6 }, { 0, h - 0.6, d * 0.5 }, { 230, 240, 255 }, "Neon", {
				light = { color = { 200, 220, 255 }, range = 26, brightness = 1.4, flicker = true },
			})
		)
		for k = 0, 4 do
			table.insert(
				out,
				S(
					"Block",
					{ 2.4, 1, 1.4 },
					{ -w / 2 + 3 + k * 2.3, 0.5 + (k % 2) * 0.9, 2 },
					{ 150, 135, 100 },
					"Fabric"
				)
			)
		end
		return out
	end,
	-- 4: REBAR VAULT
	[4] = function(w, h, d)
		local out = {
			S(
				"Cylinder",
				{ 1.6, 12, 12 },
				{ 0, 7, d - 0.9 },
				{ 120, 124, 130 },
				"DiamondPlate",
				{ rot = { 0, 90, 0 } }
			),
			S("Cylinder", { 2, 3, 3 }, { 0, 7, d - 2.4 }, { 90, 92, 96 }, "Metal", { rot = { 0, 90, 0 } }),
			S("Block", { 6, 0.6, 0.6 }, { 0, 7, d - 3.5 }, { 160, 160, 165 }, "Metal"),
			S("Block", { 0.6, 6, 0.6 }, { 0, 7, d - 3.5 }, { 160, 160, 165 }, "Metal"),
			S("Block", { 1.2, 1.2, 1.2 }, { 0, h - 1.2, d * 0.5 }, { 255, 40, 40 }, "Neon", {
				light = { color = { 255, 50, 40 }, range = 26, brightness = 2, flicker = true },
			}),
		}
		for k = 0, 8 do
			table.insert(
				out,
				S(
					"Block",
					{ 1.6, 0.6, 0.8 },
					{ -7 + (k % 3) * 1.8, 0.3 + (k // 3) * 0.6, d * 0.4 + (k % 2) * 0.4 },
					GOLD,
					"Foil"
				)
			)
		end
		table.insert(out, S("Block", { 4, 4.5, 3.5 }, { 8, 2.25, d * 0.45 }, { 50, 54, 60 }, "Metal"))
		table.insert(
			out,
			S(
				"Block",
				{ 0.3, 4.2, 3.2 },
				{ 5.7, 2.25, d * 0.45 - 0.6 },
				{ 60, 64, 70 },
				"Metal",
				{ rot = { 0, 50, 0 } }
			)
		)
		return out
	end,
	-- 5: PIPE JUNCTION
	[5] = function(w, h, d)
		local out = {
			S("Cylinder", { w, 4.4, 4.4 }, { 0, h - 4, d * 0.35 }, { 170, 90, 50 }, "SmoothPlastic"),
			S(
				"Cylinder",
				{ d, 3.6, 3.6 },
				{ -w / 2 + 4, 3, d * 0.5 },
				{ 96, 62, 48 },
				"CorrodedMetal",
				{ rot = { 0, 90, 0 } }
			),
			S(
				"Cylinder",
				{ h, 3, 3 },
				{ w / 2 - 4, h / 2, d * 0.7 },
				{ 90, 96, 100 },
				"Metal",
				{ rot = { 0, 0, 90 } }
			),
			S(
				"Cylinder",
				{ 0.5, 3, 3 },
				{ -w / 2 + 4, 6, d * 0.5 },
				{ 200, 40, 40 },
				"Metal",
				{ rot = { 0, 0, 90 } }
			),
			S("Block", { 1, 1, 1 }, { 0, h - 7, d * 0.35 }, { 120, 200, 255 }, "Glass", {
				emit = "drips",
				light = { color = { 255, 200, 140 }, range = 22, brightness = 1.2 },
			}),
		}
		return out
	end,
	-- 6: OLD SEWER CANAL
	[6] = function(w, h, d)
		local out = {
			S(
				"Block",
				{ 8, 0.6, d },
				{ 0, 0.3, d / 2 },
				{ 60, 120, 90 },
				"Glass",
				{ transparency = 0.2, light = { color = { 120, 255, 160 }, range = 20, brightness = 0.8 } }
			),
			S("Block", { 1, 0.8, d }, { -4.5, 0.4, d / 2 }, { 80, 84, 70 }, "Brick"),
			S("Block", { 1, 0.8, d }, { 4.5, 0.4, d / 2 }, { 80, 84, 70 }, "Brick"),
			S("Block", { 3, 1, 7 }, { 0, 1, d * 0.5 }, { 110, 80, 50 }, "WoodPlanks", { rot = { 0, 15, 0 } }),
			S("Ball", { 0.9, 0.9, 0.9 }, { 2.5, 1, d * 0.3 }, { 255, 220, 40 }, "SmoothPlastic"),
			S("Ball", { 0.5, 0.5, 0.5 }, { 2.9, 1.5, d * 0.3 }, { 255, 220, 40 }, "SmoothPlastic"),
			S("Block", { 0.25, 0.2, 0.3 }, { 3.2, 1.45, d * 0.3 }, { 255, 140, 30 }, "SmoothPlastic"),
			S("Block", { 1.2, 0.6, 0.6 }, { -7, 0.3, d * 0.7 }, { 90, 90, 95 }, "Fabric"),
			S("Block", { 1.2, 0.6, 0.6 }, { 7, 0.3, d * 0.2 }, { 90, 90, 95 }, "Fabric"),
			S(
				"Block",
				{ 5, 5, 0.4 },
				{ 0, h - 4, d - 0.2 },
				{ 50, 54, 50 },
				"DiamondPlate",
				{ emit = "drips" }
			),
		}
		return out
	end,
	-- 7: GLITTERING HOLLOW
	[7] = function(w, h, d)
		local out = {}
		for k = 0, 9 do
			local x = -w / 2 + 3 + (k * 7.3) % (w - 6)
			local z = 2 + (k * 4.1) % (d - 4)
			local len = 2 + (k % 4)
			table.insert(
				out,
				S(
					"Wedge",
					{ 1.6, len, 1.6 },
					{ x, h - len / 2, z },
					{ 60, 58, 70 },
					"Basalt",
					{ rot = { 180, k * 40, 0 } }
				)
			)
		end
		for k = 0, 5 do
			local x = -w / 2 + 4 + (k * 5.7) % (w - 8)
			table.insert(
				out,
				S(
					"Block",
					{ 0.8, 1.6, 0.8 },
					{ x, 0.8, 2 + (k * 3.3) % (d - 4) },
					if k % 2 == 0 then { 120, 200, 255 } else { 200, 255, 230 },
					"Neon",
					{ rot = { 0, k * 30, 15 } }
				)
			)
		end
		table.insert(
			out,
			S("Block", { 1, 1, 1 }, { 0, h - 2, d / 2 }, { 180, 210, 255 }, "Glass", {
				transparency = 1,
				light = { color = { 150, 190, 255 }, range = 28, brightness = 1.2 },
				emit = "sparkle",
			})
		)
		return out
	end,
	-- 8: CRYSTAL GROTTO
	[8] = function(w, h, d)
		local out = {}
		local colors = { { 190, 110, 255 }, { 110, 220, 255 }, { 255, 120, 220 } }
		for k = 0, 7 do
			local side = if k % 2 == 0 then -1 else 1
			local len = 6 + (k % 3) * 3
			table.insert(
				out,
				S(
					"Block",
					{ 1.6, len, 1.6 },
					{ side * (w / 2 - 3 - (k % 3)), len / 2 - 0.5, 2 + k * (d - 4) / 7 },
					colors[k % 3 + 1],
					"Neon",
					{
						rot = { (k % 2) * 12 - 6, k * 37, side * -25 },
						transparency = 0.15,
					}
				)
			)
		end
		table.insert(
			out,
			S("Block", { 3, 9, 3 }, { 0, 4.5, d * 0.6 }, { 200, 140, 255 }, "Neon", {
				rot = { 0, 45, 0 },
				transparency = 0.1,
				light = { color = { 190, 120, 255 }, range = 30, brightness = 2 },
				emit = "sparkle",
			})
		)
		return out
	end,
	-- 9: LAVA LAKE
	[9] = function(w, h, d)
		local out = {
			S("Block", { w - 4, 0.4, d - 4 }, { 0, 0.2, d / 2 }, { 255, 110, 30 }, "Neon", {
				light = { color = { 255, 120, 40 }, range = 34, brightness = 2.4, flicker = true },
				emit = "embers",
			}),
			S("Block", { 3.2, 0.8, d }, { 0, 1.2, d / 2 }, { 60, 50, 46 }, "Slate", { collide = true }),
		}
		for _, z in { 2, d - 2 } do
			table.insert(out, S("Block", { 0.4, 3, 0.4 }, { -1.4, 2.6, z }, { 50, 40, 36 }, "Wood"))
			table.insert(out, S("Block", { 0.4, 3, 0.4 }, { 1.4, 2.6, z }, { 50, 40, 36 }, "Wood"))
		end
		for k = 0, 5 do
			table.insert(
				out,
				S(
					"Ball",
					{ 2.4, 1.4, 2.4 },
					{ -w / 2 + 4 + k * (w - 8) / 5, 0.5, 2 + (k * 3) % (d - 4) },
					{ 40, 30, 28 },
					"Basalt"
				)
			)
		end
		return out
	end,
	-- 10: THE OLD ESCAPE
	[10] = function(w, h, d)
		local bone = { 235, 228, 205 }
		local out = {
			S("Block", { 2, h - 2, 2 }, { -5, (h - 2) / 2, d - 1 }, { 200, 170, 110 }, "Sandstone"),
			S("Block", { 2, h - 2, 2 }, { 5, (h - 2) / 2, d - 1 }, { 200, 170, 110 }, "Sandstone"),
			S(
				"Block",
				{ 12, 2, 2.2 },
				{ 0, h - 2, d - 1 },
				{ 200, 170, 110 },
				"Sandstone",
				{ sign = "HE ALMOST MADE IT" }
			),
			S("Block", { 8, h - 4, 0.6 }, { 0, (h - 4) / 2, d - 0.3 }, { 60, 50, 40 }, "WoodPlanks"),
			-- the skeleton, sitting against the wall with his spoon
			S("Ball", { 1.3, 1.3, 1.3 }, { 6, 3.6, 3 }, bone, "SmoothPlastic"),
			S("Block", { 1.4, 1.8, 0.7 }, { 6, 2.3, 3 }, bone, "SmoothPlastic", { transparency = 0.15 }),
			S("Block", { 0.35, 1.8, 0.35 }, { 5.2, 2.2, 2.4 }, bone, "SmoothPlastic", { rot = { 40, 0, 0 } }),
			S("Block", { 0.35, 0.35, 2 }, { 5.6, 0.6, 2 }, bone, "SmoothPlastic"),
			S("Block", { 0.35, 0.35, 2 }, { 6.4, 0.6, 2 }, bone, "SmoothPlastic"),
			S("Block", { 0.15, 0.15, 1.2 }, { 5.2, 1.4, 1.6 }, { 200, 200, 205 }, "Metal"),
			-- the chest of the ones who tried before
			S("Block", { 3.2, 1.8, 2 }, { -6, 0.9, d * 0.5 }, { 110, 70, 40 }, "WoodPlanks"),
			S("Block", { 3.4, 0.5, 2.2 }, { -6, 2, d * 0.5 }, GOLD, "Foil"),
		}
		for _, x in { -w / 2 + 0.6, w / 2 - 0.6 } do
			table.insert(out, S("Block", { 0.4, 1.4, 0.4 }, { x, 6, d * 0.5 }, { 80, 60, 40 }, "Wood"))
			table.insert(
				out,
				S("Block", { 0.6, 0.6, 0.6 }, { x, 7, d * 0.5 }, { 255, 160, 60 }, "Neon", {
					light = { color = { 255, 160, 70 }, range = 20, brightness = 1.6, flicker = true },
					emit = "fire",
				})
			)
		end
		return out
	end,
}

-- Specs for the chamber of `zone` (nil = no chamber / no set piece). w, h, d in studs.
function ChamberSets.specs(zone: number, w: number, h: number, d: number): { Spec }?
	local b = builders[zone]
	return if b then b(w, h, d) else nil
end

return ChamberSets
