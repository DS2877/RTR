--!strict
-- Runtime (not saved) state per player, shared by every service.
-- The smoke test uses plain tables as "players" ({ UserId, Name, Position }); root() handles both.

local Data = require(script.Parent.Services.Data)

export type Pile = { id: number, pos: Vector3, rubble: number, value: number }

export type PlayerState = {
	player: Player,
	data: Data.PlayerData,
	cell: number?,
	frame: CFrame?, -- tunnel frame of your cell
	grid: any, -- Voxel.Grid of your tunnel
	damage: { [number]: number }, -- block index -> hp left (not saved)
	tunnelDirty: boolean,
	lastPunch: number,
	vacuuming: boolean,
	piles: { Pile },
	pileSeq: number,
	loose: number, -- rubble lying around in piles
	watching: { [number]: boolean }, -- owners (UserId) whose tunnels this client renders
	ready: boolean,
	passes: { [string]: boolean },
	lastLift: number,
}

local State = {}

local states: { [any]: PlayerState } = {}

function State.add(player: Player, data: Data.PlayerData): PlayerState
	local s: PlayerState = {
		player = player,
		data = data,
		cell = nil,
		frame = nil,
		grid = nil,
		damage = {},
		tunnelDirty = false,
		lastPunch = 0,
		vacuuming = false,
		piles = {},
		pileSeq = 0,
		loose = 0,
		watching = {},
		ready = false,
		passes = {},
		lastLift = 0,
	}
	states[player] = s
	return s
end

function State.get(player: Player): PlayerState?
	return states[player]
end

function State.remove(player: Player)
	states[player] = nil
end

function State.all(): { [any]: PlayerState }
	return states
end

-- World position of the player's HumanoidRootPart (or a test player's Position).
function State.root(player: any): Vector3?
	if typeof(player) ~= "Instance" then
		return player.Position
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

return State
