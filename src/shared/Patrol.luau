--!strict
-- Where a patrolling guard is at a given server time: walk the route loop at Config/Patrol.Speed,
-- pausing at every corner. Pure (Lune-tested); the server (lines) and every client (rendering)
-- compute the same answer from workspace:GetServerTimeNow().

local function config(name: string): any
	if script then
		return (require :: any)((script :: any).Parent.Config[name])
	end
	return (require :: any)("./Config/" .. name)
end

local Config = config("Patrol")

local PatrolMath = {}

export type Pose = { x: number, z: number, heading: number, walking: boolean }

-- Route name of guard `i` in schedule phase `phase`.
function PatrolMath.routeOf(i: number, phase: string): string
	local g = Config.Guards[i]
	return g and (g.routes[phase] or g.routes.Day) or "Corridor"
end

-- Pose on a route at time t (seconds). `offset` spreads guards that share a route.
function PatrolMath.pose(routeName: string, t: number, offset: number?): Pose
	local pts = Config.Routes[routeName] or Config.Routes.Corridor
	local n = #pts
	local legs = {}
	local total = 0
	for i = 1, n do
		local a, b = pts[i], pts[i % n + 1]
		local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		local walk = len / Config.Speed
		table.insert(legs, { a = a, b = b, walk = walk })
		total += walk + Config.Pause
	end
	local tau = (t + (offset or 0)) % total
	for _, leg in legs do
		local a, b = leg.a, leg.b
		local heading = math.atan2(b[1] - a[1], b[2] - a[2])
		if tau < Config.Pause then
			return { x = a[1], z = a[2], heading = heading, walking = false }
		end
		tau -= Config.Pause
		if tau < leg.walk then
			local k = tau / leg.walk
			return {
				x = a[1] + (b[1] - a[1]) * k,
				z = a[2] + (b[2] - a[2]) * k,
				heading = heading,
				walking = true,
			}
		end
		tau -= leg.walk
	end
	local p = pts[1]
	return { x = p[1], z = p[2], heading = 0, walking = false }
end

-- Pose of guard `i` right now in `phase`.
function PatrolMath.guard(i: number, phase: string, t: number): Pose
	return PatrolMath.pose(PatrolMath.routeOf(i, phase), t, i * 13.7)
end

return PatrolMath
