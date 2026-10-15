--!strict
-- Economy simulation: time to reach each zone for a free player and for a player with every pass.
--   lune run tools/simulate          (zones open right now)
--   lune run tools/simulate all      (pretend every zone and upgrade is open: long-term pacing)
-- The model lives in tools/simcore.luau; tools/tune.luau solves zone hp against pacing targets.
local process = require("@lune/process")
local Zones = require("../src/shared/Config/Zones")
local Format = require("../src/shared/Format")
local simulate = require("./simcore")

local ALL = process.args[1] == "all"
local LIMIT = if ALL then 60 * 60 * 24 * 30 else 60 * 60 * 6

local function run(passes: boolean)
	local r = simulate(passes, ALL, LIMIT)
	local reached, info, buys = r.reached, r.info, r.buys
	local firstBuy, t, depth, strength, noodles = r.firstBuy, r.finish, r.depth, r.strength, r.noodles
	print(
		if passes
			then "\n== WITH PASSES (2x Noodles, 2x Strength, Huge Backpack, Auto-Vacuum) =="
			else "\n== FREE PLAYER =="
	)
	print(string.format("first upgrade after %s", if firstBuy then Format.duration(firstBuy) else "never"))
	for z = 1, #Zones do
		if reached[z] then
			local h = r.hits[z]
			local nextAt = reached[z + 1] or t
			print(
				string.format(
					"  zone %2d %-20s at %-8s takes %-8s avg %4.1f hits, farmed %5d  %s",
					z,
					Zones[z].name,
					Format.duration(reached[z]),
					Format.duration(nextAt - reached[z]),
					if h then h.sum / h.n else 0,
					r.farmed[z] or 0,
					info[z] or ""
				)
			)
		end
	end
	print(
		string.format(
			"  depth %d after %s, strength %s, noodles left %s",
			depth,
			Format.duration(t),
			Format.number(strength),
			Format.number(noodles)
		)
	)
	print("  purchases:")
	for i, line in buys do
		if i <= 40 then
			print("   " .. line)
		end
	end

	return reached, firstBuy, r
end

local free, firstFree, freeRun = run(false)
run(true)

-- balance targets (warn only)
local function target(name: string, actual: number?, maxSeconds: number)
	local ok = actual ~= nil and actual <= maxSeconds
	print(
		string.format(
			"%s %-28s %s (target <= %s)",
			if ok then "OK  " else "MISS",
			name,
			if actual then Format.duration(actual) else "never",
			Format.duration(maxSeconds)
		)
	)
end
print("\n== TARGETS (free player) ==")
target("first upgrade", firstFree, 60)
target("zone 2", free[2], 6 * 60)
target("zone 3", free[3], 17 * 60)
if ALL then
	target("escape (bottom)", if freeRun.depth >= 600 then freeRun.finish else nil, 150 * 60)
	for z, h in freeRun.hits do
		local avg = h.sum / h.n
		print(
			string.format(
				"%s zone %-2d average hits/block   %.1f (target <= 15)",
				if avg <= 15 then "OK  " else "MISS",
				z,
				avg
			)
		)
	end
end
