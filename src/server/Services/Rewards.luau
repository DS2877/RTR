--!strict
-- Retention: daily reward streak, playtime gifts, the group bonus and the Cellmate who digs a
-- little while you're away (capped: never more than your free backpack space).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Cycle = require(Shared.Config.Cycle)
local Zones = require(Shared.Config.Zones)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local Stats = require(script.Parent.Stats)
local Loot = require(script.Parent.Loot)

local Rewards = {}

local function zoneValue(s: State.PlayerState): number
	return Zones[math.clamp(s.data.Zone, 1, #Zones)].rubble
end

function Rewards.today(): number
	return os.time() // 86400
end

Rewards.onDaily = nil :: ((player: Player, streak: number) -> ())?

-- Returns the Noodles given (0 = already claimed today).
function Rewards.daily(player: Player, day: number?): number
	local s = State.get(player)
	if not s then
		return 0
	end
	local d = s.data.Daily
	local today = day or Rewards.today()
	if d.Day >= today then
		return 0
	end
	-- a missed day halves the streak instead of wiping it
	d.Streak = if d.Day == today - 1
		then math.min(d.Streak + 1, Economy.DailyMaxStreak)
		else math.max(1, math.floor(d.Streak / 2) + 1)
	d.Day = today
	local amount = Economy.DailyBlocks * zoneValue(s) * d.Streak
	Loot.addNoodles(player, amount)
	local text = string.format("DAY %d STREAK! +%s", d.Streak, Format.noodles(amount))
	if d.Streak >= Economy.DailyMaxStreak then
		s.data.Dynamite += 1
		if typeof(player) == "Instance" then
			player:SetAttribute("Dynamite", s.data.Dynamite)
		end
		text ..= " + 🧨"
	end
	Net.fire(player, Remotes.Names.Reward, "daily", text)
	if Rewards.onDaily then
		Rewards.onDaily(player, d.Streak)
	end
	return amount
end

-- Counted at roll call (in your own cell when it ended).
function Rewards.rollCall(player: Player): number
	local s = State.get(player)
	if not s then
		return 0
	end
	local amount = Cycle.RollCallBlocks * zoneValue(s)
	Loot.addNoodles(player, amount)
	Net.fire(player, Remotes.Names.Reward, "rollcall", "Counted at roll call! +" .. Format.noodles(amount))
	return amount
end

-- WHILE YOU SLEPT: your bunkmate keeps digging while you're offline and sells it for you.
-- Returns the Noodles paid.
function Rewards.cellmate(player: Player, awaySeconds: number): number
	local s = State.get(player)
	if not s or awaySeconds < Economy.CellmateMinMinutes * 60 then
		return 0
	end
	local minutes = math.min(awaySeconds, Economy.CellmateMaxHours * 3600) / 60
	local amount = math.floor(minutes * Economy.CellmatePerMinute * zoneValue(s) * Economy.CellmateValue)
	if amount <= 0 then
		return 0
	end
	Loot.addNoodles(player, amount)
	Stats.sync(player)
	local hours = minutes / 60
	Net.fire(
		player,
		Remotes.Names.Reward,
		"cellmate",
		string.format(
			"💤 While you were away (%s) your bunkmate kept digging: +%s",
			if hours >= 1
				then string.format("%.1f h", hours)
				else string.format("%d min", math.floor(minutes)),
			Format.noodles(amount)
		)
	)
	return amount
end

-- `lastOnline` = when this player was last seen (before this join overwrote it).
function Rewards.onJoin(player: Player, lastOnline: number?)
	local s = State.get(player)
	if not s then
		return
	end
	if lastOnline and lastOnline > 0 then
		Rewards.cellmate(player, os.time() - lastOnline)
	end
	if typeof(player) == "Instance" then
		if game.CreatorType == Enum.CreatorType.Group then
			local ok, member = pcall(function()
				return player:IsInGroup(game.CreatorId)
			end)
			s.groupBonus = ok and member == true
			player:SetAttribute("GroupBonus", s.groupBonus)
		end
		task.delay(4, function()
			if player.Parent then
				Rewards.daily(player)
			end
		end)
	end
end

function Rewards.start()
	-- playtime gifts
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				task.wait(60)
				for player, s in State.all() do
					s.data.PlayMinutes += 1
					if typeof(player) == "Instance" then
						player:SetAttribute("PlayMinutes", s.data.PlayMinutes)
					end
					if s.data.PlayMinutes % Economy.GiftMinutes == 0 then
						local amount = Economy.GiftBlocks * zoneValue(s)
						Loot.addNoodles(player, amount)
						Net.fire(
							player,
							Remotes.Names.Reward,
							"gift",
							"🎁 Playtime gift: +" .. Format.noodles(amount)
						)
					end
				end
			end)
			if not ok then
				warn("[Rewards] loop:", err)
				task.wait(1)
			end
		end
	end)
end

return Rewards
