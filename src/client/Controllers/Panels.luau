--!strict
-- Shop (Robux), Index (every item, found or ???) and Fuse (3 identical -> next mutation).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Progression = require(Shared.Progression)
local Products = require(Shared.Config.Products)
local Vaults = require(Shared.Config.Vaults)
local Rarity = require(Shared.Config.Rarity)
local Mutations = require(Shared.Config.Mutations)
local Cosmetics = require(Shared.Config.Cosmetics)

local UI = require(script.Parent.Parent.Util.UI)
local Panel = require(script.Parent.Parent.Util.Panel)
local HUD = require(script.Parent.HUD)

local Panels = {}

local player = Players.LocalPlayer
local state: any = { Found = {}, Slots = {}, Inventory = {}, Passes = {} }

local function clear(body: ScrollingFrame)
	for _, c in body:GetChildren() do
		if not c:IsA("UIGridLayout") and not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

local function card(parent: Instance, order: number, color: Color3): Frame
	return UI.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = order,
		Parent = parent,
	}, { UI.corner(14), UI.stroke(color, 3) })
end

-- ===== Shop =====
-- One scrolling page: PASSES (forever) then BOOSTS (one-time). Every card says exactly what you
-- get. Passes can be gifted to someone on the server. "BEST VALUE" = cheapest Robux per amount.
local giftPanel: Panel.Panel
local giftPass: Products.Pass? = nil

local function shopCard(
	parent: Instance,
	order: number,
	emoji: string,
	name: string,
	desc: string,
	priceText: string,
	buttonColor: Color3,
	onBuy: (() -> ())?,
	badge: string?
): Frame
	local c = card(parent, order, Color3.fromRGB(255, 120, 140))
	UI.label({
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 46),
		Text = emoji,
		Font = Enum.Font.GothamBold,
		Parent = c,
	})
	UI.bigText(
		{ Position = UDim2.fromOffset(6, 56), Size = UDim2.new(1, -12, 0, 24), Text = name, Parent = c },
		Color3.fromRGB(120, 30, 50),
		2
	)
	UI.label({
		Position = UDim2.fromOffset(8, 82),
		Size = UDim2.new(1, -16, 0, 58),
		Text = desc,
		TextColor3 = Color3.fromRGB(60, 60, 70),
		Font = Enum.Font.GothamMedium,
		TextWrapped = true,
		Parent = c,
	})
	local b = Panel.button(
		{ Position = UDim2.new(0, 10, 1, -50), Size = UDim2.new(1, -20, 0, 42) },
		buttonColor,
		buttonColor:Lerp(Color3.new(), 0.5),
		priceText
	)
	b.Parent = c
	b.Activated:Connect(function()
		if onBuy then
			onBuy()
		end
	end)
	if badge then
		local ribbon = UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 2),
			Size = UDim2.fromOffset(120, 24),
			BackgroundColor3 = Color3.fromRGB(255, 200, 40),
			ZIndex = 3,
			Parent = c,
		}, { UI.corner(12), UI.stroke(Color3.fromRGB(140, 90, 0), 2) })
		UI.bigText({
			Position = UDim2.fromOffset(4, 2),
			Size = UDim2.new(1, -8, 1, -4),
			Text = badge,
			ZIndex = 4,
			Parent = ribbon,
		}, Color3.fromRGB(120, 70, 0), 2)
	end
	return c
end

local function section(parent: Instance, order: number, text: string): Frame
	UI.bigText({
		Size = UDim2.new(1, -12, 0, 30),
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 120, 140),
		LayoutOrder = order,
		Parent = parent,
	}, Color3.fromRGB(90, 20, 40), 2.5)
	return UI.new("Frame", {
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order + 1,
		Parent = parent,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(176, 206),
			CellPadding = UDim2.fromOffset(10, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UI.new("UIPadding", { PaddingTop = UDim.new(0, 10) }),
	})
end

local function buildShop(panel: Panel.Panel)
	local body = panel.body
	UI.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body }
	)
	panel.onOpen = function()
		clear(body)
		local passes = section(body, 1, "⭐ PASSES — yours forever")
		for i, p in Products.Passes do
			local owned = state.Passes[p.key] == true
			local soon = p.id == 0
			local c = shopCard(
				passes,
				i,
				p.emoji,
				p.name,
				p.desc,
				if owned then "OWNED" elseif soon then "SOON" else "R$ " .. p.price,
				if owned
					then Color3.fromRGB(120, 200, 120)
					elseif soon then Color3.fromRGB(160, 160, 170)
					else Color3.fromRGB(70, 210, 90),
				if owned or soon
					then nil
					else function()
						MarketplaceService:PromptGamePassPurchase(player, p.id)
					end
			)
			if p.giftId > 0 then
				local gift = Panel.button({
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -6, 0, 6),
					Size = UDim2.fromOffset(46, 40),
					ZIndex = 3,
				}, Color3.fromRGB(255, 170, 60), Color3.fromRGB(120, 60, 0), "🎁")
				gift.Parent = c
				gift.Activated:Connect(function()
					giftPass = p
					giftPanel.setOpen(true)
				end)
			end
		end
		local best = Products.bestValue()
		local boosts = section(body, 3, "⚡ BOOSTS — instant, one time")
		for i, p in Products.Items do
			local soon = p.id == 0
			shopCard(
				boosts,
				i,
				p.emoji,
				p.name,
				p.desc,
				if soon then "SOON" else "R$ " .. p.price,
				if soon then Color3.fromRGB(160, 160, 170) else Color3.fromRGB(70, 210, 90),
				if soon
					then nil
					else function()
						MarketplaceService:PromptProductPurchase(player, p.id)
					end,
				if best[p.kind] == p.key and not soon then "BEST VALUE" else nil
			)
		end
	end
