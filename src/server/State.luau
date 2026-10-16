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
	-- PvP (M3)
	stamina: number,
	lastHitAt: number, -- when you were last punched
	lastBrawl: number, -- when you last punched a player
	protectedUntil: number,
	carrying: { id: string, owner: Player }?, -- a stolen find on its way home
	-- M4
	groupBonus: boolean,
	escapeReady: boolean,
	buffs: { [string]: number }, -- buff id -> os.time() it ends
	hidden: boolean, -- lying in bed (Services/Hideout)
	coverDown: boolean, -- the tapestry is rolled down over the tunnel hole
	bribed: boolean, -- paid off tonight's inspection
	fullNoticeAt: number, -- os.clock() of the last "backpack full" notice (at most every 20 s)
	snitched: boolean, -- guaranteed inspection next night
	-- COMBO chain (Services/Dig): punches in a row, the last one (os.clock), the bonus value earned
	comboHits: number,
	comboLast: number,
	comboBonus: number,
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
		stamina = 100,
		lastHitAt = 0,
		lastBrawl = 0,
		protectedUntil = 0,
		carrying = nil,
		groupBonus = false,
		escapeReady = false,
		buffs = {},
		hidden = false,
		coverDown = false,
		bribed = false,
		fullNoticeAt = -math.huge,
		snitched = false,
		comboHits = 0,
		comboLast = -math.huge,
		comboBonus = 0,
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
