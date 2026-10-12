--!strict
-- Player data with ProfileStore (session locking). Versioned from day one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Progression = require(ReplicatedStorage.Shared.Progression)

export type SlotItem = { Id: string, Mut: string }
-- A stolen crate at the appraiser: the item inside is already decided (shown when it opens).
export type Crate = { Id: string, Mut: string, ReadyAt: number }

export type PlayerData = {
	Version: number,
	Cash: number,
	Pending: number, -- earned on the plot, waiting on the collect pad
	Speed: number, -- treadmill points
	Treadmill: number,
	PlotLevel: number,
	Slots: { [string]: SlotItem }, -- pedestal index (as string) -> item
	Inventory: { SlotItem }, -- owned items not on a pedestal (hotbar / My Items)
	Crates: { Crate }, -- crates being appraised at your base
	Found: { [string]: boolean }, -- index (item ids ever owned)
	LastOnline: number,
	StarterGiven: boolean,
	TutorialDone: boolean,
	Receipts: { string },
	GiftedPasses: { [string]: boolean }, -- passes a friend gifted (work like owning the pass)
	Candy: number, -- seasonal event currency
	Trails: { [string]: boolean }, -- owned trails
	Trail: string, -- equipped trail id ("" = none)
	Stats: {
		Steals: number, -- from vaults
		PlayerSteals: number, -- from other players
		Caught: number,
		RobbedRichest: number,
		ReignSeconds: number,
		BestReign: number,
		Earned: number,
		Collected: number,
	},
}

local TEMPLATE: PlayerData = {
	Version = Economy.ProfileVersion,
	Cash = Economy.StartingCash,
	Pending = 0,
	Speed = 0,
	Treadmill = 1,
	PlotLevel = 1,
	Slots = {},
	Inventory = {},
	Crates = {},
	Found = {},
	LastOnline = 0,
	StarterGiven = false,
	TutorialDone = false,
	Receipts = {},
	GiftedPasses = {},
	Candy = 0,
	Trails = {},
	Trail = "",
	Stats = {
		Steals = 0,
		PlayerSteals = 0,
		Caught = 0,
		RobbedRichest = 0,
		ReignSeconds = 0,
		BestReign = 0,
		Earned = 0,
		Collected = 0,
	},
}

local MIGRATIONS: { [number]: (data: PlayerData) -> () } = {}

local Data = {}

-- Items from before the zones were rearranged to match the genre (12 Oct) -> today's items.
local RENAMED: { [string]: string } = {
	Sneakers = "PearlEarrings",
	SelfieStick = "EmeraldNecklace",
	DiamondTub = "VaultSafe",
	MoneyGun = "GoldenGun",
	InfinityGem = "MidasHand",
	GoldLambo = "GoldToilet",
	VaultKey = "BossRing",
	CaptainHat = "Fedora",
	Champagne = "RumBarrel",
	JetSki = "TreasureMap",
	Anchor = "Cutlass",
	YachtWheel = "Compass",
	IslandDeed = "KrakenEgg",
	GamingPC = "Vase",
	RobotDog = "Statue",
	AIBrain = "Sword",
	QuantumChip = "CrystalSkull",
	RocketEngine = "Painting",
	MarsTicket = "Meteorite",
	GoldDuck = "GoldenGoose",
}

-- Every saved item id must exist (an unknown id would break plot rendering).
local function fixItem(item: { Id: string })
	if not Progression.item(item.Id) then
		item.Id = RENAMED[item.Id] or Economy.StarterItem
	end
end

function Data.sanitize(data: PlayerData)
	for _, item in data.Slots do
		fixItem(item)
	end
	for _, item in data.Inventory do
		fixItem(item)
	end
	for _, crate in data.Crates do
		fixItem(crate)
	end
	for id in table.clone(data.Found) do
		if not Progression.item(id) then
			data.Found[id] = nil
			local now = RENAMED[id]
			if now then
				data.Found[now] = true
			end
		end
	end
end

local store = ProfileStore.New(Economy.DataStoreName, TEMPLATE)
local profiles: { [Player]: any } = {}

local function migrate(data: PlayerData)
	local version = data.Version or 0
	while version < Economy.ProfileVersion do
		local step = MIGRATIONS[version]
		if step then
			step(data)
		end
		version += 1
	end
	data.Version = version
	for key, value in TEMPLATE.Stats :: any do
		if (data.Stats :: any)[key] == nil then
			(data.Stats :: any)[key] = value
		end
	end
end

-- Yields. Returns the data, or nil if the player left or the profile could not be loaded.
function Data.load(player: Player): PlayerData?
	local profile = store:StartSessionAsync(
		"Player_" .. player.UserId,
		{
			Cancel = function()
				return player.Parent ~= Players
			end,
		} :: any
	)
	if profile == nil then
		if player.Parent == Players then
			player:Kick("Could not load your data. Please rejoin in a moment.")
		end
		return nil
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	migrate(profile.Data)
	Data.sanitize(profile.Data)
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Your data was opened on another server. Please rejoin.")
		end
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return nil
	end
	profiles[player] = profile
	return profile.Data
end

function Data.get(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

local function deep(t: any): any
	if typeof(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t do
		out[k] = deep(v)
	end
	return out
end

-- A brand-new player's data (also used by the smoke test's simulated players).
function Data.fresh(): PlayerData
	return deep(TEMPLATE)
end

-- Admin: wipe back to a brand-new player (receipts + gifts kept so purchases never vanish).
function Data.reset(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local receipts = profile.Data.Receipts
	local gifts = profile.Data.GiftedPasses
	local fresh = deep(TEMPLATE)
	fresh.Receipts = receipts
	fresh.GiftedPasses = gifts
	profile.Data = fresh
	return true
end

function Data.saveAndWait(player: Player, timeout: number?): boolean
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false
	end
	local done = false
	local conn = profile.OnAfterSave:Connect(function()
		done = true
	end)
	profile:Save()
	local waited = 0
	local limit = timeout or 15
	while not done and waited < limit and profile:IsActive() do
		waited += task.wait(0.1)
	end
	conn:Disconnect()
	return done
end

function Data.release(player: Player)
	local profile = profiles[player]
	if profile then
		profiles[player] = nil
		profile:EndSession()
	end
end

return Data
