--!strict
-- Game passes, developer products and gifts (ids in Config/Products; 0 = not created yet -> skipped).
-- Gifts: the buyer picks someone on the server (GiftTarget remote), then buys the pass's gift
-- product; the receiver gets the pass for good (saved in their data). If the receiver left before
-- the purchase finished, the buyer gets the pass instead (said in the gift dialog).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Products = require(Shared.Config.Products)
local Progression = require(Shared.Progression)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Data = require(script.Parent.Data)
local Wallet = require(script.Parent.Wallet)
local Bases = require(script.Parent.Bases)
local Movement = require(script.Parent.Movement)

local Product = {}

local giftTargets: { [Player]: number } = {}

local function vipTag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or head:FindFirstChild("VipTag") then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "VipTag"
	bb.Size = UDim2.fromOffset(90, 24)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 80
	bb.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = "💎 VIP"
	l.TextColor3 = Color3.fromRGB(120, 230, 255)
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Color = Color3.fromRGB(10, 40, 70)
	s.Parent = l
	l.Parent = bb
	bb.Parent = head
end

-- Called on every spawn (cosmetics that live on the character).
function Product.onCharacter(player: Player)
	local s = State.get(player)
	if s and s.passes.VIP then
		task.wait(0.3)
		vipTag(player)
	end
end

local function grantPass(player: Player, key: string)
	local s = State.get(player)
	if not s then
		return
	end
	s.passes[key] = true
	player:SetAttribute("Pass_" .. key, true)
	Bases.changed(player)
	if key == "VIP" then
		vipTag(player)
	end
end

function Product.loadPasses(player: Player)
	local s = State.get(player)
	for _, pass in Products.Passes do
		local owns = s ~= nil and s.data.GiftedPasses[pass.key] == true
		if not owns and pass.id > 0 then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			owns = ok and result == true
		end
		if owns then
			grantPass(player, pass.key)
		end
	end
end

local function celebrate(player: Player, text: string)
	Net.announce("🎉 " .. player.DisplayName .. " " .. text .. " 🎉", { 120, 230, 255 }, "Bounty")
end

local function grantProduct(player: Player, s: State.PlayerState, product: Products.Product)
	if product.kind == "speed" then
		s.data.Speed += Progression.treadmillRate(s.data.Treadmill) * product.amount
		Movement.refresh(player)
		Net.notice(player, "⚡ " .. product.name .. ": speed boosted!", "good")
	elseif product.kind == "cash" then
		local amount = math.max(Products.MinCashProduct, Bases.incomePerSecond(player) * product.amount)
		Wallet.add(player, amount)
		Net.notice(player, "💰 +" .. Format.cash(amount), "good")
		Net.fire(player, Remotes.Names.CashFX, amount, nil)
	end
end

local function grantGift(buyer: Player, pass: Products.Pass)
	local targetId = giftTargets[buyer]
	giftTargets[buyer] = nil
	local target = if targetId then Players:GetPlayerByUserId(targetId) else nil
	local ts = target and State.get(target)
	if target and ts and not ts.passes[pass.key] then
		ts.data.GiftedPasses[pass.key] = true
		grantPass(target, pass.key)
		Net.notice(target, "🎁 " .. buyer.DisplayName .. " gifted you " .. pass.name .. "!", "good")
		Net.notice(buyer, "🎁 You gifted " .. pass.name .. " to " .. target.DisplayName .. "!", "good")
		celebrate(buyer, "gifted " .. pass.name .. " to " .. target.DisplayName .. "!")
		return
	end
	-- receiver gone (or got it meanwhile): the buyer keeps the pass
	local bs = State.get(buyer)
	if bs then
		bs.data.GiftedPasses[pass.key] = true
		grantPass(buyer, pass.key)
		Net.notice(buyer, "🎁 Your friend left, so " .. pass.name .. " is yours!", "good")
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
	local handled = false
	for _, p in Products.Items do
		if p.id > 0 and p.id == info.ProductId then
			grantProduct(player, s, p)
			handled = true
		end
	end
	for _, pass in Products.Passes do
		if pass.giftId > 0 and pass.giftId == info.ProductId then
			grantGift(player, pass)
			handled = true
		end
	end
	if not handled then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(s.data.Receipts, receiptId)
	while #s.data.Receipts > 100 do
		table.remove(s.data.Receipts, 1)
	end
	if not Data.saveAndWait(player) then
		-- not saved yet: Roblox retries the receipt; the receipt id prevents double grants
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
				celebrate(player, "unlocked " .. pass.emoji .. " " .. pass.name .. "!")
			end
		end
	end)
	local giftLimit = RateLimit.new(1, 4)
	Net.on(Remotes.Names.GiftTarget, function(player, targetId)
		if giftLimit(player) and typeof(targetId) == "number" and targetId ~= player.UserId then
			giftTargets[player] = targetId
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		giftTargets[player] = nil
	end)
	-- Premium joins/leaves change the cash bonus
	Players.PlayerMembershipChanged:Connect(function(player)
		if State.get(player) then
			Bases.changed(player)
		end
	end)
end

return Product
