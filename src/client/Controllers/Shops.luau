--!strict
-- Shop panels, opened by the counters' ProximityPrompts in the Common Room (no shop buttons in the
-- HUD). Workshop: tools + brushes. Commissary: backpack, find slots, vacuum. The Fence: sell finds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Upgrades = require(Shared.Config.Upgrades)
local Economy = require(Shared.Config.Economy)
local Finds = require(Shared.Config.Finds)
local Rarity = require(Shared.Config.Rarity)
local Progression = require(Shared.Progression)
local Locker = require(Shared.Locker)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local Client = script.Parent.Parent
local UI = require(Client.Util.UI)
local Panel = require(Client.Util.Panel)
local Sound = require(Client.Util.Sound)

local Shops = {}

-- the Workshop's DECOR button (ExtraShops opens the panel)
Shops.openDecor = nil :: (() -> ())?

-- CELL CATALOG: the upgrade panels opened from your cell at night show (and charge) the catalog
-- price; opened at a counter they're the normal shop
local catalog = false
local upgradePanels: { [string]: any } = {}

local player = Players.LocalPlayer

-- the same price the server charges (Shop.price): Bargain Hunter perk off, catalog markup on top
local function price(track: string, level: number): number?
	local bargain = player:GetAttribute(Locker.attr("Bargain"))
	local cost = Progression.upgradeCost(
		track,
		level,
		{ Bargain = if typeof(bargain) == "number" then bargain else 0 }
	)
	if cost and catalog then
		return math.ceil(cost * Economy.CatalogMarkup)
	end
	return cost
end

local TRACK_INFO: { [string]: { title: string, unit: (v: any) -> string } } = {
	Tools = {
		title = "TOOL",
		unit = function(v)
			return "x" .. v.value .. " punch"
		end,
	},
	Brushes = {
		title = "BRUSH",
		unit = function(v)
			return #v.cells .. " blocks / punch"
		end,
	},
	Backpack = {
		title = "BACKPACK",
		unit = function(v)
			return v.value .. " rubble"
		end,
	},
	FindSlots = {
		title = "FIND SLOTS",
		unit = function(v)
			return v.value .. " finds"
		end,
	},
	Vacuum = {
		title = "VACUUM",
		unit = function(v)
			return v.value .. " studs range"
		end,
	},
	Cart = {
		title = "CART",
		unit = function(v)
			return if v.value > 1 then "x" .. v.value .. " speed in your tunnel" else "walking"
		end,
	},
	Lock = {
		title = "STASH LOCK",
		unit = function(v)
			return v.value .. " s to pick"
		end,
	},
	Trap = {
		title = "TRAP",
		unit = function(v)
			return if v.value > 0 then "thieves slip once a day" else "none"
		end,
	},
	Alarm = {
		title = "ALARM",
		unit = function(v)
			return if v.value > 0 then "warns you + points at the thief" else "none"
		end,
	},
}

local finds: { string } = {}

local function clear(body: Instance)
	for _, c in body:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
end

local row = Panel.row

