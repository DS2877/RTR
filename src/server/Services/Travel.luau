--!strict
-- QUICK TRIP: deep tunnels are a long walk. From anywhere in your own cell or tunnel, hold still for
-- World.TravelChannel seconds and you're at the dig face (the deepest open spot of your tunnel), or
-- back in your cell. Free, with a cooldown; never while carrying a stolen find, lifting, in bed or
-- on THE BREAKOUT.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Tunnel = require(Shared.Tunnel)
local Voxel = require(Shared.Voxel)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Cells = require(script.Parent.Cells)

local Travel = {}

-- init: lifting, on THE BREAKOUT
Travel.busy = nil :: ((player: any) -> boolean)?

local B = World.BlockSize
local trips: { [any]: { at: number, from: Vector3, where: string } } = {}
local readyAt: { [any]: number } = {}

-- Where you stand at the dig face: an open block (with headroom) in the deepest layers, as low as
-- possible, facing deeper. nil = nothing dug yet.
function Travel.faceSpot(s: State.PlayerState): CFrame?
	local g = s.grid
	if not g or not s.frame then
		return nil
	end
	local depth = Voxel.depth(g)
	if depth < World.TravelMinDepth then
		return nil
	end
	local frame = s.frame :: CFrame
	for z = depth - 1, math.max(0, depth - 8), -1 do
		local best: { number }? = nil
		local bestScore = math.huge
		for y = 0, g.h - 3 do
			for x = 1, g.w - 2 do
				if
					Voxel.isDug(g, x, y, z)
					and Voxel.isDug(g, x, y + 1, z)
					and Voxel.isDug(g, x, y + 2, z)
					and (y == 0 or not Voxel.isDug(g, x, y - 1, z))
				then
					local score = y * 100 + math.abs(x - g.w / 2)
					if score < bestScore then
						best, bestScore = { x, y }, score
					end
				end
			end
		end
		if best then
			-- a little back from the face so you land facing the rock you were working on
			local zz = math.max(0, z - 1)
			if not (Voxel.isDug(g, best[1], best[2], zz) and Voxel.isDug(g, best[1], best[2] + 1, zz)) then
				zz = z
			end
			local floor = Tunnel.blockCenter(frame, best[1], best[2], zz) - Vector3.new(0, B / 2, 0)
			local stand = floor + Vector3.new(0, 3.2, 0)
			local deeper = frame:VectorToWorldSpace(Vector3.new(0, 0, -1))
			return CFrame.lookAt(stand, stand + deeper)
		end
	end
	return nil
end

local function refuse(player: any, text: string)
	Net.notice(player, text, "info")
	Net.fire(player, Remotes.Names.TravelState, "cancel", "")
end

-- Starts a trip (the channel). Returns a reason when refused.
function Travel.begin(player: any, where: any): string?
	local s = State.get(player)
	if not s or (where ~= "face" and where ~= "cell") then
		return "bad args"
	end
	local pos = State.root(player)
	if not pos or not s.cell or Tunnel.cellAt(pos) ~= s.cell then
		refuse(player, "Quick trips work inside your own cell and tunnel.")
		return "not home"
	end
	if s.carrying ~= nil or s.hidden or (Travel.busy and Travel.busy(player)) then
		refuse(player, "Not right now!")
		return "busy"
	end
	local now = os.clock()
	if now < (readyAt[player] or 0) then
		refuse(player, string.format("Catch your breath: %d s", math.ceil(readyAt[player] - now)))
		return "cooldown"
	end
	if where == "face" and not Travel.faceSpot(s) then
		refuse(player, "Dig a little deeper first!")
		return "too shallow"
	end
	trips[player] = { at = now + World.TravelChannel, from = pos, where = where }
	Net.fire(player, Remotes.Names.TravelState, "start", where, World.TravelChannel)
	return nil
end

-- Finishes due trips (moved = cancelled). Also called by the smoke test.
function Travel.tick(now: number)
	for player, t in trips do
		if now >= t.at then
			trips[player] = nil
			local s = State.get(player)
			local pos = State.root(player)
			if not s or not pos then
				continue
			end
			if
				(pos - t.from).Magnitude > 4
				or Tunnel.cellAt(pos) ~= s.cell
				or s.carrying ~= nil
				or s.hidden
			then
				Net.fire(player, Remotes.Names.TravelState, "cancel", t.where)
				continue
			end
			local target: CFrame? = if t.where == "face" then Travel.faceSpot(s) else nil
			if t.where == "cell" then
				Cells.toCell(player)
			elseif target then
				if typeof(player) == "Instance" then
					local character = player.Character
					if character then
						character:PivotTo(target)
					end
				else
					(player :: any).Position = target.Position
				end
			end
			readyAt[player] = now + World.TravelCooldown
			Net.fire(player, Remotes.Names.TravelState, "done", t.where, World.TravelCooldown)
		end
	end
end

function Travel.onLeaving(player: any)
	trips[player] = nil
	readyAt[player] = nil
end

function Travel.start()
	local limit = RateLimit.new(1, 3)
	Net.on(Remotes.Names.Travel, function(player, where)
		if limit(player) then
			Travel.begin(player, where)
		end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				task.wait(0.1)
				Travel.tick(os.clock())
			end)
			if not ok then
				warn("[Travel] loop:", err)
				task.wait(1)
			end
		end
	end)
end

return Travel
