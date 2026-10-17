--!strict
-- Panels for the STORE (Robux, known contents), THE CANTEEN (one panel, three tabs: LAUNDRY,
-- MESS HALL, BLACK MARKET + snitch) and the DECOR list (opened from the Workshop panel).
-- Each canteen counter opens the canteen on its own tab; every tab sells at every canteen counter
-- (the server checks you're near one of them). It closes when you walk away from all of them.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Products = require(Shared.Config.Products)
local Extras = require(Shared.Config.Extras)
local Cycle = require(Shared.Config.Cycle)
local Zones = require(Shared.Config.Zones)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local Client = script.Parent.Parent
local UI = require(Client.Util.UI)
local Panel = require(Client.Util.Panel)
local Sound = require(Client.Util.Sound)

local ExtraShops = {}

local player = Players.LocalPlayer

local function clear(body: Instance)
	for _, c in body:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
end

local function zone(): number
	local z = player:GetAttribute("Zone")
	return if typeof(z) == "number" then z else 1
end

local function noodles(): number
	local n = player:GetAttribute("Noodles")
	return if typeof(n) == "number" then n else 0
end

-- one row: emoji + name + description on the left, a button on the right
local function row(
	body: Instance,
	order: number,
	title: string,
	desc: string,
	buttonText: string,
	good: boolean,
	onTap: () -> ()
)
	local r = Panel.row(body, order, 64)
	Panel.text("title", title, {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(0.66, -12, 0, 18),
		Parent = r,
	})
	Panel.text("desc", desc, {
		Position = UDim2.fromOffset(12, 27),
		Size = UDim2.new(0.66, -12, 0, 30),
		TextSize = 13,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = r,
	})
	local b = Panel.button(
		{
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0.28, 0, 0, 44),
		},
		if good then Color3.fromRGB(90, 220, 110) else Color3.fromRGB(190, 190, 190),
		Color3.fromRGB(30, 80, 40),
		buttonText
	)
	b.Parent = r
	b.Activated:Connect(function()
		Sound.play("Click")
		onTap()
	end)
	return r
end

local function listPanel(name: string, title: string, color: Color3, dark: Color3): Panel.Panel
	local p = Panel.new(name, title, color, dark, Vector2.new(560, 310))
	UI.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = p.body }
	)
	return p
end

local panels: { [string]: Panel.Panel } = {}
local renders: { [string]: () -> () } = {}

-- THE CANTEEN's tabs (ids = the counters' shop names)
local TABS = {
	{ id = "Laundry", label = "🧺 Laundry", color = Color3.fromRGB(120, 210, 230) },
	{ id = "MessHall", label = "🍲 Mess Hall", color = Color3.fromRGB(255, 160, 90) },
	{ id = "BlackMarket", label = "🕶️ Black Market", color = Color3.fromRGB(170, 140, 220) },
}
local TAB_HEIGHT = 60 -- pre-scale: ~46 pt on a landscape iPhone 11 (UI.PANEL_SCALE)
local tab = "Laundry"
local setTab: (id: string) -> () = function(_id: string) end

local function rerender(name: string)
	local p = panels[name]
	if p and p.isOpen() then
		renders[name]()
	end
end

function ExtraShops.open(name: string): boolean
	for _, t in TABS do
		if t.id == name then
			setTab(name)
			panels.Canteen.setOpen(true)
			return true
		end
	end
	local p = panels[name]
	if p then
		p.setOpen(true)
		return true
	end
	return false
end