local function upgradePanel(shop: string, title: string, color: Color3, dark: Color3)
	local panel = Panel.new(shop .. "Panel", title, color, dark, Vector2.new(540, 300))
	UI.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.body }
	)
	local buy = Remotes.get(Remotes.Names.Buy)
	-- which buttons were affordable at the last render ("101"): a Noodles change that doesn't flip
	-- any of them only updates the subtitle
	local function affordKey(): string
		local money = player:GetAttribute("Noodles") or 0
		local key = ""
		for _, track in Upgrades.Shops[shop] do
			local cost = price(track, (player:GetAttribute(track) or 1) :: number)
			key ..= if cost and money >= cost then "1" else "0"
		end
		return key
	end
	local renderedKey = ""
	local function render()
		clear(panel.body)
		renderedKey = affordKey()
		panel.subtitle.Text = Format.noodles(player:GetAttribute("Noodles") or 0)
			.. (
				if catalog
					then "  ·  📦 cell catalog +" .. math.floor((Economy.CatalogMarkup - 1) * 100 + 0.5) .. "%"
					else ""
			)
		for i, track in Upgrades.Shops[shop] do
			local list = (Upgrades :: any)[track]
			local level = (player:GetAttribute(track) or 1) :: number
			local info = TRACK_INFO[track]
			local cur = list[level]
			local nxt = list[level + 1]
			local cost = price(track, level)
			local r = row(panel.body, i, 60)
			Panel.text("note", info.title .. " · LV " .. level, {
				Position = UDim2.fromOffset(12, 5),
				Size = UDim2.new(0.64, -12, 0, 15),
				TextSize = 13,
				TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35),
				Parent = r,
			})
			Panel.text("title", cur.emoji .. " " .. cur.name, {
				Position = UDim2.fromOffset(12, 20),
				Size = UDim2.new(0.64, -12, 0, 18),
				Parent = r,
			})
			Panel.text(
				"desc",
				if nxt
					then string.format("Next: %s %s · %s", nxt.emoji, nxt.name, info.unit(nxt))
					else "Maxed · " .. info.unit(cur),
				{
					Position = UDim2.fromOffset(12, 38),
					Size = UDim2.new(0.64, -12, 0, 16),
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextWrapped = false,
					Parent = r,
				}
			)
			local afford = cost ~= nil and (player:GetAttribute("Noodles") or 0) >= cost
			local text = if cost then Format.noodles(cost) elseif nxt then "SOON" else "MAX"
			local b = Panel.button(
				{
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.new(0.3, 0, 0, 44),
				},
				if afford then Color3.fromRGB(90, 220, 110) else Color3.fromRGB(190, 190, 190),
				Color3.fromRGB(30, 80, 40),
				text
			)
			b.Parent = r
			b.Activated:Connect(function()
				if cost then
					Sound.play(if afford then "Purchase" else "Click")
					buy:FireServer(track)
				end
			end)
		end
		if catalog then
			-- flip between the two catalog pages
			local other = if shop == "Workshop" then "Commissary" else "Workshop"
			local r = row(panel.body, 99, 54)
			local go = Panel.button(
				{
					Position = UDim2.fromOffset(6, 5),
					Size = UDim2.new(1, -12, 0, 44),
				},
				Color3.fromRGB(255, 200, 110),
				Color3.fromRGB(110, 60, 0),
				if other == "Workshop" then "🔨 TOOL CRIB PAGE →" else "🎒 COMMISSARY PAGE →"
			)
			go.Parent = r
			go.Activated:Connect(function()
				Sound.play("Click")
				Shops.openCatalog(other)
			end)
		end
		if shop == "Workshop" and not catalog then
			local r = row(panel.body, 100, 50)
			local decor = Panel.button({
				Position = UDim2.fromOffset(6, 6),
				Size = UDim2.new(1, -12, 1, -12),
			}, Color3.fromRGB(255, 190, 100), Color3.fromRGB(110, 60, 0), "💡 DECOR FOR YOUR TUNNEL")
			decor.Parent = r
			decor.Activated:Connect(function()
				Sound.play("Click")
				if Shops.openDecor then
					Shops.openDecor()
				end
			end)
		end
	end
	panel.onOpen = render
	for _, attr in { Locker.attr("Bargain"), table.unpack(Upgrades.Shops[shop]) } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if panel.isOpen() then
				render()
			end
		end)
	end
	local pending = false
	local lastRender = 0
	player:GetAttributeChangedSignal("Noodles"):Connect(function()
		if not panel.isOpen() then
			return
		end
		if affordKey() == renderedKey then
			panel.subtitle.Text = Format.noodles(player:GetAttribute("Noodles") or 0)
			return
		end
		-- a button flips: rebuild, at most twice a second (Noodles tick fast while you dump)
		if pending then
			return
		end
		pending = true
		task.delay(math.max(0, 0.5 - (os.clock() - lastRender)), function()
			pending = false
			lastRender = os.clock()
			if panel.isOpen() then
				render()
			end
		end)
	end)
	return panel
end

