--!strict
-- Your loot outside the plot, like the genre: the hotbar of items in your bag (tap = place it on
-- your plot), the crate button with counters (crates at the appraiser / ready to open), the
-- APPRAISE CRATES panel with live countdowns, the MY ITEMS panel (Equip Best, place, take off,
-- sell) and the big reveal when a crate opens. Only intents go to the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Progression = require(Shared.Progression)
local Rarity = require(Shared.Config.Rarity)
local Mutations = require(Shared.Config.Mutations)
local Economy = require(Shared.Config.Economy)

local UI = require(script.Parent.Parent.Util.UI)
local Panel = require(script.Parent.Parent.Util.Panel)
local Sound = require(script.Parent.Parent.Util.Sound)
local Shake = require(script.Parent.Parent.Util.Shake)
local HUD = require(script.Parent.HUD)

local Items = {}

local player = Players.LocalPlayer
local state: any = { Slots = {}, Inventory = {}, Crates = {}, Pedestals = 0, CrateSlots = 3 }

local HOTBAR = 5 -- item cells shown in the hotbar (+ the bag button)
local CRATE_EMOJI = "📦"

local function tierColor(rarity: string): Color3
	local t = Rarity.Tiers[rarity]
	return if t then UI.rgb(t.color) else Color3.new(1, 1, 1)
end

local function itemText(id: string, mut: string): string
	local info = Progression.item(id)
	return (if mut ~= "None" then mut .. " " else "") .. (if info then info.name else id)
end

local function clear(body: Instance)
	for _, c in body:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

local function timeText(secs: number): string
	secs = math.max(0, math.ceil(secs))
	if secs >= 60 then
		return string.format("%dm %02ds", secs // 60, secs % 60)
	end
	return secs .. "s"
end

-- A white row card with an emoji, two text lines and room for buttons on the right.
local function row(
	parent: Instance,
	order: number,
	stroke: Color3,
	emoji: string,
	line1: string,
	line2: string,
	line2Color: Color3
): Frame
	local r = UI.new("Frame", {
		Size = UDim2.new(1, -12, 0, 60),
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = order,
		Parent = parent,
	}, { UI.corner(14), UI.stroke(stroke, 3) })
	UI.label({
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.fromOffset(48, 48),
		Text = emoji,
		Font = Enum.Font.GothamBold,
		Parent = r,
	})
	UI.label({
		Position = UDim2.fromOffset(62, 6),
		Size = UDim2.new(1, -300, 0, 26),
		Text = line1,
		TextColor3 = Color3.fromRGB(40, 40, 50),
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = r,
	})
	UI.label({
		Position = UDim2.fromOffset(62, 32),
		Size = UDim2.new(1, -300, 0, 22),
		Text = line2,
		TextColor3 = line2Color,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = r,
	})
	return r
end

local function rowButton(r: Frame, slot: number, text: string, color: Color3, onTap: () -> ()): TextButton
	local b = Panel.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10 - (slot - 1) * 128, 0.5, 0),
		Size = UDim2.fromOffset(118, 44),
	}, color, color:Lerp(Color3.new(), 0.5), text)
	b.Parent = r
	b.Activated:Connect(function()
		Sound.play("Click", 0.4)
		onTap()
	end)
	return b
end

local function fire(name: string, ...: any)
	Remotes.get(name):FireServer(...)
end

