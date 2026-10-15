--!strict
-- Admin commands for phone testing. The ADMIN button in the HUD (admins only) sends AdminCmd;
-- the same commands work in chat with "!": !noodles 1e6  !strength 500  !zone 3  !resettunnel
-- !stress  !reset  !day  !night  (!inspect !event arrive with M4).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local AdminConfig = require(Shared.Config.Admin)
local World = require(Shared.Config.World)
local Progression = require(Shared.Progression)
local Tunnel = require(Shared.Tunnel)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Data = require(script.Parent.Data)
local Stats = require(script.Parent.Stats)
local Dig = require(script.Parent.Dig)
local Loot = require(script.Parent.Loot)
local DayNight = require(script.Parent.DayNight)

local Admin = {}

function Admin.isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(AdminConfig.UserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and rank >= AdminConfig.GroupMinRank
end

-- The stress layout (same as tests/Shell.spec.luau): a 6x6 tunnel 120 deep with big side rooms.
function Admin.stress(player: Player)
	Dig.digBox(player, 6, 0, 0, 11, 5, 119)
	for z = 10, 110, 20 do
		Dig.digBox(player, 1, 0, z, 16, 8, z + 5)
	end
end

local function teleportInto(player: Player, z: number)
	local s = State.get(player)
	local character = player.Character
	if not s or not s.frame or not character then
		return
	end
	local pos = Tunnel.blockCenter(s.frame, World.TunnelWidth // 2, 1, z)
	character:PivotTo(CFrame.lookAt(pos, pos + s.frame.LookVector))
end

function Admin.run(player: Player, cmd: string, arg: number?): boolean
	local s = State.get(player)
	if not s then
		return false
	end
	cmd = string.lower(cmd)
	if cmd == "noodles" then
		Loot.addNoodles(player, arg or 1e6)
	elseif cmd == "strength" then
		s.data.Strength = math.max(1, math.floor(arg or 1000))
		Stats.sync(player)
	elseif cmd == "zone" then
		local zone = math.clamp(math.floor(arg or 2), 1, 10)
		local start = Progression.zoneStart(zone)
		local mid = World.TunnelWidth // 2
		if start > 0 then
			-- a 3x3 path to just before the zone (break the last layer yourself for the WOW)
			Dig.digBox(player, mid - 1, 0, 0, mid + 1, 2, start - 2)
		end
		teleportInto(player, math.max(0, start - 3))
	elseif cmd == "resettunnel" then
		Dig.resetTunnel(player)
		Net.notice(player, "Tunnel reset", "info")
	elseif cmd == "stress" then
		Admin.stress(player)
		teleportInto(player, 2)
	elseif cmd == "fill" then
		s.data.Bag = Stats.capacity(s)
		s.data.BagValue = s.data.Bag
		Stats.sync(player)
	elseif cmd == "reset" then
		Dig.forget(player)
		local fresh = Data.reset(player)
		if fresh then
			player:Kick("Data reset. Rejoin!")
		end
		return true
	elseif cmd == "day" or cmd == "night" then
		DayNight.force(cmd)
	elseif cmd == "inspect" or cmd == "event" then
		Net.notice(player, "Comes with M4 (guards and events)", "info")
		return true
	else
		Net.notice(player, "Unknown admin command: " .. cmd, "bad")
		return false
	end
	Net.notice(player, "Admin: " .. cmd .. (if arg then " " .. tostring(arg) else ""), "info")
	return true
end

function Admin.start()
	local limit = RateLimit.new(2, 5)
	Net.on(Remotes.Names.AdminCmd, function(player, cmd, arg)
		if not limit(player) or typeof(cmd) ~= "string" or #cmd > 20 then
			return
		end
		if arg ~= nil and (typeof(arg) ~= "number" or arg ~= arg) then
			return
		end
		if Admin.isAdmin(player) then
			Admin.run(player, cmd, arg)
		end
	end)
	local function hook(player: Player)
		local admin = Admin.isAdmin(player)
		player:SetAttribute("Admin", admin)
		if not admin then
			return
		end
		player.Chatted:Connect(function(message)
			local parts = string.split(message, " ")
			local first = parts[1] or ""
			if string.sub(first, 1, 1) == "!" then
				Admin.run(player, string.sub(first, 2), tonumber(parts[2]))
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		task.spawn(hook, p)
	end
end

return Admin
