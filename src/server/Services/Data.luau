--!strict
-- Player data with ProfileStore (session locking). Store "DigOut_v1": nothing from Rob the Rich.
-- `Version` + MIGRATIONS: when the shape changes, bump Economy.ProfileVersion and add a step that
-- turns version N data into version N+1.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Finds = require(ReplicatedStorage.Shared.Config.Finds)

export type PlayerData = {
	Version: number,
	Noodles: number,
	Strength: number,
	Levels: {
		Tools: number,
		Brushes: number,
		Backpack: number,
		FindSlots: number,
		Vacuum: number,
		Lock: number,
		Trap: number,
		Alarm: number,
	},
	Rebirths: number,
	Seed: number, -- decides where the finds are in your tunnel
	Tunnel: string, -- Voxel.serialize of your tunnel
	MaxDepth: number, -- deepest layer reached (record, kept on rebirth)
	Zone: number, -- deepest zone reached in this tunnel
	Bag: number, -- rubble in the backpack
	BagValue: number, -- Noodles that rubble pays at the dump
	Finds: { string }, -- find slots (find ids), carried: a knockout drops one
	Stash: { string }, -- finds in the Stash chest in your cell: raiders can steal one by day
	Found: { [string]: boolean }, -- every find ever dug up (collection)
	Receipts: { string },
	Dynamite: number, -- sticks owned
	Daily: { Day: number, Streak: number }, -- daily reward streak (Day = days since 1970)
	PlayMinutes: number, -- playtime gifts
	Escapes: { number }, -- os.time() of every escape (rebirth)
	Uniforms: { [string]: boolean }, -- Laundry
	Uniform: string,
	Fist: string, -- equipped fist trail ("" = none)
	Decor: { [string]: number }, -- decor items owned (kind -> count)
	Placed: { { number } }, -- placed decor { kindIndex, x, y, z }
	TutorialStep: number, -- 1..5 = current step, 6 = done
	LastOnline: number,
	Stats: {
		Punches: number,
		Blocks: number,
		FindsDug: number,
		Earned: number,
		Lifts: number,
		Steals: number,
		Robbed: number,
		Knockouts: number,
	},
}

local function newSeed(): number
	return Random.new():NextInteger(1, 2 ^ 31 - 1)
end

local TEMPLATE: PlayerData = {
	Version = Economy.ProfileVersion,
	Noodles = Economy.StartingNoodles,
	Strength = Economy.StartingStrength,
	Levels = {
		Tools = 1,
		Brushes = 1,
		Backpack = 1,
		FindSlots = 1,
		Vacuum = 1,
		Lock = 1,
		Trap = 1,
		Alarm = 1,
	},
	Rebirths = 0,
	Seed = 0, -- set on first load
	Tunnel = "",
	MaxDepth = 0,
	Zone = 1,
	Bag = 0,
	BagValue = 0,
	Finds = {},
	Stash = {},
	Found = {},
	Receipts = {},
	Dynamite = 0,
	Daily = { Day = 0, Streak = 0 },
	PlayMinutes = 0,
	Escapes = {},
	Uniforms = {},
	Uniform = "",
	Fist = "",
	Decor = {},
	Placed = {},
	TutorialStep = 1,
	LastOnline = 0,
	Stats = {
		Punches = 0,
		Blocks = 0,
		FindsDug = 0,
		Earned = 0,
		Lifts = 0,
		Steals = 0,
		Robbed = 0,
		Knockouts = 0,
	},
}

-- MIGRATIONS[n] upgrades version-n data to version n + 1.
local MIGRATIONS: { [number]: (data: PlayerData) -> () } = {}

local Data = {}

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

-- Fills missing nested keys, fixes impossible values. Also used on admin resets.
function Data.sanitize(data: PlayerData)
	for _, group in { "Levels", "Stats", "Daily" } do
		local have = (data :: any)[group]
		if typeof(have) ~= "table" then
			have = {};
			(data :: any)[group] = have
		end
		for k, v in (TEMPLATE :: any)[group] do
			if typeof(have[k]) ~= "number" then
				have[k] = v
			end
		end
	end
	if data.Seed == 0 then
		data.Seed = newSeed()
	end
	for _, key in { "Finds", "Stash" } do
		local kept = {}
		for _, id in (data :: any)[key] or {} do
			if Finds.ById[id] then
				table.insert(kept, id)
			end
		end
		(data :: any)[key] = kept
	end
	data.Noodles = math.max(0, data.Noodles)
end

function Data.migrate(data: PlayerData)
	local version = data.Version or 0
	while version < Economy.ProfileVersion do
		local step = MIGRATIONS[version]
		if step then
			step(data)
		end
		version += 1
	end
	data.Version = version
end

local store = ProfileStore.New(Economy.DataStoreName, TEMPLATE)
local profiles: { [Player]: any } = {}

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
	Data.migrate(profile.Data)
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

-- A brand-new player's data (also used by the smoke test's simulated players).
function Data.fresh(): PlayerData
	local d = deep(TEMPLATE)
	Data.sanitize(d)
	return d
end

-- Admin: wipe back to a brand-new player (receipts kept so purchases never vanish).
function Data.reset(player: Player): PlayerData?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local fresh = Data.fresh()
	fresh.Receipts = profile.Data.Receipts
	profile.Data = fresh
	return fresh
end

function Data.release(player: Player)
	local profile = profiles[player]
	if profile then
		profiles[player] = nil
		profile:EndSession()
	end
end

return Data
