--!strict
-- Chat commands for testing (admins only, re-checked here):
--   !cash 1e9   !speed 1e6   !item GoldBar Diamond   !reroll   !event GoldRush 90   !candy 500   !reset
-- ("!" instead of "/" so the Roblox chat never swallows them as unknown chat commands)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local AdminConfig = require(Shared.Config.Admin)
local Progression = require(Shared.Progression)
local Mutations = require(Shared.Config.Mutations)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local Data = require(script.Parent.Data)
local Wallet = require(script.Parent.Wallet)
local Bases = require(script.Parent.Bases)
local Movement = require(script.Parent.Movement)
local VaultLoot = require(script.Parent.Vaults)
local Events = require(script.Parent.Events)
local Cosmetic = require(script.Parent.Cosmetic)

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

local function run(player: Player, message: string)
	local args = string.split(message, " ")
	local cmd = string.lower(args[1] or "")
	local s = State.get(player)
	if not s then
		return
	end
	if cmd == "!cash" then
		Wallet.add(player, tonumber(args[2]) or 1e6)
	elseif cmd == "!speed" then
		s.data.Speed += tonumber(args[2]) or 1e4
		Movement.refresh(player)
	elseif cmd == "!item" then
		local id = args[2] or ""
		local mut = args[3] or "None"
		if Progression.item(id) and Mutations.List[mut] then
			Bases.addItem(player, id, mut)
		else
			Net.notice(player, "Unknown item/mutation", "bad")
			return
		end
	elseif cmd == "!reroll" then
		VaultLoot.rerollAll()
	elseif cmd == "!candy" then
		Cosmetic.addCandy(player, tonumber(args[2]) or 500)
	elseif cmd == "!event" then
		if not Events.start(args[2] or "GoldRush", tonumber(args[3])) then
			Net.notice(player, "Events: GoldRush, GuardStrike, CashFrenzy", "bad")
			return
		end
	elseif cmd == "!reset" then
		Data.reset(player)
		player:Kick("Data reset. Rejoin!")
		return
	else
		return
	end
	Net.notice(player, "Admin: " .. message, "info")
end

function Admin.start()
	local function hook(player: Player)
		player.Chatted:Connect(function(message)
			if string.sub(message, 1, 1) == "!" and Admin.isAdmin(player) then
				run(player, message)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
end

return Admin
