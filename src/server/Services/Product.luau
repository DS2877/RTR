--!strict
-- Robux: game passes (owned forever) and developer products (ProcessReceipt, granted once per
-- purchase id, kept in the profile). Known contents only: every amount is shown before buying.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Products = require(Shared.Config.Products)
local Zones = require(Shared.Config.Zones)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Stats = require(script.Parent.Stats)
local Loot = require(script.Parent.Loot)

local Product = {}

local MAX_RECEIPTS = 60

-- hooks (set in init)
Product.onPasses = nil :: ((player: Player) -> ())?

local function byKey(list: { Products.Product }, key: string): Products.Product?
	for _, p in list do
		if p.key == key then
			return p
		end
	end
	return nil
end

local function byId(list: { Products.Product }, id: number): Products.Product?
	for _, p in list do
		if p.id == id and id ~= 0 then
			return p
		end
	end
	return nil
end

-- Noodles a pack gives this player right now (shown in the Store before buying).
function Product.packAmount(s: State.PlayerState, key: string): number
	local blocks = if key == "NoodlesBig" then Products.NoodlesBigBlocks else Products.NoodlesSmallBlocks
	local zone = Zones[math.clamp(s.data.Zone, 1, #Zones)]
	return blocks * zone.rubble
end

function Product.syncPackAttributes(player: Player)
	local s = State.get(player)
	if s and typeof(player) == "Instance" then
		player:SetAttribute("PackSmall", Product.packAmount(s, "NoodlesSmall"))
		player:SetAttribute("PackBig", Product.packAmount(s, "NoodlesBig"))
		player:SetAttribute("Dynamite", s.data.Dynamite)
	end
end

-- Grants a developer product. Returns true when granted.
function Product.grant(player: Player, key: string): boolean
	local s = State.get(player)
	if not s then
		return false
	end
	if key == "Dynamite" then
		s.data.Dynamite += 1
		Net.notice(player, "🧨 +1 Dynamite! Tap the 🧨 button in your tunnel.", "upgrade")
	elseif key == "NoodlesSmall" or key == "NoodlesBig" then
		local amount = Product.packAmount(s, key)
		Loot.addNoodles(player, amount)
		Net.notice(player, "+" .. Format.noodles(amount), "cash")
	elseif key == "InstantEmpty" then
		local pay = Loot.dumpAnywhere(player)
		Net.notice(player, "💨 Backpack emptied: +" .. Format.noodles(pay), "cash")
	else
		return false
	end
	Product.syncPackAttributes(player)
	Stats.sync(player)
	return true
end

local function ownPass(player: Player, s: State.PlayerState, p: Products.Product)
	if p.id == 0 then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, p.id)
	end)
	if ok and owns then
		s.passes[p.key] = true
	end
end

function Product.loadPasses(player: Player)
	local s = State.get(player)
	if not s or typeof(player) ~= "Instance" then
		return
	end
	for _, p in Products.Passes do
		ownPass(player, s, p)
	end
	Product.applyPasses(player)
end

function Product.applyPasses(player: Player)
	local s = State.get(player)
	if not s then
		return
	end
	if typeof(player) == "Instance" then
		for _, p in Products.Passes do
			player:SetAttribute("Pass_" .. p.key, s.passes[p.key] == true)
		end
		player:SetAttribute("VIP", s.passes.VIP == true)
	end
	Stats.sync(player)
	if Product.onPasses then
		Product.onPasses(player)
	end
end

function Product.start()
	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		local s = player and State.get(player)
		if not player or not s then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local receipts = s.data.Receipts
		if table.find(receipts, info.PurchaseId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local p = byId(Products.Items, info.ProductId)
		if not p or not Product.grant(player, p.key) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		table.insert(receipts, info.PurchaseId)
		while #receipts > MAX_RECEIPTS do
			table.remove(receipts, 1)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		local s = State.get(player)
		local p = byId(Products.Passes, passId)
		if bought and s and p then
			s.passes[p.key] = true
			Net.notice(player, p.emoji .. " " .. p.name .. " unlocked! Thank you!", "upgrade")
			Product.applyPasses(player)
		end
	end)
	local limit = RateLimit.new(1, 3)
	Net.on(Remotes.Names.RobuxBuy, function(player, key)
		if not limit(player) or typeof(key) ~= "string" then
			return
		end
		local pass = byKey(Products.Passes, key)
		local item = byKey(Products.Items, key)
		local p = pass or item
		if not p then
			return
		end
		if p.id == 0 then
			Net.notice(player, "The Store opens very soon!", "info")
			return
		end
		if pass then
			MarketplaceService:PromptGamePassPurchase(player, p.id)
		else
			MarketplaceService:PromptProductPurchase(player, p.id)
		end
	end)
end

return Product