-- ===== APPRAISE CRATES =====
local function buildAppraise(panel: Panel.Panel)
	local body = panel.body
	UI.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body }
	)
	local bars: { { fill: Frame, label: TextLabel, readyAt: number, button: TextButton? } } = {}
	panel.onOpen = function()
		clear(body)
		table.clear(bars)
		local crates = state.Crates or {}
		panel.subtitle.Text = #crates .. " / " .. (state.CrateSlots or 3)
		if #crates == 0 then
			UI.bigText({
				Size = UDim2.new(1, -12, 0, 60),
				Text = "No crates yet! Steal one from a rich person and run it home.",
				TextColor3 = Color3.fromRGB(200, 120, 40),
				TextWrapped = true,
				Parent = body,
			}, Color3.new(1, 1, 1), 2)
			return
		end
		local allRow = UI.new("Frame", {
			Size = UDim2.new(1, -12, 0, 50),
			BackgroundTransparency = 1,
			LayoutOrder = 0,
			Parent = body,
		})
		local all = Panel.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 2),
			Size = UDim2.fromOffset(200, 46),
		}, Color3.fromRGB(70, 210, 90), Color3.fromRGB(20, 90, 30), "OPEN ALL")
		all.Parent = allRow
		all.Activated:Connect(function()
			Sound.play("Click", 0.4)
			fire(Remotes.Names.Appraise, 0)
		end)
		for i, c in crates do
			local info = Progression.item(c.Id)
			local rarity = if info then info.rarity else "Common"
			local r = row(body, i, tierColor(rarity), CRATE_EMOJI, rarity .. " Crate", "", tierColor(rarity))
			-- progress bar in place of the second line
			local track = UI.new("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(220, 40),
				BackgroundColor3 = Color3.fromRGB(50, 50, 60),
				Parent = r,
			}, { UI.corner(10) })
			local fill = UI.new("Frame", {
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = Color3.fromRGB(80, 220, 90),
				Parent = track,
			}, { UI.corner(10) })
			local label = UI.bigText({
				Position = UDim2.fromOffset(6, 4),
				Size = UDim2.new(1, -12, 1, -8),
				Text = "",
				ZIndex = 3,
				Parent = track,
			}, Color3.fromRGB(20, 20, 25), 2)
			local button: TextButton = UI.new("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 4,
				Parent = track,
			})
			local index = i
			button.Activated:Connect(function()
				Sound.play("Click", 0.4)
				fire(Remotes.Names.Appraise, index)
			end)
			table.insert(bars, { fill = fill, label = label, readyAt = c.ReadyAt, button = button })
		end
	end
	task.spawn(function()
		while true do
			task.wait(0.25)
			if panel.isOpen() then
				local t = workspace:GetServerTimeNow()
				for i, b in bars do
					local c = (state.Crates or {})[i]
					local info = c and Progression.item(c.Id)
					local total = Progression.appraiseSeconds(if info then info.rarity else "Common")
					local left = b.readyAt - t
					b.fill.Size = UDim2.fromScale(math.clamp(1 - left / total, 0, 1), 1)
					b.label.Text = if left <= 0 then "OPEN!" else timeText(left)
				end
			end
		end
	end)
end

