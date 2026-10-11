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

local UI = require(script.Parent.Parent.Util.UI)
local Panel = require(script.Parent.Parent.Util.Panel)
local HUD = require(script.Parent.HUD)

local Panels = {}

local player = Players.LocalPlayer
local state: any = { Found = {}, Slots = {}, Passes = {} }

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
local function buildShop(panel: Panel.Panel)
	local body = panel.body
	UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(170, 190),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = body,
	})
	local function entry(
		order: number,
		emoji: string,
		name: string,
		desc: string,
		price: number,
		id: number,
		owned: boolean,
		isPass: boolean
	)
		local c = card(body, order, Color3.fromRGB(255, 120, 140))
		UI.label({
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.new(1, 0, 0, 44),
			Text = emoji,
			Font = Enum.Font.GothamBold,
			Parent = c,
		})
		UI.bigText(
			{ Position = UDim2.fromOffset(6, 52), Size = UDim2.new(1, -12, 0, 24), Text = name, Parent = c },
			Color3.fromRGB(120, 30, 50),
			2
		)
		UI.label({
			Position = UDim2.fromOffset(8, 78),
			Size = UDim2.new(1, -16, 0, 50),
			Text = desc,
			TextColor3 = Color3.fromRGB(60, 60, 70),
			Font = Enum.Font.GothamMedium,
			TextWrapped = true,
			Parent = c,
		})
		local label = if owned then "OWNED" elseif id == 0 then "SOON" else "R$ " .. price
		local color = if owned
			then Color3.fromRGB(120, 200, 120)
			elseif id == 0 then Color3.fromRGB(160, 160, 170)
			else Color3.fromRGB(70, 210, 90)
		local b = Panel.button(
			{ Position = UDim2.new(0, 10, 1, -50), Size = UDim2.new(1, -20, 0, 40) },
			color,
			color:Lerp(Color3.new(), 0.5),
			label
		)
		b.Parent = c
		b.Activated:Connect(function()
			if owned or id == 0 then
				return
			end
			if isPass then
				MarketplaceService:PromptGamePassPurchase(player, id)
			else
				MarketplaceService:PromptProductPurchase(player, id)
			end
		end)
	end
	panel.onOpen = function()
		clear(body)
		local order = 0
		for _, p in Products.Passes do
			order += 1
			entry(order, p.emoji, p.name, p.desc, p.price, p.id, state.Passes[p.key] == true, true)
		end
		for _, p in Products.Items do
			order += 1
			entry(order, p.emoji, p.name, p.desc, p.price, p.id, false, false)
		end
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
		for _, item in state.Slots do
			local key = item.Id .. "|" .. item.Mut
			local g = groups[key]
			if not g then
				g = { id = item.Id, mut = item.Mut, count = 0 }
				groups[key] = g
			end
			g.count += 1
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
	buildShop(shop)
	buildIndex(index)
	buildFuse(fuse)

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
