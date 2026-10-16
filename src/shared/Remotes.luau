--!strict
-- All RemoteEvents in one place. The server creates them, clients wait for them.
-- Client -> server remotes carry intents only, never values.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.Names = {
	-- client -> server
	Ready = "Ready", -- () the client can receive tunnel snapshots
	Punch = "Punch", -- (x, y, z, face, ownerId?) punch a block of your tunnel (or your CREW host's)
	CrewInvite = "CrewInvite", -- (userId: number) invite a player to dig in your tunnel
	CrewAnswer = "CrewAnswer", -- (hostId: number, accept: boolean) answer an invite
	PetBuy = "PetBuy", -- (id: string) buy a cellmate (known price)
	PetEquip = "PetEquip", -- (id: string, on: boolean) take a cellmate out / back to the cell
	CrewLeave = "CrewLeave", -- (kickUserId: number?) leave your crew (host: nil = disband, id = kick)
	Vacuum = "Vacuum", -- (on: boolean) holding the VACUUM button
	Lift = "Lift", -- () one rep while you hold a gym station's thing over your head
	GymStop = "GymStop", -- () put it down
	Buy = "Buy", -- (track: string) buy the next level of an upgrade track
	Sell = "Sell", -- (slot: number) sell one find, 0 = sell all
	AdminCmd = "AdminCmd", -- (cmd: string, arg: number?) admins only
	Brawl = "Brawl", -- (userId: number) punch a player (day, outside safe zones)
	StashCmd = "StashCmd", -- (cmd: "put" | "take") at your own Stash chest
	RobuxBuy = "RobuxBuy", -- (key: string) prompt a pass / developer product purchase
	Dynamite = "Dynamite", -- (x, y, z) light a stick at an exposed block of your tunnel
	Escape = "Escape", -- () escape (rebirth) once you reached the bottom
	Hide = "Hide", -- () hide from the guard's inspection (into bed + cover the hole)
	Cover = "Cover", -- (down: boolean?) roll your cell's tapestry down / up (nil = toggle)
	Sleep = "Sleep", -- (on: boolean?) lie down in your bed / get up (nil = toggle)
	TourDone = "TourDone", -- () finished or skipped the first-join tour
	ClaimMission = "ClaimMission", -- (index: number) claim a finished WORK DETAIL job (4 = bonus)
	Bribe = "Bribe", -- () bribe the guard (snitched players)
	Snitch = "Snitch", -- (userId: number) pay to tip off the guard
	BuyItem = "BuyItem", -- (shop: string, id: string) Laundry / Black Market / Mess Hall / Decor
	Equip = "Equip", -- (kind: "uniform", id: string)
	PlaceDecor = "PlaceDecor", -- (kind: string) place a decor item where you stand
	ClearDecor = "ClearDecor", -- () pick up every placed decor item
	-- server -> client
	Notice = "Notice", -- (text, kind) small toast
	Announce = "Announce", -- (text, color: {number}, sound: string?) server-wide message
	Snapshot = "Snapshot", -- (owner: number, cell: number, seed: number, data: string, damage: {number})
	Delta = "Delta", -- (owner: number, broken: {number}, damage: {number}, puncher: number)
	Drop = "Drop", -- (owner: number) stop rendering that tunnel
	Chamber = "Chamber", -- (owner: number, zone: number) a chamber was broken into
	Zone = "Zone", -- (zone: number) you reached a new zone (banner + confetti)
	Found = "Found", -- (findId: string) you dug up a find
	Finds = "Finds", -- ({ string }) your find slots
	Piles = "Piles", -- ({ {id, x, y, z, n} }) your loose rubble
	Full = "Full", -- (kind: "bag" | "loose" | "slots") why your punch did nothing
	OpenShop = "OpenShop", -- (shop: string) a counter prompt was used
	Dumped = "Dumped", -- (noodles: number) rubble dumped in the Yard
	Lifted = "Lifted", -- (gain: number, quality: "perfect" | "good" | "miss", combo: number)
	LiftStart = "LiftStart", -- (station: number, start: number) the meter starts (server time)
	LiftStop = "LiftStop", -- () you put it down
	Knocked = "Knocked", -- (impulse: Vector3, stamina: number, out: boolean) you got punched
	Hit = "Hit", -- (victim: number, out: boolean) your punch landed on a player
	Drops = "Drops", -- ({ {id, x, y, z, rubble, finds} }) loot on the floor (everyone)
	Slip = "Slip", -- (seconds: number) you stepped on soap
	Stash = "Stash", -- ({ string }) your Stash chest contents
	OpenStash = "OpenStash", -- () your Stash prompt was used
	Raid = "Raid", -- (kind: "alarm" | "stolen" | "carry" | "home" | "dropped", text, userId?)
	Boom = "Boom", -- (owner: number, x, y, z) dynamite went off
	Crit = "Crit", -- (x, y, z, owner) your punch was a CRIT (owner = whose tunnel)
	PetAct = "PetAct", -- (ownerUserId, petId, x, y, z, tunnelOwner) a pet swung at a block
	PetLevel = "PetLevel", -- (petId, level) your pet leveled up
	CrewInvited = "CrewInvited", -- (hostId: number, hostName: string, friend: boolean) an invite
	Combo = "Combo", -- (hits: number, tier: number, bonus: number) your combo chain after a punch
	Gold = "Gold", -- (owner, x, y, z, kind: "gold" | "jackpot", paid: number, puncher) gold broke
	-- THE BREAKOUT: ("start", serverTime, practice) | ("reset", reason, checkpoint, spotted)
	-- | ("checkpoint", n) | ("finish", seconds, medal, cash, rebirths, prison, spotted, practice)
	Breakout = "Breakout",
	CaveIn = "CaveIn", -- (owner, x, y, z, blocks: number, puncher) the rock came down
	MissionDone = "MissionDone", -- (index) a WORK DETAIL job just got finished
	EscapeReady = "EscapeReady", -- () you reached the bottom: the ESCAPE button appears
	Escaped = "Escaped", -- (rebirths: number, tierName: string) play the escape cinematic
	Inspect = "Inspect", -- (phase: "warn" | "caught" | "safe", seconds: number, snitched: boolean)
	Event = "Event", -- (id: string, seconds: number) a server event started ("" = ended)
	Treasure = "Treasure", -- (x, y, z | nil) where the treasure is in your tunnel
	Reward = "Reward", -- (kind: string, text: string) daily / playtime / cellmate rewards
}

local FOLDER_NAME = "Remotes"

local function folder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing :: Folder
		end
		local f = Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = ReplicatedStorage
		return f
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Remotes.setup()
	assert(RunService:IsServer(), "Remotes.setup is server-only")
	local f = folder()
	for _, name: string in Remotes.Names :: { [string]: string } do
		if not f:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = f
		end
	end
end

function Remotes.get(name: string): RemoteEvent
	local f = folder()
	if RunService:IsServer() then
		local r = f:FindFirstChild(name)
		assert(r and r:IsA("RemoteEvent"), "Unknown remote " .. name)
		return r
	end
	return f:WaitForChild(name) :: RemoteEvent
end

return Remotes