-- ===== MY ITEMS =====
local itemsMode = "items"
local function buildItems(panel: Panel.Panel)
	local body = panel.body
	UI.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body }
	)
	local function section(order: number, text: string)
		UI.bigText({
			Size = UDim2.new(1, -12, 0, 30),
			Text = text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(255, 200, 60),
			LayoutOrder = order,
			Parent = body,
		}, Color3.fromRGB(60, 40, 10), 2.5)
	end
	panel.onOpen = function()
		clear(body)
		local placed = 0
		local slots: { { key: string, id: string, mut: string } } = {}
		for key, it in state.Slots or {} do
			placed += 1
			table.insert(slots, { key = key, id = it.Id, mut = it.Mut })
		end
		table.sort(slots, function(a, b)
			return Progression.income(a.id, a.mut) > Progression.income(b.id, b.mut)
		end)
		local bag = state.Inventory or {}
		panel.subtitle.Text = placed .. " / " .. (state.Pedestals or 0) .. " placed"
		local top = UI.new("Frame", {
			Size = UDim2.new(1, -12, 0, 50),
			BackgroundTransparency = 1,
			LayoutOrder = 0,
			Parent = body,
		})
		local best = Panel.button({
			Position = UDim2.fromOffset(0, 2),
			Size = UDim2.fromOffset(220, 46),
		}, Color3.fromRGB(70, 210, 90), Color3.fromRGB(20, 90, 30), "⭐ EQUIP BEST")
		best.Parent = top
		best.Activated:Connect(function()
			Sound.play("Click", 0.4)
			fire(Remotes.Names.EquipBest)
		end)
		local order = 1
		section(order, "🎒 IN YOUR BAG (" .. #bag .. "/" .. Economy.InventoryMax .. ")")
		if #bag == 0 then
			order += 1
			UI.label({
				Size = UDim2.new(1, -12, 0, 26),
				Text = "Empty. Open crates at your appraiser!",
				TextColor3 = Color3.fromRGB(120, 110, 100),
				Font = Enum.Font.GothamBold,
				LayoutOrder = order,
				Parent = body,
			})
		end
		for i, it in bag do
			order += 1
			local info = Progression.item(it.Id)
			local rarity = if info then info.rarity else "Common"
			local r = row(
				body,
				order,
				tierColor(rarity),
				if info then info.emoji else "❓",
				itemText(it.Id, it.Mut),
				rarity .. "  •  +" .. Format.cash(Progression.income(it.Id, it.Mut)) .. "/s",
				tierColor(rarity)
			)
			local index = i
			rowButton(
				r,
				1,
				"SELL " .. Format.cash(Progression.sellValue(it.Id, it.Mut)),
				Color3.fromRGB(255, 170, 50),
				function()
					fire(Remotes.Names.SellItem, "bag", index)
				end
			)
			if itemsMode ~= "sell" then
				rowButton(r, 2, "PLACE", Color3.fromRGB(70, 180, 255), function()
					fire(Remotes.Names.Equip, index)
				end)
			end
		end
		order += 1
		section(order, "🏠 ON YOUR PLOT")
		for _, s in slots do
			order += 1
			local info = Progression.item(s.id)
			local rarity = if info then info.rarity else "Common"
			local r = row(
				body,
				order,
				tierColor(rarity),
				if info then info.emoji else "❓",
				itemText(s.id, s.mut),
				rarity .. "  •  +" .. Format.cash(Progression.income(s.id, s.mut)) .. "/s",
				tierColor(rarity)
			)
			local key = s.key
			if itemsMode == "sell" then
				rowButton(
					r,
					1,
					"SELL " .. Format.cash(Progression.sellValue(s.id, s.mut)),
					Color3.fromRGB(255, 170, 50),
					function()
						fire(Remotes.Names.SellItem, "slot", key)
					end
				)
			else
				rowButton(r, 1, "TAKE OFF", Color3.fromRGB(255, 90, 100), function()
					fire(Remotes.Names.Unequip, key)
				end)
			end
		end
	end
end

-- ===== the reveal when a crate opens =====
local function reveal(
	layer: Instance,
	name: string,
	rarity: string,
	mut: string,
	income: number,
	where: string
)
	local tier = Rarity.Tiers[rarity]
	local m = Mutations.List[mut]
	local big = rarity == "Legendary" or rarity == "Mythic" or (m ~= nil and m.mult >= 5)
	Sound.play(if big then "Rare" else "Deposit", 0.8)
	Shake.kick(if big then 0.5 else 0.2)
	local card = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(440, 150),
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		BackgroundTransparency = 0.1,
		Parent = layer,
	}, { UI.corner(22), UI.stroke(tierColor(rarity), 5) })
	UI.scaleObject(card)
	UI.bigText({
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 26),
		Text = "📦 CRATE OPENED!",
		TextColor3 = Color3.fromRGB(255, 220, 90),
		Parent = card,
	})
	UI.bigText({
		Position = UDim2.fromOffset(10, 38),
		Size = UDim2.new(1, -20, 0, 44),
		Text = (if m and mut ~= "None" then mut .. " " else "") .. name,
		TextColor3 = if m and m.color then UI.rgb(m.color) else Color3.new(1, 1, 1),
		Parent = card,
	})
	UI.bigText({
		Position = UDim2.fromOffset(10, 84),
		Size = UDim2.new(1, -20, 0, 30),
		Text = rarity .. "  •  +" .. Format.cash(income) .. "/s",
		TextColor3 = if tier then UI.rgb(tier.color) else Color3.new(1, 1, 1),
		Parent = card,
	})
	UI.bigText({
		Position = UDim2.fromOffset(10, 116),
		Size = UDim2.new(1, -20, 0, 24),
		Text = if where == "base" then "→ on your plot, earning!" else "→ in your bag (plot full)",
		TextColor3 = Color3.fromRGB(200, 200, 210),
		Parent = card,
	})
	local scale = card:FindFirstChildOfClass("UIScale") :: UIScale
	local target = scale.Scale
	scale.Scale = target * 0.3
	UI.tween(scale, 0.35, { Scale = target }, Enum.EasingStyle.Back)
	task.delay(if big then 3.2 else 2.2, function()
		UI.tween(card, 0.3, { BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0.3) })
		task.wait(0.32)
		card:Destroy()
	end)
