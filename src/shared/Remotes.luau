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
	GiftTarget = "GiftTarget", -- (userId: number) who the next gift purchase is for
	BuyTrail = "BuyTrail", -- (trailId: string)
	EquipTrail = "EquipTrail", -- (trailId: string) "" = take it off
	Appraise = "Appraise", -- (index: number) open a ready crate; 0 = all ready crates
	Equip = "Equip", -- (bagIndex: number) put an item from your bag on a free pedestal
	Unequip = "Unequip", -- (slot: string) take an item off its pedestal into your bag
	EquipBest = "EquipBest", -- () best earners on the pedestals
	SellItem = "SellItem", -- (kind: "bag" | "slot", key: number | string)
	-- server -> client
	Notice = "Notice", -- (text: string, kind: string) small toast for one player
	Announce = "Announce", -- (text: string, color: {number}, sound: string?) server-wide message
	SpeedTick = "SpeedTick", -- (gained: number) treadmill popup
	Caught = "Caught", -- (by: string, tooSlow: boolean)
	Deposited = "Deposited", -- (itemName, rarity, mutation, income: number, title: string?) loot landed
	Sync = "Sync", -- ({ Found, Items, Passes }) index + plot contents for panels
	OpenFuse = "OpenFuse", -- ()
	Crown = "Crown", -- (gained: boolean) you became / stopped being the richest
	Alarm = "Alarm", -- (vaultName: string) a guard spotted you
	CashFX = "CashFX", -- (amount: number, from: Vector3?) coins fly into the cash counter
	Offer = "Offer", -- (kind: string) contextual shop offer ("speed" | "cash")
	Pickup = "Pickup", -- (cash: number, candy: number, at: Vector3) you grabbed a street pickup
	OpenTrails = "OpenTrails", -- () the trails shop prompt was used
	Offline = "Offline", -- (earned: number, seconds: number, perDay: number)
	OpenItems = "OpenItems", -- (mode: "items" | "sell") the SELL stall was used
	Revealed = "Revealed", -- (itemName, rarity, mutation, income, where: "base" | "bag") a crate opened
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
