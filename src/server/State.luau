--!strict
-- Runtime (not saved) state per player, shared by every service.

local Data = require(script.Parent.Services.Data)

export type Carry = {
	id: string,
	mut: string,
	model: Model?,
	source: string, -- "vault" | "player"
	victim: Player?, -- when stolen from another player
	victimSlot: string?,
	restore: () -> (), -- puts the item back where it came from
	startedAt: number,
}

export type PlayerState = {
	player: Player,
	data: Data.PlayerData,
	base: any?, -- WorldBuilder.BaseRecord
	carry: Carry?,
	slowMode: boolean,
	stunUntil: number,
	lastSlap: number,
	passes: { [string]: boolean },
	isRichest: boolean,
	reignStart: number,
	friendBoost: number, -- 0.2 = +20% cash (Friend Boost)
}

local State = {}

local states: { [Player]: PlayerState } = {}

function State.add(player: Player, data: Data.PlayerData): PlayerState
	local s: PlayerState = {
		player = player,
		data = data,
		base = nil,
		carry = nil,
		slowMode = false,
		stunUntil = 0,
		lastSlap = 0,
		passes = {},
		isRichest = false,
		reignStart = 0,
		friendBoost = 0,
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

function State.all(): { [Player]: PlayerState }
	return states
end

function State.root(player: Player): BasePart?
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

function State.humanoid(player: Player): Humanoid?
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return if h and h.Health > 0 then h else nil
end

return State
