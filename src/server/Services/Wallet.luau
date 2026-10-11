--!strict
-- Cash in and out, kept in sync with the player's attributes and leaderstats.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local State = require(script.Parent.Parent.State)

local Wallet = {}

function Wallet.sync(player: Player)
	local s = State.get(player)
	if not s then
		return
	end
	player:SetAttribute("Cash", s.data.Cash)
	local ls = player:FindFirstChild("leaderstats")
	local cash = ls and ls:FindFirstChild("Cash")
	if cash and cash:IsA("StringValue") then
		cash.Value = Format.cash(s.data.Cash)
	end
	local steals = ls and ls:FindFirstChild("Steals")
	if steals and steals:IsA("IntValue") then
		steals.Value = s.data.Stats.Steals + s.data.Stats.PlayerSteals
	end
end

function Wallet.add(player: Player, amount: number)
	local s = State.get(player)
	if not s or amount ~= amount or amount <= 0 then
		return
	end
	s.data.Cash += amount
	s.data.Stats.Earned += amount
	Wallet.sync(player)
end

function Wallet.spend(player: Player, amount: number): boolean
	local s = State.get(player)
	if not s or s.data.Cash < amount then
		return false
	end
	s.data.Cash -= amount
	Wallet.sync(player)
	return true
end

function Wallet.setupLeaderstats(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Parent = ls
	local steals = Instance.new("IntValue")
	steals.Name = "Steals"
	steals.Parent = ls
	ls.Parent = player
	Wallet.sync(player)
end

return Wallet