end

-- Pick who gets the gift (only players who don't own that pass yet).
local function buildGift(panel: Panel.Panel)
	local body = panel.body
	UI.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body }
	)
	panel.onOpen = function()
		clear(body)
		local pass = giftPass
		if not pass then
			return
		end
		panel.subtitle.Text = pass.emoji .. " " .. pass.name
		UI.label({
			Size = UDim2.new(1, -12, 0, 44),
			Text = "Gift "
				.. pass.name
				.. " (R$ "
				.. pass.price
				.. ") to someone on this server. If they leave before the purchase finishes, the pass is yours.",
			TextColor3 = Color3.fromRGB(60, 60, 70),
			Font = Enum.Font.GothamMedium,
			TextWrapped = true,
			LayoutOrder = 0,
			Parent = body,
		})
		local anyone = false
		for i, other in Players:GetPlayers() do
			if other ~= player and not other:GetAttribute("Pass_" .. pass.key) then
				anyone = true
				local b = Panel.button(
					{ Size = UDim2.new(1, -12, 0, 52), LayoutOrder = i },
					Color3.fromRGB(255, 170, 60),
					Color3.fromRGB(120, 60, 0),
					"🎁 " .. other.DisplayName
				)
				b.Parent = body
				b.Activated:Connect(function()
					Remotes.get(Remotes.Names.GiftTarget):FireServer(other.UserId)
					MarketplaceService:PromptProductPurchase(player, pass.giftId)
					panel.setOpen(false)
				end)
			end
		end
		if not anyone then
			UI.bigText({
				Size = UDim2.new(1, -12, 0, 40),
				Text = "Nobody here can get this gift right now.",
				TextColor3 = Color3.fromRGB(255, 140, 60),
				LayoutOrder = 1,
				Parent = body,
			}, Color3.new(1, 1, 1), 2)
		end
	end
end

-- Contextual offer: one product that fits the moment (caught by a faster guard -> speed,
-- short on cash for an upgrade -> cash). At most one every few minutes, never while a menu is open.
local OFFER_COOLDOWN = 240
local lastOffer = -math.huge
local offerPanel: Panel.Panel
local offerProduct: Products.Product? = nil

local function buildOffer(panel: Panel.Panel)
	local body = panel.body
	panel.onOpen = function()
		clear(body)
		local p = offerProduct
		if not p then
			return
		end
		UI.label({
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(0.3, 0, 1, -10),
			Text = p.emoji,
			Font = Enum.Font.GothamBold,
			Parent = body,
		})
		UI.bigText({
			Position = UDim2.new(0.3, 0, 0, 4),
			Size = UDim2.new(0.7, -10, 0, 34),
			Text = p.name,
			TextColor3 = Color3.fromRGB(255, 120, 140),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = body,
		}, Color3.fromRGB(90, 20, 40), 2.5)
		UI.label({
			Position = UDim2.new(0.3, 0, 0, 42),
			Size = UDim2.new(0.7, -10, 0, 50),
			Text = p.desc,
			TextColor3 = Color3.fromRGB(60, 60, 70),
			Font = Enum.Font.GothamMedium,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = body,
		})
		local buy = Panel.button(
			{ Position = UDim2.new(0.3, 0, 1, -58), Size = UDim2.new(0.38, -10, 0, 50) },
			Color3.fromRGB(70, 210, 90),
			Color3.fromRGB(20, 90, 30),
			"R$ " .. p.price
		)
		buy.Parent = body
		buy.Activated:Connect(function()
			MarketplaceService:PromptProductPurchase(player, p.id)
			panel.setOpen(false)
		end)
		local no = Panel.button(
			{ Position = UDim2.new(0.68, 0, 1, -58), Size = UDim2.new(0.32, -10, 0, 50) },
			Color3.fromRGB(170, 170, 180),
			Color3.fromRGB(70, 70, 80),
			"NO THANKS"
		)
		no.Parent = body
		no.Activated:Connect(function()
			panel.setOpen(false)
		end)
	end