end

function Items.start()
	local gui = HUD.gui()
	local appraise = Panel.new(
		"AppraisePanel",
		"APPRAISE CRATES",
		Color3.fromRGB(80, 200, 255),
		Color3.fromRGB(20, 70, 120),
		Vector2.new(600, 330)
	)
	local items = Panel.new(
		"ItemsPanel",
		"MY ITEMS",
		Color3.fromRGB(255, 190, 60),
		Color3.fromRGB(120, 70, 0),
		Vector2.new(620, 330)
	)
	buildAppraise(appraise)
	buildItems(items)

	-- right edge: the crate button (with counters) and the bag button
	local side = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.42, 0),
		Size = UDim2.fromOffset(70, 150),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 12),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	UI.scaleObject(side)
	local function sideButton(
		name: string,
		emoji: string,
		order: number,
		top: Color3,
		bottom: Color3
	): TextButton
		local b: TextButton = UI.new("TextButton", {
			Name = name,
			Size = UDim2.fromOffset(64, 64),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Text = "",
			LayoutOrder = order,
			Parent = side,
		}, { UI.corner(14), UI.stroke(Color3.fromRGB(120, 60, 10), 3), UI.gradient(top, bottom) })
		UI.label({
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 1, -16),
			Text = emoji,
			Font = Enum.Font.GothamBold,
			Parent = b,
		})
		b.Activated:Connect(function()
			Sound.play("Click", 0.4)
			UI.bump(b, 0.12)
		end)
		HUD.buttons[name] = b
		return b
	end
	local crateB =
		sideButton("Crates", CRATE_EMOJI, 1, Color3.fromRGB(255, 200, 90), Color3.fromRGB(230, 120, 30))
	local bagB = sideButton("Items", "💰", 2, Color3.fromRGB(255, 200, 90), Color3.fromRGB(230, 120, 30))
	local function badge(parent: Instance, x: number, color: Color3): TextLabel
		return UI.new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(x, 0, 1, -4),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = color,
			Text = "",
			TextScaled = true,
			Font = Enum.Font.FredokaOne,
			TextColor3 = Color3.new(1, 1, 1),
			Visible = false,
			ZIndex = 3,
			Parent = parent,
		}, { UI.corner(13), UI.stroke(Color3.new(1, 1, 1), 2) })
	end
	local countBadge = badge(crateB, 0.15, Color3.fromRGB(220, 50, 60))
	local readyBadge = badge(crateB, 0.85, Color3.fromRGB(60, 190, 70))
	local function badges()
		local n = player:GetAttribute("Crates") or 0
		local ready = player:GetAttribute("CratesReady") or 0
		countBadge.Text = tostring(n)
		countBadge.Visible = n > 0
		readyBadge.Text = tostring(ready)
		readyBadge.Visible = ready > 0
		if ready > 0 then
			UI.bump(crateB, 0.15)
		end
	end
	player:GetAttributeChangedSignal("Crates"):Connect(badges)
	player:GetAttributeChangedSignal("CratesReady"):Connect(function()
		badges()
		if (player:GetAttribute("CratesReady") or 0) > 0 then
			Sound.play("Upgrade", 0.4)
			HUD.toast("📦 A crate is ready to open!", "good")
		end
	end)
	badges()
	crateB.Activated:Connect(appraise.toggle)
	bagB.Activated:Connect(function()
		itemsMode = "items"
		items.toggle()
	end)

	-- bottom center: the hotbar (items in your bag; tap = place it on your plot)
	local bar = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset((HOTBAR + 1) * 70, 66),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	UI.scaleObject(bar)
	local function renderBar()
		clear(bar)
		local bag = state.Inventory or {}
		for i = 1, math.min(HOTBAR, #bag) do
			local it = bag[i]
			local info = Progression.item(it.Id)
			local rarity = if info then info.rarity else "Common"
			local cell: TextButton = UI.new("TextButton", {
				Size = UDim2.fromOffset(64, 64),
				BackgroundColor3 = Color3.fromRGB(30, 30, 40),
				BackgroundTransparency = 0.25,
				Text = "",
				LayoutOrder = i,
				Parent = bar,
			}, { UI.corner(10), UI.stroke(tierColor(rarity), 3) })
			UI.label({
				Position = UDim2.fromOffset(6, 2),
				Size = UDim2.new(1, -12, 0, 40),
				Text = if info then info.emoji else "❓",
				Font = Enum.Font.GothamBold,
				Parent = cell,
			})
			UI.bigText({
				Position = UDim2.new(0, 2, 1, -20),
				Size = UDim2.new(1, -4, 0, 16),
				Text = Format.cash(Progression.income(it.Id, it.Mut)) .. "/s",
				TextColor3 = Color3.fromRGB(120, 255, 130),
				Parent = cell,
			}, Color3.fromRGB(10, 10, 15), 1.5)
			local index = i
			cell.Activated:Connect(function()
				Sound.play("Click", 0.4)
				UI.bump(cell, 0.15)
				fire(Remotes.Names.Equip, index)
			end)
		end
		if #bag > HOTBAR then
			local more: TextButton = UI.new("TextButton", {
				Size = UDim2.fromOffset(64, 64),
				BackgroundColor3 = Color3.fromRGB(30, 30, 40),
				BackgroundTransparency = 0.25,
				Text = "",
				LayoutOrder = HOTBAR + 1,
				Parent = bar,
			}, { UI.corner(10), UI.stroke(Color3.new(1, 1, 1), 3) })
			UI.bigText({
				Position = UDim2.fromOffset(4, 4),
				Size = UDim2.new(1, -8, 1, -8),
				Text = "+" .. (#bag - HOTBAR),
				Parent = more,
			})
			more.Activated:Connect(function()
				itemsMode = "items"
				items.setOpen(true)
			end)
		end
	end

	Remotes.get(Remotes.Names.Sync).OnClientEvent:Connect(function(s: any)
		state = s
		renderBar()
		if appraise.isOpen() and appraise.onOpen then
			appraise.onOpen()
		end
		if items.isOpen() and items.onOpen then
			items.onOpen()
		end
	end)
	Remotes.get(Remotes.Names.OpenItems).OnClientEvent:Connect(function(mode: string)
		itemsMode = if mode == "sell" then "sell" else "items"
		task.wait(0.15) -- the Sync sent just before this lands first
		items.setOpen(true)
	end)

	local layer = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Remotes.get(Remotes.Names.Revealed).OnClientEvent:Connect(
		function(name: string, rarity: string, mut: string, income: number, where: string, bonus: number?)
			reveal(layer, name, rarity, mut, income, where)
			if bonus and bonus > 0 then
				HUD.toast("💰 Opening bonus +" .. Format.cash(bonus), "cash")
			end
		end
	)
end

return Items
