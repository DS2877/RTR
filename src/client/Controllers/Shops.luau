--!strict
-- Shop panels, opened by the counters' ProximityPrompts in the Common Room (no shop buttons in the
-- HUD). Workshop: tools + brushes. Commissary: backpack, find slots, vacuum. The Fence: sell finds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Upgrades = require(Shared.Config.Upgrades)
local Finds = require(Shared.Config.Finds)
local Rarity = require(Shared.Config.Rarity)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local Client = script.Parent.Parent
local UI = require(Client.Util.UI)
local Panel = require(Client.Util.Panel)
local Sound = require(Client.Util.Sound)

local Shops = {}

local player = Players.LocalPlayer
local DARK = Color3.fromRGB(40, 30, 20)

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

local function row(body: Instance, order: number, height: number?): Frame
	return UI.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, height or 70),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Parent = body,
	}, { UI.corner(14), UI.stroke(Color3.fromRGB(220, 200, 170), 2) })
end

local function upgradePanel(shop: string, title: string, color: Color3, dark: Color3)
	local panel = Panel.new(shop .. "Panel", title, color, dark, Vector2.new(580, 320))
	UI.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.body }
	)
	local buy = Remotes.get(Remotes.Names.Buy)
	local function render()
		clear(panel.body)
		panel.subtitle.Text = Format.noodles(player:GetAttribute("Noodles") or 0)
		for i, track in Upgrades.Shops[shop] do
			local list = (Upgrades :: any)[track]
			local level = (player:GetAttribute(track) or 1) :: number
			local info = TRACK_INFO[track]
			local cur = list[level]
			local nxt = list[level + 1]
			local cost = Progression.nextCost(track, level)
			local r = row(panel.body, i, 78)
			UI.label({
				Position = UDim2.fromOffset(10, 6),
				Size = UDim2.new(0.55, -10, 0, 22),
				Text = info.title .. "  " .. cur.emoji .. " " .. cur.name,
				TextColor3 = DARK,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = r,
			})
			UI.label({
				Position = UDim2.fromOffset(10, 32),
				Size = UDim2.new(0.6, -10, 0, 36),
				Text = if nxt
					then string.format("NEXT %s %s: %s", nxt.emoji, nxt.name, info.unit(nxt))
					else "MAXED: " .. info.unit(cur),
				TextColor3 = Color3.fromRGB(110, 90, 70),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = r,
			})
			local afford = cost ~= nil and (player:GetAttribute("Noodles") or 0) >= cost
			local text = if cost then Format.noodles(cost) elseif nxt then "SOON" else "MAX"
			local b = Panel.button(
				{
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.new(0.36, 0, 0, 58),
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
	end
	panel.onOpen = render
	for _, track in Upgrades.Shops[shop] do
		player:GetAttributeChangedSignal(track):Connect(function()
			if panel.isOpen() then
				render()
			end
		end)
	end
	player:GetAttributeChangedSignal("Noodles"):Connect(function()
		if panel.isOpen() then
			render()
		end
	end)
	return panel
end

local function fencePanel()
	local panel = Panel.new(
		"FencePanel",
		"💰 THE FENCE",
		Color3.fromRGB(170, 100, 230),
		Color3.fromRGB(60, 20, 90),
		Vector2.new(580, 320)
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
		local top = row(panel.body, 0, 66)
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
				local r = row(panel.body, i, 58)
				UI.label({
					Position = UDim2.fromOffset(10, 6),
					Size = UDim2.new(0.62, -10, 1, -12),
					Text = f.emoji .. " " .. f.name .. "  ·  " .. f.rarity,
					TextColor3 = UI.rgb(tier.color):Lerp(Color3.new(0, 0, 0), 0.35),
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = r,
				})
				local b = Panel.button({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -6, 0.5, 0),
					Size = UDim2.new(0.34, 0, 0, 46),
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

function Shops.start()
	local panels = {
		Workshop = upgradePanel(
			"Workshop",
			"🔨 WORKSHOP",
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
		table.insert(finds, id)
	end)
	Remotes.get(Remotes.Names.OpenShop).OnClientEvent:Connect(function(name)
		local p = (panels :: any)[name]
		if p then
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
					if p.isOpen() then
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