end

local function offer(kind: string, title: string)
	if os.clock() - lastOffer < OFFER_COOLDOWN or Panel.anyOpen() then
		return
	end
	local pick: Products.Product? = nil
	for _, p in Products.Items do
		if p.kind == kind and p.id > 0 and (not pick or p.price < pick.price) then
			pick = p
		end
	end
	if not pick then
		return
	end
	lastOffer = os.clock()
	offerProduct = pick
	offerPanel.subtitle.Text = title
	task.delay(1.2, function()
		if not Panel.anyOpen() then
			offerPanel.setOpen(true)
		end
	end)
end

-- ===== Trails =====
-- Cash trails, Halloween candy trails (during the season) and the Rainbow Trail pass.
local function buildTrails(panel: Panel.Panel)
	local body = panel.body
	UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(176, 196),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = body,
	})
	panel.onOpen = function()
		clear(body)
		local season = workspace:GetAttribute("Season") == "Halloween"
		local owned: { [string]: boolean } = {}
		for _, id in string.split(player:GetAttribute("TrailsOwned") or "", ",") do
			owned[id] = true
		end
		local equipped = player:GetAttribute("Trail") or ""
		panel.subtitle.Text = if season
			then "🍬 " .. Format.number(player:GetAttribute("Candy") or 0)
			else ""
		for i, t in Cosmetics.Trails do
			if t.currency == "candy" and not season and not owned[t.id] then
				continue
			end
			local has = owned[t.id]
				or (t.currency == "pass" and t.pass ~= nil and state.Passes[t.pass] == true)
			local c = card(body, i, Color3.fromRGB(200, 120, 255))
			UI.label({
				Position = UDim2.fromOffset(0, 6),
				Size = UDim2.new(1, 0, 0, 40),
				Text = t.emoji,
				Font = Enum.Font.GothamBold,
				Parent = c,
			})
			UI.bigText({
				Position = UDim2.fromOffset(6, 48),
				Size = UDim2.new(1, -12, 0, 24),
				Text = t.name .. "  ⚡x" .. t.mult,
				Parent = c,
			}, Color3.fromRGB(70, 20, 110), 2)
			-- color preview
			local keys = {}
			for k, col in t.colors do
				table.insert(
					keys,
					ColorSequenceKeypoint.new((k - 1) / math.max(1, #t.colors - 1), UI.rgb(col))
				)
			end
			if #keys == 1 then
				table.insert(keys, ColorSequenceKeypoint.new(1, UI.rgb(t.colors[1])))
			end
			UI.new("Frame", {
				Position = UDim2.fromOffset(14, 82),
				Size = UDim2.new(1, -28, 0, 26),
				BackgroundColor3 = Color3.new(1, 1, 1),
				Parent = c,
			}, { UI.corner(13), UI.new("UIGradient", { Color = ColorSequence.new(keys) }) })
			local label: string
			local color: Color3
			local action: (() -> ())? = nil
			if has and equipped == t.id then
				label, color = "EQUIPPED", Color3.fromRGB(120, 200, 120)
				action = function()
					Remotes.get(Remotes.Names.EquipTrail):FireServer("")
				end
			elseif has then
				label, color = "EQUIP", Color3.fromRGB(160, 90, 255)
				action = function()
					Remotes.get(Remotes.Names.EquipTrail):FireServer(t.id)
				end
			elseif t.currency == "pass" then
				local pass = t.pass and Products.pass(t.pass)
				if pass and pass.id > 0 then
					label, color = "R$ " .. pass.price, Color3.fromRGB(70, 210, 90)
					action = function()
						MarketplaceService:PromptGamePassPurchase(player, pass.id)
					end
				else
					label, color = "SOON", Color3.fromRGB(160, 160, 170)
				end
			elseif t.currency == "candy" then
				label, color = t.price .. " 🍬", Color3.fromRGB(255, 150, 40)
				action = function()
					Remotes.get(Remotes.Names.BuyTrail):FireServer(t.id)
				end
			else
				label, color = Format.cash(t.price), Color3.fromRGB(70, 210, 90)
				action = function()
					Remotes.get(Remotes.Names.BuyTrail):FireServer(t.id)
				end
			end
			local b = Panel.button(
				{ Position = UDim2.new(0, 10, 1, -54), Size = UDim2.new(1, -20, 0, 44) },
				color,
				color:Lerp(Color3.new(), 0.5),
				label
			)
			b.Parent = c
			b.Activated:Connect(function()
				if action then
					action()
				end
			end)
		end
	end
	-- refresh while open (bought / equipped / candy changed)
	for _, a in { "TrailsOwned", "Trail", "Candy" } do
		player:GetAttributeChangedSignal(a):Connect(function()
			if panel.isOpen() and panel.onOpen then
				panel.onOpen()
			end
		end)
	end
end

-- ===== Index =====
local function buildIndex(panel: Panel.Panel)
	local body = panel.body
	UI.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body }
	)
	panel.onOpen = function()
		clear(body)
		local found, total = 0, 0
		for vi, v in Vaults do
			local row = UI.new("Frame", {
				Size = UDim2.new(1, -12, 0, 132),
				BackgroundColor3 = UI.rgb(v.color):Lerp(Color3.new(1, 1, 1), 0.6),
				LayoutOrder = vi,
				Parent = body,
			}, { UI.corner(14), UI.stroke(UI.rgb(v.trim), 3) })
			UI.bigText({
				Position = UDim2.fromOffset(10, 4),
				Size = UDim2.new(1, -20, 0, 26),
				Text = v.emoji .. " " .. v.name,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			}, UI.rgb(v.trim), 2.5)
			local grid = UI.new("Frame", {
				Position = UDim2.fromOffset(8, 34),
				Size = UDim2.new(1, -16, 0, 92),
				BackgroundTransparency = 1,
				Parent = row,
			}, {
				UI.new("UIGridLayout", {
					CellSize = UDim2.fromOffset(84, 92),
					CellPadding = UDim2.fromOffset(6, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})
			for ri, it in v.items do
				total += 1
				local has = state.Found[it.id] == true
				if has then
					found += 1
				end
				local tier = Rarity.Tiers[Rarity.Order[ri]]
				local cell = card(grid, ri, UI.rgb(tier.color))
				UI.label({
					Position = UDim2.fromOffset(0, 4),
					Size = UDim2.new(1, 0, 0, 36),
					Text = if has then it.emoji else "❓",
					Font = Enum.Font.GothamBold,
					Parent = cell,
				})
				UI.label({
					Position = UDim2.fromOffset(4, 42),
					Size = UDim2.new(1, -8, 0, 28),
					Text = if has then it.name else "???",
					TextColor3 = Color3.fromRGB(40, 40, 50),
					Font = Enum.Font.GothamBold,
					TextWrapped = true,
					Parent = cell,
				})
				UI.label({
					Position = UDim2.fromOffset(4, 72),
					Size = UDim2.new(1, -8, 0, 16),
					Text = Format.cash(Progression.income(it.id)) .. "/s",
					TextColor3 = UI.rgb(tier.color):Lerp(Color3.new(), 0.3),
					Font = Enum.Font.GothamBold,
					Parent = cell,
				})
			end
		end
		panel.subtitle.Text = found .. " / " .. total
	end
end

-- ===== Fuse =====
local function buildFuse(panel: Panel.Panel)
	local body = panel.body
	UI.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body }
	)
	panel.onOpen = function()
		clear(body)
		local groups: { [string]: { id: string, mut: string, count: number } } = {}
		local function add(item: any)
			local key = item.Id .. "|" .. item.Mut
			local g = groups[key]
			if not g then
				g = { id = item.Id, mut = item.Mut, count = 0 }
				groups[key] = g
			end
			g.count += 1
		end
		for _, item in state.Slots or {} do
			add(item)
		end
		for _, item in state.Inventory or {} do
			add(item)
		end
		local list = {}
		for _, g in groups do
			if Mutations.next(g.mut) then
				table.insert(list, g)
			end
		end
		table.sort(list, function(a, b)
			return Progression.income(a.id, a.mut) > Progression.income(b.id, b.mut)
		end)
		if #list == 0 then
			UI.bigText({
				Size = UDim2.new(1, -12, 0, 40),
				Text = "Steal some items first!",
				TextColor3 = Color3.fromRGB(120, 80, 200),
				Parent = body,
			}, Color3.new(1, 1, 1), 2)
		end
		for i, g in list do
			local info = Progression.item(g.id) :: any
			local nextMut = Mutations.next(g.mut) :: string
			local row = UI.new("Frame", {
				Size = UDim2.new(1, -12, 0, 64),
				BackgroundColor3 = Color3.new(1, 1, 1),
				LayoutOrder = i,
				Parent = body,
			}, { UI.corner(14), UI.stroke(Color3.fromRGB(150, 70, 255), 3) })
			UI.label({
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(48, 48),
				Text = info.emoji,
				Font = Enum.Font.GothamBold,
				Parent = row,
			})
			UI.label({
				Position = UDim2.fromOffset(62, 6),
				Size = UDim2.new(1, -250, 0, 28),
				Text = (if g.mut ~= "None" then g.mut .. " " else "") .. info.name .. "  x" .. g.count,
				TextColor3 = Color3.fromRGB(40, 40, 50),
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})
			UI.label({
				Position = UDim2.fromOffset(62, 34),
				Size = UDim2.new(1, -250, 0, 22),
				Text = "→ " .. nextMut .. " " .. info.name .. " (" .. Format.cash(
					Progression.income(g.id, nextMut)
				) .. "/s)",
				TextColor3 = UI.rgb(Mutations.List[nextMut].color :: { number }),
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})
			local can = g.count >= Mutations.FuseCount
			local color = if can then Color3.fromRGB(160, 80, 255) else Color3.fromRGB(170, 170, 180)
			local b = Panel.button(
				{
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(170, 46),
				},
				color,
				color:Lerp(Color3.new(), 0.5),
				if can then "FUSE 3" else g.count .. "/" .. Mutations.FuseCount
			)
			b.Parent = row
			b.Activated:Connect(function()
				if can then
					Remotes.get(Remotes.Names.Fuse):FireServer(g.id, g.mut)
					panel.setOpen(false)
				end
			end)
		end
	end
end

function Panels.start()
	local shop = Panel.new(
		"ShopPanel",
		"SHOP",
		Color3.fromRGB(255, 90, 110),
		Color3.fromRGB(120, 20, 40),
		Vector2.new(600, 330)
	)
	local index = Panel.new(
		"IndexPanel",
		"INDEX",
		Color3.fromRGB(80, 170, 255),
		Color3.fromRGB(20, 60, 120),
		Vector2.new(600, 330)
	)
	local fuse = Panel.new(
		"FusePanel",
		"FUSE MACHINE",
		Color3.fromRGB(160, 80, 255),
		Color3.fromRGB(60, 20, 120),
		Vector2.new(600, 330)
	)
	giftPanel = Panel.new(
		"GiftPanel",
		"🎁 GIFT",
		Color3.fromRGB(255, 170, 60),
		Color3.fromRGB(120, 60, 0),
		Vector2.new(460, 330)
	)
	offerPanel = Panel.new(
		"OfferPanel",
		"BOOST?",
		Color3.fromRGB(110, 210, 255),
		Color3.fromRGB(20, 70, 120),
		Vector2.new(480, 230)
	)
	buildShop(shop)
	buildIndex(index)
	buildFuse(fuse)
	buildGift(giftPanel)
	buildOffer(offerPanel)
	local trails = Panel.new(
		"TrailsPanel",
		"🌈 TRAILS",
		Color3.fromRGB(200, 120, 255),
		Color3.fromRGB(70, 20, 110),
		Vector2.new(600, 330)
	)
	buildTrails(trails)
	Remotes.get(Remotes.Names.OpenTrails).OnClientEvent:Connect(function()
		trails.setOpen(true)
	end)
	HUD.buttons.Trails.Activated:Connect(trails.toggle)
	HUD.buttons.Event.Activated:Connect(trails.toggle) -- Halloween: candy trails live in the trails shop
	Remotes.get(Remotes.Names.Offer).OnClientEvent:Connect(function(kind: string)
		if kind == "cash" then
			offer("cash", "Short on cash?")
		end
	end)
	Remotes.get(Remotes.Names.Caught).OnClientEvent:Connect(function(_by: string, tooSlow: boolean?)
		if tooSlow then
			offer("speed", "That guard is faster!")
		end
	end)

	Remotes.get(Remotes.Names.Sync).OnClientEvent:Connect(function(s: any)
		state = s
		if index.isOpen() and index.onOpen then
			index.onOpen()
		end
		if shop.isOpen() and shop.onOpen then
			shop.onOpen()
		end
	end)
	Remotes.get(Remotes.Names.OpenFuse).OnClientEvent:Connect(function()
		task.wait(0.15) -- the Sync sent just before this lands first
		fuse.setOpen(true)
	end)
	HUD.buttons.Shop.Activated:Connect(shop.toggle)
	HUD.buttons.Index.Activated:Connect(index.toggle)
	Remotes.get(Remotes.Names.RequestSync):FireServer()
end

return Panels
