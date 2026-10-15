--!strict
-- Solves every zone's block hp against the pacing targets below (free player, everything open)
-- and prints the values to paste into Config/Zones. Re-run after changing tools, costs or rubble.
--   lune run tools/tune          (print)
--   lune run tools/tune write    (also write the hp values into src/shared/Config/Zones.luau)
local fs = require("@lune/fs")
local process = require("@lune/process")
local Zones = require("../src/shared/Config/Zones")
local Format = require("../src/shared/Format")
local simulate = require("./simcore")

-- minutes from the start until a free player first reaches each zone (11 = the bottom / escape)
local TARGET = { 0, 4, 9, 15, 23, 33, 46, 62, 82, 104, 126 }
local LIMIT = 60 * 60 * 24

local function reachTime(zone: number): number
	local r = simulate(false, true, LIMIT)
	if zone > #Zones then
		return if r.depth >= 600 then r.finish else math.huge
	end
	return r.reached[zone] or math.huge
end

for k = 2, #Zones do
	-- hp of zone k decides when zone k + 1 is reached; search in log space
	local lo, hi = math.log(Zones[k - 1].hp * 3), math.log(1e14)
	for _ = 1, 40 do
		local mid = (lo + hi) / 2
		Zones[k].hp = math.exp(mid)
		if reachTime(k + 1) > TARGET[k + 1] * 60 then
			hi = mid
		else
			lo = mid
		end
	end
	-- two significant digits
	local hp = math.exp(lo)
	local mag = 10 ^ math.floor(math.log10(hp) - 1)
	Zones[k].hp = math.floor(hp / mag) * mag
	print(
		string.format(
			"zone %2d %-20s hp = %s (%d)",
			k,
			Zones[k].name,
			Format.number(Zones[k].hp),
			Zones[k].hp
		)
	)
end

if process.args[1] == "write" then
	local path = "src/shared/Config/Zones.luau"
	local src = fs.readFile(path)
	for k = 2, #Zones do
		local id = Zones[k].id
		src = string.gsub(
			src,
			'(id = "' .. id .. '",\n[^\n]*\n[^\n]*\n%s*hp = )%d+',
			"%1" .. string.format("%d", Zones[k].hp)
		)
	end
	fs.writeFile(path, src)
	print("written to " .. path)
end
