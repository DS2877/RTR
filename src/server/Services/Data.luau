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
	RunDepth: number, -- deepest layer of this run's tunnel (0 again after an escape)
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
	TutorialStep: number, -- 1..5 = current step, 6 = done (analytics funnel only)
	TourDone: boolean, -- saw the first-join tour (Controllers/Tour)
	Missions: {
		Day: number,
		Progress: { number },
		Claimed: { boolean },
		Bonus: boolean,
		Seed: number?,
		NoDepth: boolean?,
	}, -- WORK DETAIL
	LastOnline: number,
	Week: { Id: number, Blocks: number }, -- the weekly race (Services/TopDog): blocks since Monday
	-- bought buffs that outlive a rejoin: id -> os.time() it ends (0 = "until the morning")
	Buffs: { [string]: number },
	StarterBought: boolean, -- the one-time Starter Pack
	BuffsAt: number, -- when Buffs was written
	-- PRISON PASS: this season's XP, premium, claimed tiers ("1".."30" -> true)
	Pass: {
		Season: number,
		Xp: number,
		Premium: boolean,
		Free: { [string]: boolean },
		Paid: { [string]: boolean },
	},
	Stats: {
		Punches: number,
		Blocks: number,
		FindsDug: number,
		Earned: number,
		Lifts: number,
		Steals: number,
		Robbed: number,
		Knockouts: number,
		BestCombo: number,
		Gold: number, -- gold blocks broken
		Jackpots: number,
		CaveIns: number,
		Breakouts: number, -- finished escape runs (with a medal)
		BestEscape: number, -- fastest escape run in seconds (0 = none yet)
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
	RunDepth = 0,
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
	TourDone = false,
	Missions = { Day = 0, Progress = { 0, 0, 0 }, Claimed = { false, false, false }, Bonus = false },
	LastOnline = 0,
	Week = { Id = 0, Blocks = 0 },
	Buffs = {},
	StarterBought = false,
	BuffsAt = 0,
	Pass = { Season = 0, Xp = 0, Premium = false, Free = {}, Paid = {} },
	Stats = {
		Punches = 0,
		Blocks = 0,
		FindsDug = 0,
		Earned = 0,
		Lifts = 0,
		Steals = 0,
		Robbed = 0,
		Knockouts = 0,
		BestCombo = 0,
		Gold = 0,
		Jackpots = 0,
		CaveIns = 0,
		Breakouts = 0,
		BestEscape = 0,
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
local releasing: { [Player]: boolean } = {} -- we end the session ourselves (leaving, shutdown)

-- Called right before every save of a player's profile (init: write the live tunnel into it, so
-- the saved Noodles / finds never get ahead of the saved tunnel).
Data.onSave = nil :: ((player: Player) -> ())?

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
	profile.OnSave:Connect(function()
		if Data.onSave and profiles[player] == profile then
			local ok, err = pcall(Data.onSave, player)
			if not ok then
				warn("[Data] onSave", err)
			end
		end
	end)
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if releasing[player] then
			releasing[player] = nil
		elseif player.Parent == Players then
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

-- The player's profile is loaded and still owned by this server (purchases go only into a live one).
function Data.isActive(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile:IsActive()
end

-- Save now (after a Robux purchase); no-op without a live profile.
function Data.save(player: Player)
	local profile = profiles[player]
	if profile and profile:IsActive() then
		profile:Save()
	end
end

function Data.release(player: Player)
	local profile = profiles[player]
	if profile then
		releasing[player] = true
		profile:EndSession() -- (OnSessionEnd clears the flag)
		profiles[player] = nil
	end
end

return Data
