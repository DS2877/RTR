--!strict
-- Retention: daily reward streak, playtime gifts, the group bonus and the Cellmate who digs a
-- little while you're away (capped: never more than your free backpack space).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Cycle = require(Shared.Config.Cycle)
local Zones = require(Shared.Config.Zones)
local Extras = require(Shared.Config.Extras)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)
local Progression = require(Shared.Progression)

local HttpService = game:GetService("HttpService")

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
-- the exclusive uniform was given: put it on (Market.equip)
Rewards.onUniform = nil :: ((player: Player, id: string) -> ())?

local function uniformName(): string
	for _, it in Extras.Uniforms do
		if it.id == Economy.DailyUniform then
			return it.emoji .. " " .. it.name
		end
	end
	return Economy.DailyUniform
end

-- What the client shows (Jobs panel strip, the daily card): the streak, whether today is claimed,
-- tomorrow's day and every day's known prize, plus the next playtime gift. The client never works
-- out a reward itself: this is the truth. (Also the smoke test's view.)
function Rewards.calendar(player: Player, day: number?): any?
	local s = State.get(player)
	if not s then
		return nil
	end
	local d = s.data.Daily
	local today = day or Rewards.today()
	local claimed = d.Day >= today
	-- the day you're on: today's claimed day, or the one you'd get by claiming now
	local current = if claimed then d.Streak else Progression.dailyStreak(d.Day, d.Streak, today)
	local tomorrow = if claimed
		then Progression.dailyStreak(today, d.Streak, today + 1)
		else Progression.dailyStreak(today, current, today + 1)
	return {
		streak = current,
		claimed = claimed,
		tomorrow = tomorrow,
		days = Progression.dailyCalendar(s.data.Zone, s.data.Uniforms[Economy.DailyUniform] == true),
		uniformName = uniformName(),
		gift = Economy.GiftBlocks * zoneValue(s),
		giftEvery = Economy.GiftMinutes,
	}
end

function Rewards.syncCalendar(player: Player)
	if typeof(player) ~= "Instance" then
		return
	end
	local info = Rewards.calendar(player)
	if info then
		player:SetAttribute("DailyInfo", HttpService:JSONEncode(info))
	end
end

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
	d.Streak = Progression.dailyStreak(d.Day, d.Streak, today)
	d.Day = today
	local prize =
		Progression.dailyCalendar(s.data.Zone, s.data.Uniforms[Economy.DailyUniform] == true)[d.Streak]
	local amount = prize.noodles
	Loot.addNoodles(player, amount)
	local text = string.format("DAY %d STREAK! +%s", d.Streak, Format.noodles(amount))
	if prize.dynamite > 0 then
		s.data.Dynamite += prize.dynamite
		if typeof(player) == "Instance" then
			player:SetAttribute("Dynamite", s.data.Dynamite)
		end
		text ..= " + 🧨"
	end
	-- the exclusive uniform: once (owning it is the flag), put on right away
	if prize.uniform and not s.data.Uniforms[prize.uniform] then
		s.data.Uniforms[prize.uniform] = true
		text ..= " + " .. uniformName()
		if Rewards.onUniform then
			Rewards.onUniform(player, prize.uniform)
		end
	end
	Rewards.syncCalendar(player)
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

-- INVITES: a brand-new prisoner who came from a friend's invite (Roblox join data) gets
-- Economy.ReferralDynamite 🧨, and so does the friend if they're on this server (known contents).
local function giveDynamite(player: Player, n: number, text: string)
	local s = State.get(player)
	if not s then
		return
	end
	s.data.Dynamite += n
	if typeof(player) == "Instance" then
		player:SetAttribute("Dynamite", s.data.Dynamite)
	end
	Net.fire(player, Remotes.Names.Reward, "invite", text)
end

function Rewards.referral(player: Player, referrerId: number?)
	local s = State.get(player)
	if not s or not referrerId or referrerId == 0 or referrerId == player.UserId then
		return false
	end
	-- only for a new prisoner, once
	if s.data.ReferredBy ~= 0 or s.data.PlayMinutes > 5 then
		return false
	end
	s.data.ReferredBy = referrerId
	local n = Economy.ReferralDynamite
	local friend: Player? = nil
	for p in State.all() do
		if (p :: any).UserId == referrerId then
			friend = p
		end
	end
	giveDynamite(player, n, string.format("📨 You came on a friend's invite: +%d 🧨 Dynamite!", n))
	if friend then
		giveDynamite(
			friend,
			n,
			string.format("📨 %s joined on your invite: +%d 🧨 Dynamite!", (player :: any).Name, n)
		)
	end
	return true
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
		local ok, join = pcall(function()
			return player:GetJoinData()
		end)
		local ref = if ok and typeof(join) == "table" then (join :: any).ReferredByPlayerId else nil
		if typeof(ref) == "number" then
			Rewards.referral(player, ref)
		end
	end
	if typeof(player) == "Instance" then
		s.premium = player.MembershipType == Enum.MembershipType.Premium
		player:SetAttribute("PremiumBonus", s.premium)
		if game.CreatorType == Enum.CreatorType.Group then
			local ok, member = pcall(function()
				return player:IsInGroup(game.CreatorId)
			end)
			s.groupBonus = ok and member == true
			player:SetAttribute("GroupBonus", s.groupBonus)
		end
		Rewards.syncCalendar(player)
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
					-- still here at midnight (UTC): the next day of the streak, no rejoin needed
					if s.data.Daily.Day > 0 and s.data.Daily.Day < Rewards.today() then
						Rewards.daily(player)
					else
						Rewards.syncCalendar(player) -- (zone changes move the prizes)
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
