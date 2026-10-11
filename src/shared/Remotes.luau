--!strict
-- All RemoteEvents in one place. The server creates them, clients wait for them.
-- Client -> server remotes carry intents only, never values.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.Names = {
	-- client -> server
	Drop = "Drop", -- () drop what you carry (it goes back where it came from)
	Slap = "Slap", -- (userId: number) make a nearby carrier drop their loot
	SetSlowMode = "SetSlowMode", -- (on: boolean)
	Lock = "Lock", -- () lock your base
	Fuse = "Fuse", -- (itemId: string, mutation: string)
	RequestSync = "RequestSync", -- ()
	-- server -> client
	Notice = "Notice", -- (text: string, kind: string) small toast for one player
	Announce = "Announce", -- (text: string, color: {number}) big server-wide message
	SpeedTick = "SpeedTick", -- (gained: number) treadmill popup
	Caught = "Caught", -- (by: string)
	Deposited = "Deposited", -- (itemName, rarity, mutation, income: number, title: string?) loot landed
	Sync = "Sync", -- ({ Found, Items, Passes }) index + plot contents for panels
	OpenFuse = "OpenFuse", -- ()
	Offline = "Offline", -- (earned: number, seconds: number)
	Crown = "Crown", -- (gained: boolean) you became / stopped being the richest
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