local function fencePanel()
	local panel = Panel.new(
		"FencePanel",
		"💰 THE FENCE",
		Color3.fromRGB(170, 100, 230),
		Color3.fromRGB(60, 20, 90),
		Vector2.new(540, 300)
	)
	UI.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.body }
	)
	local sell = Remotes.get(Remotes.Names.Sell)
	local function render()
		clear(panel.body)
		local total = 0
		for _, id in finds do
			total += Progression.findValue(id)
		end
		panel.subtitle.Text = #finds .. " finds"
		local top = row(panel.body, 0, 50)
		local all = Panel.button(
			{
				Position = UDim2.fromOffset(6, 6),
				Size = UDim2.new(1, -12, 1, -12),
			},
			if #finds > 0 then Color3.fromRGB(255, 210, 60) else Color3.fromRGB(190, 190, 190),
			Color3.fromRGB(110, 70, 0),
			if #finds > 0
				then "SELL ALL  " .. Format.noodles(total)
				else "No finds yet: dig for glowing blocks!"
		)
		all.Parent = top
		all.Activated:Connect(function()
			if #finds > 0 then
				Sound.play("Coin")
				sell:FireServer(0)
			end
		end)
		for i, id in finds do
			local f = Finds.ById[id]
			if f then
				local tier = Rarity.Tiers[f.rarity]
				local r = row(panel.body, i, 54)
				Panel.text("title", f.emoji .. " " .. f.name, {
					Position = UDim2.fromOffset(12, 0),
					Size = UDim2.new(0.66, -12, 1, 0),
					Parent = r,
				})
				Panel.text("note", string.upper(f.rarity), {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(0.7, -8, 0.5, 0),
					Size = UDim2.fromOffset(90, 16),
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Right,
					TextColor3 = UI.rgb(tier.color):Lerp(Color3.new(1, 1, 1), 0.2),
					Parent = r,
				})
				local b = Panel.button({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.new(0.28, 0, 0, 44),
				}, Color3.fromRGB(90, 220, 110), Color3.fromRGB(30, 80, 40), Format.noodles(f.value))
				b.Parent = r
				b.Activated:Connect(function()
					Sound.play("Coin")
					sell:FireServer(i)
				end)
			end
		end
	end
	panel.onOpen = render
	return panel, render
end

-- Opens a catalog page (Controllers/Catalog's 📦 button; the server checks night + your cell).
function Shops.openCatalog(shop: string)
	local p = upgradePanels[shop]
	if p then
		catalog = true
		p.setOpen(true)
		if p.onOpen then
			p.onOpen() -- (re-render when flipping pages: prices change with the mode)
		end
	end
end

-- Morning: the catalog pages close.
function Shops.closeCatalog()
	if not catalog then
		return
	end
	catalog = false
	for _, p in upgradePanels do
		if p.isOpen() then
			p.setOpen(false)
		end
	end
end

function Shops.start()
	local panels = {
		Workshop = upgradePanel(
			"Workshop",
			"🔨 TOOL CRIB",
			Color3.fromRGB(255, 150, 60),
			Color3.fromRGB(110, 50, 0)
		),
		Commissary = upgradePanel(
			"Commissary",
			"🎒 COMMISSARY",
			Color3.fromRGB(80, 170, 255),
			Color3.fromRGB(10, 60, 120)
		),
	}
	local fence, renderFence = fencePanel();
	(panels :: any).Fence = fence
	Remotes.get(Remotes.Names.Finds).OnClientEvent:Connect(function(list)
		finds = list
		if fence.isOpen() then
			renderFence()
		end
	end)
	Remotes.get(Remotes.Names.Found).OnClientEvent:Connect(function(id)
		-- only while there's a free slot (a find with full slots goes to the Stash, not the Fence
		-- list; the server's Finds list stays the truth)
		local slotsAttr = player:GetAttribute("Slots")
		local cap = if typeof(slotsAttr) == "number" then slotsAttr else 3
		if #finds < cap then
			table.insert(finds, id)
		end
	end)
	upgradePanels.Workshop, upgradePanels.Commissary = panels.Workshop, panels.Commissary
	Remotes.get(Remotes.Names.OpenShop).OnClientEvent:Connect(function(name)
		local p = (panels :: any)[name]
		if p then
			catalog = false
			p.setOpen(true)
		end
	end)
	-- close a shop panel when you walk away from the counter
	task.spawn(function()
		while true do
			task.wait(0.5)
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if r and r:IsA("BasePart") then
				for name, p in panels :: any do
					if p.isOpen() and not (catalog and upgradePanels[name]) then
						local counter = workspace:FindFirstChild("Prison")
							and workspace.Prison:FindFirstChild("CommonRoom")
							and workspace.Prison.CommonRoom:FindFirstChild(name)
						local top = counter and counter:FindFirstChild("Counter")
						if top and (top.Position - r.Position).Magnitude > 26 then
							p.setOpen(false)
						end
					end
				end
			end
		end
	end)
end

return Shops