function ExtraShops.start()
	local robux = Remotes.get(Remotes.Names.RobuxBuy)
	local buyItem = Remotes.get(Remotes.Names.BuyItem)
	local equip = Remotes.get(Remotes.Names.Equip)

	-- ===== STORE =====
	panels.Store =
		listPanel("StorePanel", "📞 VISITATION", Color3.fromRGB(255, 200, 40), Color3.fromRGB(110, 70, 0))
	renders.Store = function()
		local body = panels.Store.body
		clear(body)
		panels.Store.subtitle.Text = "Robux"
		local order = 0
		for _, p in Products.Passes do
			order += 1
			local owned = player:GetAttribute("Pass_" .. p.key) == true
			row(
				body,
				order,
				p.emoji .. " " .. p.name,
				p.desc,
				if owned then "OWNED" else "R$ " .. p.price,
				not owned,
				function()
					if not owned then
						robux:FireServer(p.key)
					end
				end
			)
		end
		for _, p in Products.Items do
			if p.key == "StarterPack" and player:GetAttribute("StarterBought") == true then
				continue -- (once per prisoner)
			end
			order += 1
			local desc = p.desc
			if p.key == "NoodlesSmall" then
				desc = "You get "
					.. Format.noodles(player:GetAttribute("PackSmall") or 0)
					.. " (based on your zone)"
			elseif p.key == "NoodlesBig" then
				desc = "You get "
					.. Format.noodles(player:GetAttribute("PackBig") or 0)
					.. " (based on your zone)"
			elseif p.key == "NoodlesHuge" then
				desc = "You get "
					.. Format.noodles(player:GetAttribute("PackHuge") or 0)
					.. " (based on your zone)"
			end
			row(body, order, p.emoji .. " " .. p.name, desc, "R$ " .. p.price, true, function()
				robux:FireServer(p.key)
			end)
		end
	end

	-- ===== THE CANTEEN: LAUNDRY tab =====
	local function renderLaundry(body: Instance)
		local owned: { [string]: boolean } = {}
		for _, id in string.split(tostring(player:GetAttribute("UniformsOwned") or ""), ",") do
			owned[id] = true
		end
		owned.Orange = true
		local current = player:GetAttribute("Uniform")
		local fist = player:GetAttribute("Fist")
		row(
			body,
			0,
			"👕 Your own clothes",
			"Take the uniform off.",
			if current == "" then "WEARING" else "WEAR",
			current ~= "",
			function()
				equip:FireServer("uniform", "Own")
			end
		)
		local order = 0
		for _, it in Extras.Uniforms do
			order += 1
			local have = owned[it.id]
			local text = if current == it.id
				then "WEARING"
				elseif have then "WEAR"
				elseif it.pass then "🎫 PASS"
				elseif it.starter then "🎁 PACK"
				elseif it.daily then "📅 DAY 7"
				else Format.noodles(Progression.itemPrice(it, zone()))
			-- (exclusives you don't own yet are earned elsewhere: a muted button)
			local exclusive = not have and (it.pass or it.starter or it.daily) == true
			row(
				body,
				order,
				it.emoji .. " " .. it.name,
				it.desc,
				text,
				current ~= it.id and not exclusive,
				function()
					if have then
						equip:FireServer("uniform", it.id)
					else
						buyItem:FireServer("Laundry", it.id)
					end
				end
			)
		end
		for _, it in Extras.Fists do
			order += 1
			local have = owned[it.id]
			local text = if fist == it.id
				then "TAKE OFF"
				elseif have then "EQUIP"
				elseif it.pass then "🎫 PASS"
				elseif it.starter then "🎁 PACK"
				elseif it.daily then "📅 DAY 7"
				else Format.noodles(Progression.itemPrice(it, zone()))
			row(body, order, it.emoji .. " " .. it.name, it.desc, text, true, function()
				if have then
					equip:FireServer("uniform", it.id)
				else
					buyItem:FireServer("Laundry", it.id)
				end
			end)
		end
	end

	-- ===== THE CANTEEN: MESS HALL tab =====
	local function renderMess(body: Instance)
		local buffs = tostring(player:GetAttribute("Buffs") or "")
		for i, it in Extras.Meals do
			local active = string.find("," .. buffs .. ",", "," .. (it.buff or "?") .. ",", 1, true) ~= nil
			row(
				body,
				i,
				it.emoji .. " " .. it.name,
				it.desc,
				if active then "EATEN ✓" else Format.noodles(Progression.itemPrice(it, zone())),
				not active,
				function()
					if not active then
						buyItem:FireServer("MessHall", it.id)
					end
				end
			)
		end
	end

	-- ===== THE CANTEEN: BLACK MARKET tab (+ snitch) =====
	local function renderMarket(body: Instance)
		local now = workspace:GetServerTimeNow()
		local left = 86400 - (now % 86400)
		Panel.text("note", "🕶️ Today's deals · new stock in " .. Format.duration(left), {
			LayoutOrder = 0,
			Size = UDim2.new(1, -6, 0, 22),
			Parent = body,
		})
		local day = ReplicatedStorage:GetAttribute("MarketDay")
		local stock =
			Progression.marketStock(if typeof(day) == "number" then day else math.floor(now / 86400))
		local order = 0
		for _, id in stock do
			for _, it in Extras.Market do
				if it.id == id then
					order += 1
					row(
						body,
						order,
						it.emoji .. " " .. it.name,
						it.desc,
						Format.noodles(Progression.itemPrice(it, zone())),
						true,
						function()
							buyItem:FireServer("BlackMarket", it.id)
						end
					)
				end
			end
		end
		order += 1
		Panel.text("note", "🤫 SNITCH: tip off the guard (they get a visit tonight)", {
			LayoutOrder = order,
			Size = UDim2.new(1, -6, 0, 26),
			Parent = body,
		})
		for _, other in Players:GetPlayers() do
			if other ~= player then
				order += 1
				local z = other:GetAttribute("Zone")
				local zoneValue = Zones[math.clamp(if typeof(z) == "number" then z else 1, 1, #Zones)].rubble
				local cost = Cycle.SnitchBlocks * zoneValue
				row(
					body,
					order,
					"👤 " .. other.DisplayName,
					"@" .. other.Name,
					Format.noodles(cost),
					true,
					function()
						Remotes.get(Remotes.Names.Snitch):FireServer(other.UserId)
					end
				)
			end
		end
	end

	-- ===== THE CANTEEN: one panel, a big segmented control on top =====
	local canteen = Panel.new(
		"CanteenPanel",
		"🏪 THE CANTEEN",
		Color3.fromRGB(120, 210, 230),
		Color3.fromRGB(10, 70, 90),
		Vector2.new(580, 380)
	)
	panels.Canteen = canteen
	UI.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = canteen.body }
	)
	local segTop = 54
	canteen.body.Position = UDim2.fromOffset(12, segTop + TAB_HEIGHT + 8)
	canteen.body.Size = UDim2.new(1, -24, 1, -(segTop + TAB_HEIGHT + 16))
	local seg = UI.new("Frame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(12, segTop),
		Size = UDim2.new(1, -24, 0, TAB_HEIGHT),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.94,
		Parent = canteen.frame,
	}, {
		UI.corner(14),
		UI.stroke(Color3.new(1, 1, 1), 1, 0.9),
		UI.new("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
		}),
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local tabButtons: { [string]: TextButton } = {}
	for i, t in TABS do
		local b: TextButton = UI.new("TextButton", {
			Name = t.id,
			LayoutOrder = i,
			Size = UDim2.new(1 / #TABS, -3, 1, 0),
			BackgroundColor3 = t.color,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = t.label,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextColor3 = Panel.MUTED,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = seg,
		}, { UI.corner(11) })
		b.Activated:Connect(function()
			if tab ~= t.id then
				Sound.play("Click")
				setTab(t.id)
			end
		end)
		tabButtons[t.id] = b
	end
	renders.Canteen = function()
		local body = canteen.body
		clear(body)
		canteen.subtitle.Text = Format.noodles(noodles())
		if tab == "MessHall" then
			renderMess(body)
		elseif tab == "BlackMarket" then
			renderMarket(body)
		else
			renderLaundry(body)
		end
	end
	setTab = function(id: string)
		tab = id
		for _, t in TABS do
			local b = tabButtons[t.id]
			local on = t.id == id
			b.BackgroundTransparency = if on then 0 else 1
			b.TextColor3 = if on then UI.INK else Panel.MUTED
			b.Font = if on then Enum.Font.GothamBlack else Enum.Font.GothamBold
		end
		canteen.body.CanvasPosition = Vector2.zero
		rerender("Canteen")
	end
	setTab(tab)

	-- ===== DECOR (from the Workshop) =====
	panels.Decor =
		listPanel("DecorPanel", "💡 DECOR", Color3.fromRGB(255, 180, 90), Color3.fromRGB(110, 60, 0))
	renders.Decor = function()
		local body = panels.Decor.body
		clear(body)
		panels.Decor.subtitle.Text = Format.noodles(noodles())
		local owned: { [string]: number } = {}
		for _, pair in string.split(tostring(player:GetAttribute("DecorOwned") or ""), ",") do
			local id, n = string.match(pair, "(%w+)=(%d+)")
			if id then
				owned[id] = tonumber(n) or 0
			end
		end
		for i, it in Extras.Decor do
			local have = owned[it.id] or 0
			row(
				body,
				i,
				it.emoji .. " " .. it.name .. (if have > 0 then "  x" .. have else ""),
				it.desc .. " Place it with 💡 in your tunnel.",
				Format.noodles(Progression.itemPrice(it, zone())),
				noodles() >= Progression.itemPrice(it, zone()),
				function()
					buyItem:FireServer("Decor", it.id)
				end
			)
		end
	end

	for name, p in panels do
		p.onOpen = renders[name]
	end
	for _, attr in
		{ "Noodles", "UniformsOwned", "Uniform", "Fist", "Buffs", "DecorOwned", "PackSmall", "StarterBought" }
	do
		player:GetAttributeChangedSignal(attr):Connect(function()
			for name in panels do
				rerender(name)
			end
		end)
	end
	for _, p in Products.Passes do
		player:GetAttributeChangedSignal("Pass_" .. p.key):Connect(function()
			rerender("Store")
		end)
	end
	Remotes.get(Remotes.Names.OpenShop).OnClientEvent:Connect(function(name)
		ExtraShops.open(name)
	end)
	-- walk away from every canteen counter: the canteen closes (like the upgrade counters)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if canteen.isOpen() and r and r:IsA("BasePart") then
				local near = false
				for _, counter in CollectionService:GetTagged("Shop") do
					local name = counter:GetAttribute("Shop")
					if
						counter:IsA("BasePart")
						and (name == "Laundry" or name == "MessHall" or name == "BlackMarket")
						and (counter.Position - r.Position).Magnitude <= 26
					then
						near = true
					end
				end
				if not near then
					canteen.setOpen(false)
				end
			end
		end
	end)
end

return ExtraShops
