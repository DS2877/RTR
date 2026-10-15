--!strict
-- All RemoteEvents in one place. The server creates them, clients wait for them.
-- Client -> server remotes carry intents only, never values.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.Names = {
	-- client -> server
	Ready = "Ready", -- () the client can receive tunnel snapshots
	Punch = "Punch", -- (x, y, z, face) punch the aimed block of your own tunnel
	Vacuum = "Vacuum", -- (on: boolean) holding the VACUUM button
	Lift = "Lift", -- () one rep at the gym station you stand next to
	Buy = "Buy", -- (track: string) buy the next level of an upgrade track
	Sell = "Sell", -- (slot: number) sell one find, 0 = sell all
	AdminCmd = "AdminCmd", -- (cmd: string, arg: number?) admins only
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
	Lifted = "Lifted", -- (gain: number) a gym rep counted
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
