--!strict
-- THE BREAKOUT course in plain numbers (no Roblox APIs) so the server (Services/Breakout), the
-- client (Controllers/Breakout) and Lune agree on every rule: where each section is, where the
-- searchlights are at any server time, which spots count as checkpoints, what a run earns.
--
-- Local coordinates relative to Config/Breakout.Origin: +X is the way out, Y up, Z across.
--   SEWER    x 0..96     walkway top y = 0, water below (fall in = back to the start)
--   SHAFT    x 90..96    a ladder up through a manhole to the yard (y 0 -> 16)
--   YARD     x 96..216   ground y = 16, three sweeping searchlights, guards on your heels
--   WALL     x 216..220  24 studs high (a ladder on the yard side), a tower light on the top
--   OUTSIDE  x 220..300  ground y = 16, the road and the getaway car (the finish)

local function config(name: string): any
	if script then
		return (require :: any)((script :: any).Parent.Config[name])
	end
	return (require :: any)("./Config/" .. name)
end
local Config = config("Breakout")

local Breakout = {}

export type Box = { x0: number, y0: number, z0: number, x1: number, y1: number, z1: number }
export type Spawn = { x: number, y: number, z: number }

Breakout.YardY = 16
Breakout.WallTopY = 40
Breakout.HalfWidth = 36 -- yard / outside: z -36..36

-- sewer walkways (x ranges); the gaps between them are water
Breakout.Walkways = { { 0, 22 }, { 28, 46 }, { 52, 70 }, { 76, 96 } }

-- 1 = sewer start, 2 = out of the manhole, 3 = on top of the wall
Breakout.Spawns = {
	{ x = 4, y = 3, z = 0 },
	{ x = 101, y = Breakout.YardY + 3, z = 0 },
	{ x = 218, y = Breakout.WallTopY + 3, z = 0 },
} :: { Spawn }

-- reaching a box moves your checkpoint up to that number
Breakout.Checkpoints = {
	[2] = { x0 = 96, y0 = 15, z0 = -8, x1 = 108, y1 = 30, z1 = 8 },
	[3] = { x0 = 215, y0 = 38.5, z0 = -36, x1 = 221, y1 = 50, z1 = 36 },
} :: { [number]: Box }

-- the getaway car's door
Breakout.Finish = { x0 = 272, y0 = 14, z0 = -7, x1 = 290, y1 = 26, z1 = 7 } :: Box
Breakout.Car = { x = 281, z = 0 }

Breakout.Objectives = {
	"Get through the sewer. Don't fall in!",
	"Cross the yard: stay out of the searchlights!",
	"Over the wall and into the car!",
}

local function inBox(b: Box, x: number, y: number, z: number): boolean
	return x >= b.x0 and x <= b.x1 and y >= b.y0 and y <= b.y1 and z >= b.z0 and z <= b.z1
end
Breakout.inBox = inBox

-- ===== searchlights =====

-- Each yard light sweeps a figure across the yard (centers stay inside x 116..196, z -28..28).
local LIGHTS = {
	{ cx = 132, ax = 14, wx = 0.31, px = 0.0, az = 26, wz = 0.47, pz = 1.1 },
	{ cx = 158, ax = 16, wx = 0.27, px = 2.3, az = 27, wz = 0.39, pz = 3.9 },
	{ cx = 184, ax = 12, wx = 0.36, px = 4.1, az = 25, wz = 0.53, pz = 0.4 },
}
Breakout.LightCount = #LIGHTS

-- Where yard light i hits the ground at server time t: (x, z) local.
function Breakout.light(i: number, t: number): (number, number)
	local l = LIGHTS[i]
	return l.cx + l.ax * math.sin(t * l.wx + l.px), l.az * math.sin(t * l.wz + l.pz)
end

-- The wall-top tower light: z along the wall at server time t.
function Breakout.towerLight(t: number): number
	return 30 * math.sin(t * 0.55)
end

-- Is someone standing at local (x, y, z) caught in a light at server time t?
function Breakout.spotted(x: number, y: number, z: number, t: number): boolean
	if x > 108 and x < 214 and y > Breakout.YardY - 1 and y < Breakout.YardY + 12 then
		for i = 1, #LIGHTS do
			local lx, lz = Breakout.light(i, t)
			local dx, dz = x - lx, z - lz
			if dx * dx + dz * dz <= Config.LightRadius * Config.LightRadius then
				return true
			end
		end
	end
	if x > 214 and x < 222 and y > Breakout.WallTopY - 1.5 then
		local dz = z - Breakout.towerLight(t)
		if math.abs(dz) <= Config.TowerLightRadius then
			return true
		end
	end
	return false
end

-- ===== rules =====

-- A new checkpoint reached at local (x, y, z), given the current one (nil = none new).
function Breakout.checkpointAt(current: number, x: number, y: number, z: number): number?
	local nextBox = Breakout.Checkpoints[current + 1]
	if nextBox and inBox(nextBox, x, y, z) then
		return current + 1
	end
	return nil
end

function Breakout.atFinish(x: number, y: number, z: number): boolean
	return inBox(Breakout.Finish, x, y, z)
end

-- Fell somewhere you can't come back from: the sewer water, or off the course.
function Breakout.fell(x: number, y: number, _z: number): boolean
	if x < 96 then
		return y < -1.5
	end
	return y < Breakout.YardY - 4
end

-- The medal for a run: (medal table) - the first whose time and spotted limits you beat.
function Breakout.medal(seconds: number, spotted: number): any
	for _, m in Config.Medals do
		if seconds <= m.time and spotted <= m.spotted then
			return m
		end
	end
	return Config.Medals[#Config.Medals]
end

return Breakout
