--!strict
-- Game passes and developer products (ids in Config/Products; 0 = not created yet -> skipped).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Products = require(Shared.Config.Products)
local Progression = require(Shared.Progression)
local Format = require(Shared.Format)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local Data = require(script.Parent.Data)
local Wallet = require(script.Parent.Wallet)
local Bases = require(script.Parent.Bases)
local Movement = require(script.Parent.Movement)

local Product = {}

local function grantPass(player: Player, key: string)
	local s = State.get(player)
	if not s then
		return
	end
	s.passes[key] = true
	player:SetAttribute("Pass_" .. key, true)
	Bases.changed(player)
end

function Product.loadPasses(player: Player)
	for _, pass in Products.Passes do
		if pass.id > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and owns then
				grantPass(player, pass.key)
			end
		end
	end
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local s = player and State.get(player)
	if not player or not s then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptId = tostring(info.PurchaseId)
	if table.find(s.data.Receipts, receiptId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = nil
	for _, p in Products.Items do
		if p.id == info.ProductId then
			product = p
		end
	end
	if not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if product.kind == "speed" then
		s.data.Speed += Progression.treadmillRate(s.data.Treadmill) * product.amount
		Movement.refresh(player)
		Net.notice(player, "⚡ Speed boosted!", "good")
	elseif product.kind == "cash" then
		local amount = math.max(1000, Bases.incomePerSecond(player) * product.amount)
		Wallet.add(player, amount)
		Net.notice(player, "💰 +" .. Format.cash(amount), "good")
	end
	table.insert(s.data.Receipts, receiptId)
	while #s.data.Receipts > 100 do
		table.remove(s.data.Receipts, 1)
	end
	if not Data.saveAndWait(player) then
		-- not saved: undo is not possible here, but Roblox retries; the receipt id prevents double grants
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Product.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, pass in Products.Passes do
			if pass.id == passId then
				grantPass(player, pass.key)
				Net.notice(player, "Thanks! " .. pass.name .. " unlocked!", "good")
			end
		end
	end)
end

return Product
